<?php

class SystemRequestPasswordResetForm
{
    public function onRequest($param)
    {
        new TMessage('error', 'A recuperação de senhas está desabilitada');
    }
}
