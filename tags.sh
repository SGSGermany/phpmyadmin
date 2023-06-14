#!/bin/bash
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
export LC_ALL=C

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

if ! podman image exists "$IMAGE:${TAGS%% *}"; then
    echo "Missing built image '"$IMAGE:${TAGS%% *}"': No image with this tag found" >&2
    exit 1
fi

PMA_VERSION="$(podman image inspect --format '{{range .Config.Env}}{{printf "%q\n" .}}{{end}}' "$IMAGE:${TAGS%% *}" \
    | sed -ne 's/^"VERSION=\(.*\)"$/\1/p')"
if [ -z "$PMA_VERSION" ]; then
    echo "Unable to read image's env variable 'VERSION': No such variable" >&2
    exit 1
elif ! [[ "$PMA_VERSION" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
    echo "Unable to read image's env variable 'VERSION': '$PMA_VERSION' is no valid version" >&2
    exit 1
fi

PMA_VERSION_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
PMA_VERSION_MAJOR="${BASH_REMATCH[1]}"

TAG_DATE="$(date -u +'%Y%m%d%H%M')"

TAGS=(
    "v$PMA_VERSION" "v${PMA_VERSION}_$TAG_DATE"
    "v$PMA_VERSION_MINOR" "v${PMA_VERSION_MINOR}_$TAG_DATE"
    "v$PMA_VERSION_MAJOR" "v${PMA_VERSION_MAJOR}_$TAG_DATE"
    "latest"
)

printf 'VERSION="%s"\n' "$PMA_VERSION"
printf 'TAGS="%s"\n' "${TAGS[*]}"
