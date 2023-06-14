#!/bin/sh
# phpMyAdmin
# A php-fpm container running phpMyAdmin.
#
# Copyright (c) 2021  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

read_secret() {
    local SECRET="/run/secrets/$1"

    [ -e "$SECRET" ] || return 0
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

# database config
if [ ! -f "/etc/phpmyadmin/config.database.inc.php" ]; then
    PMA_PMADB="$(read_secret "pma_pmadb")"
    PMA_CONTROLUSER="$(read_secret "pma_controluser")"
    PMA_CONTROLPASS="$(read_secret "pma_controlpass")"

    if [ -n "$PMA_PMADB" ]; then
        {
            printf '<?php\n';
            printf "\$databaseConfig['database'] = '%s';\n" "$PMA_PMADB";
            [ -z "$PMA_CONTROLUSER" ] || printf "\$databaseConfig['user'] = '%s';\n" "$PMA_CONTROLUSER";
            [ -z "$PMA_CONTROLPASS" ] || printf "\$databaseConfig['password'] = '%s';\n" "$PMA_CONTROLPASS";
        } > "/etc/phpmyadmin/config.database.inc.php"
    fi
fi

# blowfish secret
if [ ! -f "/etc/phpmyadmin/config.secrets.inc.php" ]; then
    PMA_SECRET="$(read_secret "pma_secret")"

    if [ -z "$PMA_SECRET" ]; then
        PMA_SECRET="$(tr -dc '[\x21-\x7E]' < /dev/urandom 2> /dev/null | tr -d "\\\'" | head -c 32 || true)"
    fi

    {
        printf '<?php\n';
        printf "\$secrets['blowfish_secret'] = '%s';\n" "$PMA_SECRET";
    } > "/etc/phpmyadmin/config.secrets.inc.php"
fi
