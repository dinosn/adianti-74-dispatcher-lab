<?php
require_once 'bootstrap.php';
new TSession;
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <meta name="theme-color" content="#ffffff">
    <title> Adianti 7.4 Dispatcher Lab </title>
    <link rel="manifest" href="manifest.json">
    <link rel="icon" type="image/png" href="app/images/icon.png?appver=740">
    <link rel="stylesheet" href="lib/bootstrap/css/bootstrap.min.css?afver=740">
    <link rel="stylesheet" href="lib/independent/css/font-awesome.min.css?afver=740">
    <link rel="stylesheet" href="app/templates/theme3/application.css?appver=740">
    <style>
        html, body { min-height: 100%; background: #ecf0f5; }
        body { font-family: "Source Sans Pro", "Helvetica Neue", Arial, sans-serif; color: #333; }
        .main-header { position: relative; max-height: 100px; z-index: 1030; }
        .main-header .logo { float: left; width: 230px; height: 50px; line-height: 50px; color: #fff; background: #357ca5; text-align: center; font-size: 19px; }
        .main-header .navbar { min-height: 50px; margin-left: 230px; margin-bottom: 0; border: 0; border-radius: 0; background: #3c8dbc; }
        .navbar-title { display: inline-block; padding: 15px 20px; color: #fff; font-size: 15px; }
        .main-sidebar { position: absolute; top: 0; left: 0; min-height: 100%; width: 230px; padding-top: 50px; background: #222d32; }
        .sidebar-brand { padding: 24px 20px; color: #b8c7ce; border-bottom: 1px solid #1a2226; }
        .sidebar-menu { margin: 0; padding: 0; list-style: none; }
        .sidebar-menu li a { display: block; padding: 12px 20px; color: #b8c7ce; text-decoration: none; }
        .sidebar-menu li.active a { color: #fff; border-left: 3px solid #3c8dbc; background: #1e282c; }
        .content-wrapper { min-height: calc(100vh - 50px); margin-left: 230px; padding: 20px; background: #ecf0f5; }
        .content-header { padding: 15px 15px 0; }
        .content-header h1 { margin: 0; font-size: 24px; font-weight: 300; }
        .content { min-height: 250px; padding: 15px; }
        #adianti_div_content { min-height: 320px; }
        .login-placeholder { max-width: 430px; margin: 40px auto; padding: 22px; border-top: 3px solid #3c8dbc; background: #fff; box-shadow: 0 1px 1px rgba(0,0,0,.1); }
        .login-placeholder h2 { margin: 0 0 8px; font-size: 21px; font-weight: 400; }
        .login-placeholder p { margin: 0; color: #777; }
        .main-footer { margin-left: 230px; padding: 15px; color: #444; border-top: 1px solid #d2d6de; background: #fff; }
        @media (max-width: 767px) {
            .main-header .logo { float: none; width: 100%; }
            .main-header .navbar { margin-left: 0; }
            .main-sidebar { display: none; }
            .content-wrapper, .main-footer { margin-left: 0; }
        }
    </style>
    <script src="lib/jquery/js/jquery.min.js?afver=740"></script>
    <script src="lib/bootstrap/js/bootstrap.min.js?afver=740"></script>
    <script src="lib/adianti/include/adianti.js?afver=740"></script>
    <script src="app/lib/include/application.js?appver=740"></script>
    <script>
        __adianti_set_name('AdiantiLab');
        __adianti_set_language('pt');
        __adianti_set_debug(0);
    </script>
</head>
<body class="hold-transition skin-blue sidebar-mini">
<div class="wrapper">
    <header class="main-header">
        <a class="logo" href="index.php"><span class="logo-lg">Adianti Lab</span></a>
        <nav class="navbar" role="navigation">
            <span class="navbar-title">Authorization Routing Lab</span>
        </nav>
    </header>

    <aside class="main-sidebar" aria-label="Navegação principal">
        <section class="sidebar">
            <div class="sidebar-brand">Acesso ao sistema</div>
            <ul class="sidebar-menu">
                <li class="active"><a href="index.php"><i class="fa fa-sign-in"></i> <span>Entrar</span></a></li>
            </ul>
        </section>
    </aside>

    <div class="content-wrapper">
        <section class="content-header">
            <h1>Authorization Routing Lab</h1>
        </section>
        <section class="content">
            <div id="adianti_div_content">
                <div class="login-placeholder" aria-live="polite">
                    <h2>Adianti 7.4 Dispatcher Lab</h2>
                    <p>Carregando formulário de acesso...</p>
                    <!-- <a href="index.php?class=SystemRegistrationForm">Criar conta</a> -->
                    <!-- <a href="index.php?class=SystemRequestPasswordResetForm">Redefinir senha</a> -->
                </div>
            </div>
        </section>
    </div>

    <footer class="main-footer">
        <span>Authorization Routing Lab</span>
    </footer>
</div>
</body>
</html>
<script language='JavaScript'>setTimeout( function() { __adianti_load_page('index.php?class=LoginForm&previous_class=SystemLoginForm'); }, 1 )</script>
