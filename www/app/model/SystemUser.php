<?php

/**
 * Synthetic user record used by the isolated lab.
 */
class SystemUser extends TRecord
{
    const TABLENAME = 'system_users';
    const PRIMARYKEY = 'id';
    const IDPOLICY = 'serial';

    public function __construct($id = null, $callObjectLoad = true)
    {
        parent::__construct($id, $callObjectLoad);
        $this->addAttribute('login');
        $this->addAttribute('password');
        $this->addAttribute('active');
        $this->addAttribute('name');
        $this->addAttribute('email');
        $this->addAttribute('role');
    }
}
