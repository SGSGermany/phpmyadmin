<?php
/**
 * phpMyAdmin
 * A php-fpm container running phpMyAdmin.
 *
 * Copyright (c) 2021  SGS Serious Gaming & Simulations GmbH
 *
 * This work is licensed under the terms of the MIT license.
 * For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
 *
 * SPDX-License-Identifier: MIT
 * License-Filename: LICENSE
 */

$env = (function () {
    $env = [];
    foreach (getenv() as $name => $value) {
        $value = trim($value);
        if ((substr($name, 0, 4) === 'PMA_') && ($value !== '')) {
            $env[$name] = $value;
        }
    }

    return $env;
})();

$i = 1;
$cfg['Servers'][$i] = [
    'host' => 'localhost',
    'socket' => '/run/mysql/mysql.sock',
    'compress' => false,
    'AllowNoPassword' => false,
    'auth_type' => 'cookie',
    'DisableIS' => true,

    'AllowDeny' => [
        'order' => 'deny,allow',
        'rules' => [
            'deny root from all',
            'deny mysql from all',
            'deny phpmyadmin from all',
        ],
    ],
];

if (isset($env['PMA_PMADB'])) {
    $cfg['Servers'][$i] += [
        'pmadb' => $env['PMA_PMADB'],
        'relation' => 'pma__relation',
        'table_info' => 'pma__table_info',
        'table_coords' => 'pma__table_coords',
        'pdf_pages' => 'pma__pdf_pages',
        'column_info' => 'pma__column_info',
        'bookmarktable' => 'pma__bookmark',
        'history' => 'pma__history',
        'recent' => 'pma__recent',
        'favorite' => 'pma__favorite',
        'table_uiprefs' => 'pma__table_uiprefs',
        'tracking' => 'pma__tracking',
        'userconfig' => 'pma__userconfig',
        'users' => 'pma__users',
        'usergroups' => 'pma__usergroups',
        'navigationhiding' => 'pma__navigationhiding',
        'savedsearches' => 'pma__savedsearches',
        'central_columns' => 'pma__central_columns',
        'designer_settings' => 'pma__designer_settings',
        'export_templates' => 'pma__export_templates',
    ];

    if (isset($env['PMA_CONTROLUSER'])) {
        $cfg['Servers'][$i]['controluser'] = $env['PMA_CONTROLUSER'];
    }

    if (isset($env['PMA_CONTROLPASS'])) {
        $cfg['Servers'][$i]['controlpass'] = $env['PMA_CONTROLPASS'];
    }
}

$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = sys_get_temp_dir();
$cfg['ExecTimeLimit'] = ini_get('max_execution_time');
$cfg['MemoryLimit'] = ini_get('memory_limit');
$cfg['AuthLog'] = 'php';
$cfg['VersionCheck'] = false;

if (file_exists('/etc/phpmyadmin/config.user.inc.php')) {
    require('/etc/phpmyadmin/config.user.inc.php');
}

if (isset($env['PMA_SECRET'])) {
    $cfg['blowfish_secret'] = $env['PMA_SECRET'];
}

if (file_exists('/etc/phpmyadmin/config.secret.inc.php')) {
    require('/etc/phpmyadmin/config.secret.inc.php');
}
