<?php

/**
 * Deliberately present but denied by engine.php before reflection.
 */
class SystemModulesCheckView extends TPage
{
    public function onShow($param)
    {
        echo 'LAB_PROTECTED_METHOD_REACHED';
    }
}
