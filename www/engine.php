<?php
require_once 'bootstrap.php';

/**
 * Raw/static front controller for the local authorization-routing lab.
 * Padding preserves the version-specific dispatcher trace line numbers.
 */
class TApplication extends AdiantiCoreApplication
{
    public static function run($debug = null)
    {
        new TSession;

        if (!$_REQUEST)
        {
            return;
        }

        $ini = AdiantiApplicationConfig::get();
        $debug = is_null($debug) ? $ini['general']['debug'] : $debug;
        $class = isset($_REQUEST['class']) ? $_REQUEST['class'] : '';
        $method = isset($_REQUEST['method']) ? $_REQUEST['method'] : '';

        $reflectionClass = is_string($class)
            && in_array($class, array('LoginForm', 'SystemPasswordResetForm'), true)
            && is_string($method);
        $disabledResetRoute = $class === 'SystemRequestPasswordResetForm'
            && $method === 'onRequest';
        $authenticatedRoute = TSession::getValue('logged') && in_array($class, array('SystemUserList', 'SystemProfileForm'), true);
        if ($reflectionClass || $disabledResetRoute || $authenticatedRoute)
        {
            // Deliberately uncaught: this is the observed raw ReflectionException path.
            // The inherited 7.4 dispatcher constructs ReflectionMethod at core line 79.



            parent::run($debug);
            return;
        }
        http_response_code(401);
        new TMessage('error', 'Permissão negada');
    }
}

/*
 * Compatibility padding: the modeled application calls TApplication::run()
 * from engine.php line 66. Keep the invocation below on that line so PHP 7.4
 * produces the same application frames in an uncaught reflection trace.
 */
















TApplication::run();
