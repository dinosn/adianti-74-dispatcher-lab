<?php

/**
 * Synthetic administrator-only user list and intentionally vulnerable
 * passwordless impersonation method used by the local lab.
 */
class SystemUserList extends TPage
{
    public function __construct($param = null)
    {
        parent::__construct();
    }

    public function onImpersonation($param)
    {
        $login = isset($param['login']) && is_scalar($param['login'])
            ? trim((string) $param['login'])
            : '';

        if ($login === '')
        {
            new TMessage('error', 'Usuário não encontrado');
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

        if (!$user || $user->active !== 'Y')
        {
            new TMessage('error', 'Usuário não encontrado');
            return;
        }

        // Intentional lab flaw: existence and active state are checked, but no
        // credential is required before an authenticated identity is written.
        TSession::regenerate();
        TSession::setValue('logged', true);
        TSession::setValue('user_id', (int) $user->id);
        TSession::setValue('login', $user->login);
        TSession::setValue('role', $user->role);
        TScript::create("__adianti_goto_page('index.php?class=EmptyPage')");
    }

    public function show($param = null)
    {
        if (!TSession::getValue('logged') || TSession::getValue('role') !== 'admin')
        {
            http_response_code(403);
            new TMessage('error', 'Permissão negada');
            return;
        }

        TTransaction::open('lab');
        try
        {
            $users = SystemUser::where('id', '>', 0)->orderBy('id')->load();
            TTransaction::close();
        }
        catch (Throwable $error)
        {
            TTransaction::rollback();
            throw $error;
        }

        echo '<section id="lab-admin-user-list" data-lab-marker="LAB_ADMIN_USER_LIST">';
        echo '<h1>Usuários sintéticos</h1>';
        echo '<table><thead><tr>';
        foreach (array('ID', 'Nome', 'Login', 'Email', 'Perfil', 'Ativo') as $header)
        {
            echo '<th>' . self::escape($header) . '</th>';
        }
        echo '</tr></thead><tbody>';
        foreach ($users as $user)
        {
            echo '<tr>';
            foreach (array($user->id, $user->name, $user->login, $user->email, $user->role, $user->active) as $value)
            {
                echo '<td>' . self::escape($value) . '</td>';
            }
            echo '</tr>';
        }
        echo '</tbody></table></section>';
    }

    private static function escape($value)
    {
        return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}
