<?php

// Router for the PHP built-in web server, so static files and deep routes
// both work:  php -S 127.0.0.1:8080 -t public public/router.php

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && $path !== '/index.php' && $path !== '/router.php' && is_file(__DIR__ . $path)) {
    return false;
}

$_SERVER['SCRIPT_FILENAME'] = __DIR__ . '/index.php';
$_SERVER['SCRIPT_NAME'] = '/index.php';

require __DIR__ . '/index.php';