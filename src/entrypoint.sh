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

set -e

[ $# -gt 0 ] || set -- php-fpm "$@"
if [ "$1" == "php-fpm" ]; then
    # create phpMyAdmin blowfish secret
    if [ ! -f /etc/phpmyadmin/config.secret.inc.php ] && [ -z "$PMA_SECRET" ]; then
        PMA_SECRET="$(LC_ALL=C tr -dc '[\x21-\x7E]' < /dev/urandom 2> /dev/null | tr -d "\\\'" | head -c 32 || true)"
        printf "<?php\n\$cfg['blowfish_secret'] = '%s';\n" "$PMA_SECRET" \
            > /etc/phpmyadmin/config.secret.inc.php
    fi

    # setup phpMyAdmin, if necessary
    /usr/lib/phpmyadmin/setup.sh

    exec "$@"
fi

exec "$@"
