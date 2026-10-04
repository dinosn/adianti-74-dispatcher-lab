<?php

if (version_compare(PHP_VERSION, '7.4.0', '<'))
{
    die('PHP 7.4 or newer is required');
}

chdir(__DIR__);

$ini = parse_ini_file(__DIR__ . '/application.ini', true);
if (!is_array($ini))
{
    throw new RuntimeException('Application configuration file not found');
}

require_once __DIR__ . '/lib/adianti/core/AdiantiCoreLoader.php';

spl_autoload_register(array('Adianti\\Core\\AdiantiCoreLoader', 'autoload'));
Adianti\Core\AdiantiCoreLoader::loadClassMap();

AdiantiCoreTranslator::setLanguage($ini['general']['language']);
AdiantiApplicationConfig::load($ini);
AdiantiApplicationConfig::apply();

date_default_timezone_set($ini['general']['timezone']);

defined('APPLICATION_NAME') || define('APPLICATION_NAME', $ini['general']['application']);
defined('OS') || define('OS', strtoupper(substr(PHP_OS, 0, 3)));
defined('PATH') || define('PATH', __DIR__);
defined('LANG') || define('LANG', $ini['general']['language']);

session_name('PHPSESSID_' . $ini['general']['application']);
