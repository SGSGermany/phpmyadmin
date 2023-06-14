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

if [ -e "/var/www/pma_version_info" ]; then
    OLD_HASH="$(sed -ne 's/^HASH=\(.*\)$/\1/p' /var/www/pma_version_info)"
    NEW_HASH="$(sed -ne 's/^HASH=\(.*\)$/\1/p' /usr/src/phpmyadmin/version_info)"

    OLD_SHA256="$(sed -ne 's/^PMA_SHA256=\(.*\)$/\1/p' /var/www/pma_version_info)"
    NEW_SHA256="$(sed -ne 's/^PMA_SHA256=\(.*\)$/\1/p' /usr/src/phpmyadmin/version_info)"

    if [ -n "$OLD_HASH" ] && [ "$OLD_HASH" == "$NEW_HASH" ] \
        && [ -n "$OLD_SHA256" ] && [ "$OLD_SHA256" == "$NEW_SHA256" ]
    then
        exit
    fi

    OLD_VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /var/www/pma_version_info)"
    OLD_PMA_VERSION="$(sed -ne 's/^PMA_VERSION=\(.*\)$/\1/p' /var/www/pma_version_info)"

    OLD_VERSION_INFO="$OLD_VERSION"
    [ "$OLD_VERSION" == "$OLD_PMA_VERSION" ] || [ -z "$OLD_PMA_VERSION" ] || OLD_VERSION_INFO="$OLD_PMA_VERSION ($OLD_VERSION)"
else
    OLD_VERSION=""
    OLD_PMA_VERSION=""

    OLD_VERSION_INFO=""
fi

NEW_VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /usr/src/phpmyadmin/version_info)"
NEW_PMA_VERSION="$(sed -ne 's/^PMA_VERSION=\(.*\)$/\1/p' /usr/src/phpmyadmin/version_info)"

NEW_VERSION_INFO="$NEW_VERSION"
[ "$NEW_VERSION" == "$NEW_PMA_VERSION" ] || [ -z "$NEW_PMA_VERSION" ] || NEW_VERSION_INFO="$NEW_PMA_VERSION ($NEW_VERSION)"

# sync phpMyAdmin files
if [ -z "$OLD_VERSION" ]; then
    echo "Initializing phpMyAdmin $NEW_VERSION_INFO..."
else
    echo "Upgrading phpMyAdmin $OLD_VERSION_INFO to $NEW_VERSION_INFO..."
fi

rsync -rlptog --delete --chown www-data:www-data \
    "/usr/src/phpmyadmin/phpmyadmin/" \
    "/var/www/html/"

rsync -lptog --chown www-data:www-data \
    "/usr/src/phpmyadmin/version_info" \
    "/var/www/pma_version_info"
