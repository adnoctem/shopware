<?php

declare(strict_types=1);

$php_versions = ['8.2', '8.3'];
$root_dir = trim(shell_exec('git rev-parse --show-toplevel'));

$plugin_dir = $root_dir . '/custom/plugins';
$apps_dir = $root_dir . '/custom/apps';

$plugin_paths = glob($plugin_dir . '/*', GLOB_ONLYDIR);
$app_paths = glob($apps_dir . '/*', GLOB_ONLYDIR);

$plugins = [];
$apps = [];

foreach ($plugin_paths as $plugin_path) {
    $plugins[] .= basename($plugin_path);
}

foreach ($app_paths as $app_path) {
    $apps[] .= basename($app_path);
}

$matrix = [
    'php_version' => $php_versions,
];

if (count($plugins) > 0) {
    $matrix['plugin'] = $plugins;
}

if (count($apps) > 0) {
    $matrix['app'] = $apps;
}

try {
    echo json_encode($matrix, JSON_THROW_ON_ERROR);
} catch (JsonException $e) {
    printf("Could not generate matrix for project: %s.\nERROR: %s\n", basename($root_dir), $e->getMessage());
}
