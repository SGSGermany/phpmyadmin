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
    # initialize config, if necessary
    /usr/lib/phpmyadmin/config.sh

    # setup phpMyAdmin, if necessary
    /usr/lib/phpmyadmin/setup.sh

    exec "$@"
fi

exec "$@"
