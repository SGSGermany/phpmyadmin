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

$cfg = [];

// server config
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

// phpMyAdmin database config
$databaseConfig = [];

if (file_exists('/etc/phpmyadmin/config.database.inc.php')) {
    require('/etc/phpmyadmin/config.database.inc.php');
}

if (isset($databaseConfig['database'])) {
    $cfg['Servers'][$i] += [
        'pmadb' => $databaseConfig['database'],
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

    if (isset($databaseConfig['user'])) {
        $cfg['Servers'][$i]['controluser'] = $databaseConfig['user'];
    }

    if (isset($databaseConfig['password'])) {
        $cfg['Servers'][$i]['controlpass'] = $databaseConfig['password'];
    }
}

// global config
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = sys_get_temp_dir();
$cfg['ExecTimeLimit'] = ini_get('max_execution_time');
$cfg['MemoryLimit'] = ini_get('memory_limit');
$cfg['AuthLog'] = 'php';
$cfg['VersionCheck'] = false;

// load config.user.inc.php
if (file_exists('/etc/phpmyadmin/config.user.inc.php')) {
    require('/etc/phpmyadmin/config.user.inc.php');
}

// load conf.d/*.php files
if (is_dir('/etc/phpmyadmin/conf.d/')) {
    foreach (glob('/etc/phpmyadmin/conf.d/*.php') as $configFile) {
        require($configFile);
    }
}

// secrets config
// the secrets config can't be overwritten by 'config.user.inc.php' on purpose
// either provide a custom 'config.secrets.inc.php', or use container secrets instead
$secrets = [];

if (file_exists('/etc/phpmyadmin/config.secrets.inc.php')) {
    require('/etc/phpmyadmin/config.secrets.inc.php');
}

if (!isset($secrets['blowfish_secret'])) {
    // generate 32 random printable ASCII chars as blowfish secret
    $secrets['blowfish_secret'] = '';
    for ($i = 0; $i < 32; $i++) {
        $secrets['blowfish_secret'] .= chr(random_int(33, 126));
    }
}

$cfg['blowfish_secret'] = $secrets['blowfish_secret'];
