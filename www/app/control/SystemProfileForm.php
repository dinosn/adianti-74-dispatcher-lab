<?php

/**
 * Synthetic self-service profile form used to demonstrate and restore the
 * password consequence of the lab's dispatcher authorization flaw.
 */
class SystemProfileForm extends TPage
{
    public function __construct($param = null)
    {
        parent::__construct();
    }

    public function onEdit($param = null)
    {
        $user = $this->currentUser();
        if (!$user)
        {
            return;
        }

        $token = TSession::getValue('profile_csrf_token');
        if (!is_string($token) || strlen($token) < 64)
        {
            $token = bin2hex(random_bytes(32));
            TSession::setValue('profile_csrf_token', $token);
        }

        echo '<form id="lab-profile-form" data-lab-marker="LAB_PROFILE_FORM" method="post">';
        $this->input('csrf_token', $token, 'hidden');
        $this->input('name', $user->name);
        $this->input('login', $user->login);
        $this->input('email', $user->email);
        $this->input('password1', '', 'password');
        $this->input('password2', '', 'password');
        echo '<button type="submit">Salvar</button></form>';
    }

    public function onSave($param)
    {
        $user = $this->currentUser();
        if (!$user)
        {
            return;
        }

        $expected = TSession::getValue('profile_csrf_token');
        $provided = isset($param['csrf_token']) && is_scalar($param['csrf_token'])
            ? (string) $param['csrf_token']
            : '';
        if (!is_string($expected) || !hash_equals($expected, $provided))
        {
            http_response_code(403);
            echo 'LAB_CSRF_REJECTED';
            return;
        }

        $password1 = isset($param['password1']) && is_scalar($param['password1'])
            ? (string) $param['password1']
            : '';
        $password2 = isset($param['password2']) && is_scalar($param['password2'])
            ? (string) $param['password2']
            : '';
        if (strlen($password1) < 12)
        {
            new TMessage('error', 'A senha deve ter pelo menos 12 caracteres');
            return;
        }
        if (!hash_equals($password1, $password2))
        {
            new TMessage('error', 'As senhas não conferem');
            return;
        }

        TTransaction::open('lab');
        try
        {
            $stored = new SystemUser((int) $user->id);
            $stored->password = password_hash($password1, PASSWORD_BCRYPT, array('cost' => 12));
            $stored->store();
            TTransaction::close();
        }
        catch (Throwable $error)
        {
            TTransaction::rollback();
            throw $error;
        }

        TSession::setValue('profile_csrf_token', bin2hex(random_bytes(32)));
        echo 'LAB_RECORD_SAVED';
        new TMessage('info', 'Registro salvo');
    }

    private function currentUser()
    {
        $id = TSession::getValue('user_id');
        if (!TSession::getValue('logged') || !$id)
        {
            http_response_code(401);
            new TMessage('error', 'Permissão negada');
            return null;
        }

        TTransaction::open('lab');
        try
        {
            $user = new SystemUser((int) $id);
            TTransaction::close();
            return $user;
        }
        catch (Throwable $error)
        {
            TTransaction::rollback();
            throw $error;
        }
    }

    private function input($name, $value, $type = 'text')
    {
        $escape = function ($item) {
            return htmlspecialchars((string) $item, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        };
        echo '<input type="' . $escape($type) . '" name="' . $escape($name) . '" value="' . $escape($value) . '">';
    }
}
