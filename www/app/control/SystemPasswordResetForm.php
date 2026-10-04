<?php

class SystemPasswordResetForm extends TPage
{
    public function onReset($param)
    {
        $password1 = isset($param['password1']) ? $param['password1'] : null;
        $password2 = isset($param['password2']) ? $param['password2'] : null;

        if (empty($password1))
        {
            new TMessage('error', 'Senha vazia');
            return;
        }

        if ($password1 !== $password2)
        {
            new TMessage('error', 'As senhas não conferem');
            return;
        }

        $ini = AdiantiApplicationConfig::get();
        $seed = isset($ini['general']['seed']) ? $ini['general']['seed'] : null;
        if (empty($seed))
        {
            new TMessage('error', 'Uma nova seed é necessária no application.ini por motivos de segurança');
            return;
        }

        new TMessage('error', 'Chave de recuperação inválida');
    }
}
