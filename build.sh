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
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

VERSION="$(git_latest "$MERGE_IMAGE_GIT_REPO" "$VERSION_PATTERN")"

git_clone "$MERGE_IMAGE_GIT_REPO" "refs/tags/$VERSION" "$BUILD_DIR/vendor" "./vendor"

echo + "HASH=\"\$(git -C ./vendor rev-parse HEAD)\"" >&2
HASH="$(git -C "$BUILD_DIR/vendor" rev-parse HEAD)"

con_build --tag "$IMAGE-base" \
    --from "$BASE_IMAGE" --check-from "$MERGE_IMAGE_BASE_IMAGE_PATTERN" \
    "$BUILD_DIR/vendor/$MERGE_IMAGE_BUD_CONTEXT" "./vendor/$MERGE_IMAGE_BUD_CONTEXT"

echo + "CONTAINER=\"\$(buildah from $(quote "$IMAGE-base"))\"" >&2
CONTAINER="$(buildah from "$IMAGE-base")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rm -f …/docker-entrypoint.sh" >&2
rm -f "$MOUNT/docker-entrypoint.sh"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

echo + "mv …/var/www/html …/usr/src/phpmyadmin/phpmyadmin" >&2
mv "$MOUNT/var/www/html" "$MOUNT/usr/src/phpmyadmin/phpmyadmin"

cmd buildah run "$CONTAINER" -- \
    chown root:root "/usr/src/phpmyadmin/phpmyadmin"

cmd buildah run "$CONTAINER" -- \
    chmod 755 "/usr/src/phpmyadmin/phpmyadmin"

echo + "mkdir -p …/var/www/html" >&2
mkdir -p "$MOUNT/var/www/html"

cmd buildah run "$CONTAINER" -- \
    chown www-data:www-data "/var/www/html"

echo + "PMA_VERSION=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$VERSION\"')\"" >&2
PMA_VERSION="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$VERSION"')"

echo + "PMA_SHA256=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$SHA256\"')\"" >&2
PMA_SHA256="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$SHA256"')"

echo + "PMA_URL=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$URL\"')\"" >&2
PMA_URL="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$URL"')"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/src/phpmyadmin/version_info" -- \
        VERSION "$VERSION" \
        HASH "$HASH" \
        PMA_VERSION "$PMA_VERSION" \
        PMA_SHA256 "$PMA_SHA256" \
        PMA_URL "$PMA_URL"

pkg_install "$CONTAINER" --virtual .pma-run-deps \
    rsync

user_add "$CONTAINER" mysql 65538

cleanup "$CONTAINER"

cmd buildah config \
    --label org.opencontainers.image.title- \
    --label org.opencontainers.image.description- \
    --label org.opencontainers.image.version- \
    --label org.opencontainers.image.url- \
    --label org.opencontainers.image.source- \
    --label org.opencontainers.image.documentation- \
    --label org.opencontainers.image.authors- \
    --label org.opencontainers.image.vendor- \
    --label org.opencontainers.image.licenses- \
    --env MAX_EXECUTION_TIME- \
    --env MEMORY_LIMIT- \
    --env UPLOAD_LIMIT- \
    --env VERSION- \
    --env SHA256- \
    --env URL- \
    "$CONTAINER"

cmd buildah config \
    --env PMA_VERSION="$PMA_VERSION" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    "$CONTAINER"

cmd buildah config \
    --volume "/var/www" \
    --volume "/run/mysql" \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="phpMyAdmin" \
    --annotation org.opencontainers.image.description="A php-fpm container running phpMyAdmin." \
    --annotation org.opencontainers.image.version="$PMA_VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/phpmyadmin" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
