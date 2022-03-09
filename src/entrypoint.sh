#!/bin/sh
# phpMyAdmin
# A php-fpm container of phpMyAdmin.
#
# Copyright (c) 2021  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -e

[ $# -gt 0 ] || set -- php-fpm "$@"
if [ "$1" == "php-fpm" ]; then
    # create phpMyAdmin blowfish secret
    if [ ! -f /etc/phpmyadmin/config.secret.inc.php ] && [ -z "$PMA_SECRET" ]; then
        PMA_SECRET="$(LC_ALL=C tr -dc '[:graph:]' < /dev/urandom 2> /dev/null | tr -d "\\\'" | head -c 32 || true)"
        printf "<?php\n\$cfg['blowfish_secret'] = '%s';\n" "$PMA_SECRET" \
            > /etc/phpmyadmin/config.secret.inc.php
    fi

    # upgrade phpMyAdmin sources if necessary
    PMA_VERSION_SRC="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /usr/src/phpmyadmin/pma_version_info)"

    if [ -n "$(find /var/www/html -maxdepth 0 -empty)" ] || [ ! -f /var/www/pma_version_info ]; then
        echo "Initializing phpMyAdmin $PMA_VERSION_SRC..."
        rsync -rlptog /usr/src/phpmyadmin/ /var/www/
    else
        PMA_SHA256_SRC="$(sed -ne 's/^SHA256=\(.*\)$/\1/p' /usr/src/phpmyadmin/pma_version_info)"
        PMA_SHA256_LIVE="$(sed -ne 's/^SHA256=\(.*\)$/\1/p' /var/www/pma_version_info)"

        if [ -z "$PMA_SHA256_LIVE" ] || [ "$PMA_SHA256_LIVE" != "$PMA_SHA256_SRC" ]; then
            PMA_VERSION_LIVE="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /var/www/pma_version_info)"

            echo "Upgrading phpMyAdmin $PMA_VERSION_LIVE to $PMA_VERSION_SRC..."
            rsync -rlptog --delete /usr/src/phpmyadmin/ /var/www/
        fi
    fi

    exec "$@"
fi

exec "$@"
