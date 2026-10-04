<?php

/**
 * Synthetic lab login handler.
 *
 * The lookup deliberately uses Adianti's repository API. With prep="1" in
 * app/config/lab.ini, TFilter emits a bound :par_<random> placeholder.
 */
class LoginForm extends TPage
{
    public function onLogin($param)
    {
        $login = isset($param['login']) ? $param['login'] : null;
        $password = isset($param['password']) ? $param['password'] : null;

        if (!is_scalar($login) || is_bool($login))
        {
            new TMessage('error', 'O campo Login é obrigatório');
            return;
        }

        if (!is_scalar($password) || is_bool($password))
        {
            new TMessage('error', 'O campo Senha é obrigatório');
            return;
        }

        if ($this->isRequiredValueMissing($login))
        {
            new TMessage('error', 'O campo Login é obrigatório');
            return;
        }

        if ($this->isRequiredValueMissing($password))
        {
            new TMessage('error', 'O campo Senha é obrigatório');
            return;
        }

        TTransaction::open('lab');
        try
        {
            $user = SystemUser::where('login', '=', $login)->first();
            TTransaction::close();
        }
        catch (Throwable $error)
        {
            TTransaction::rollback();
            throw $error;
        }

        if (!$user)
        {
            new TMessage('error', 'Usuário não encontrado');
            return;
        }

        if ($user->active === 'N')
        {
            new TMessage('error', 'Usuário inativo');
            return;
        }

        if (!password_verify((string) $password, $user->password))
        {
            new TMessage('error', 'Senha inválida');
            return;
        }

        TSession::regenerate();
        TSession::setValue('logged', true);
        TSession::setValue('user_id', (int) $user->id);
        TSession::setValue('login', $user->login);
        TSession::setValue('role', $user->role);
        TScript::create("__adianti_load_page('index.php')");
    }

    public function onLogout($param = null)
    {
        TSession::freeSession();
        TSession::regenerate();
        TScript::create("__adianti_load_page('index.php?class=LoginForm')");
    }

    private function isRequiredValueMissing($value)
    {
        if (is_null($value))
        {
            return true;
        }

        if (is_scalar($value) && !is_bool($value))
        {
            return trim((string) $value) === '';
        }

        if (is_array($value))
        {
            if (empty($value))
            {
                return true;
            }

            return count($value) === 1
                && isset($value[0])
                && is_scalar($value[0])
                && trim((string) $value[0]) === '';
        }

        return false;
    }
}
