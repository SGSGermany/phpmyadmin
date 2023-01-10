#!/bin/bash
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

set -eu -o pipefail
export LC_ALL=C

cmd() {
    echo + "$@"
    "$@"
    return $?
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

# checkout Git repo of the image to merge
echo + "mkdir ./vendor"
mkdir "$BUILD_DIR/vendor"

echo + "git -C ./vendor/ init"
git -C "$BUILD_DIR/vendor/" init

echo + "git -C ./vendor/ remote add origin $MERGING_IMAGE_GIT_REPO"
git -C "$BUILD_DIR/vendor/" remote add "origin" "$MERGING_IMAGE_GIT_REPO"

echo + "MERGING_IMAGE_GIT_COMMIT=\"\$(git -C ./vendor/ ls-remote --refs origin $MERGING_IMAGE_GIT_REF | tail -n 1 | cut -f 1)\""
MERGING_IMAGE_GIT_COMMIT="$(git -C "$BUILD_DIR/vendor/" ls-remote --refs origin "$MERGING_IMAGE_GIT_REF" | tail -n 1 | cut -f 1)"

echo + "git -C ./vendor/ fetch --depth 1 origin $MERGING_IMAGE_GIT_COMMIT"
git -C "$BUILD_DIR/vendor/" fetch --depth 1 origin "$MERGING_IMAGE_GIT_COMMIT"

echo + "git -C ./vendor/ checkout --detach $MERGING_IMAGE_GIT_COMMIT"
git -C "$BUILD_DIR/vendor/" checkout --detach "$MERGING_IMAGE_GIT_COMMIT"

# validate Dockerfile of the image to merge
echo + "[ -f ./vendor/$MERGING_IMAGE_BUD_CONTEXT/Dockerfile ]"
if [ ! -f "$BUILD_DIR/vendor/$MERGING_IMAGE_BUD_CONTEXT/Dockerfile" ]; then
    echo "ERROR: Invalid image to merge: Dockerfile '$BUILD_DIR/vendor/$MERGING_IMAGE_BUD_CONTEXT/Dockerfile' not found" >&2
    exit 1
fi

echo + "MERGING_IMAGE_BASE_IMAGE=\"\$(sed -n -e 's/^FROM\s*\(.*\)$/\1/p' ./vendor/$MERGING_IMAGE_BUD_CONTEXT/Dockerfile)\""
MERGING_IMAGE_BASE_IMAGE="$(sed -n -e 's/^FROM\s*\(.*\)$/\1/p' "$BUILD_DIR/vendor/$MERGING_IMAGE_BUD_CONTEXT/Dockerfile")"

echo + "[[ $MERGING_IMAGE_BASE_IMAGE =~ $MERGING_IMAGE_BASE_IMAGE_REGEX ]]"
if ! [[ "$MERGING_IMAGE_BASE_IMAGE" =~ $MERGING_IMAGE_BASE_IMAGE_REGEX ]]; then
    echo "ERROR: Invalid image to merge: Expecting original base image to match '$MERGING_IMAGE_BASE_IMAGE_REGEX', got '$MERGING_IMAGE_BASE_IMAGE'" >&2
    exit 1
fi

# build base image
echo + "buildah bud -t $IMAGE-base --from $BASE_IMAGE ./vendor/$MERGING_IMAGE_BUD_CONTEXT"
buildah bud -t "$IMAGE-base" --from "$BASE_IMAGE" "$BUILD_DIR/vendor/$MERGING_IMAGE_BUD_CONTEXT"

echo + "rm -rf ./vendor"
rm -rf "$BUILD_DIR/vendor"

# build image
echo + "CONTAINER=\"\$(buildah from $IMAGE-base)\""
CONTAINER="$(buildah from "$IMAGE-base")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rm -f …/docker-entrypoint.sh"
rm -f "$MOUNT/docker-entrypoint.sh"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/"
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

echo + "mv …/var/www/html …/usr/src/phpmyadmin/html"
mv "$MOUNT/var/www/html" "$MOUNT/usr/src/phpmyadmin/phpmyadmin"

echo + "PMA_VERSION=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$VERSION\"')\""
PMA_VERSION="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$VERSION"')"

echo + "PMA_SHA256=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$SHA256\"')\""
PMA_SHA256="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$SHA256"')"

echo + "PMA_URL=\"\$(buildah run $CONTAINER -- /bin/sh -c 'echo \"\$URL\"')\""
PMA_URL="$(buildah run "$CONTAINER" -- /bin/sh -c 'echo "$URL"')"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/src/phpmyadmin/version_info" -- \
        VERSION "$PMA_VERSION" \
        SHA256 "$PMA_SHA256" \
        URL "$PMA_URL"

cmd buildah run "$CONTAINER" -- \
    chown -R www-data:www-data \
        "/usr/src/phpmyadmin/phpmyadmin" \
        "/usr/src/phpmyadmin/version_info" \
        "/var/www"

cmd buildah run "$CONTAINER" -- \
    apk add --no-cache --virtual .pma-run-deps \
        rsync

cmd buildah run "$CONTAINER" -- \
    adduser -u 65538 -s "/sbin/nologin" -D -h "/" -H mysql

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    "$CONTAINER"

cmd buildah config \
    --volume "/var/www" \
    --volume "/run/mysql" \
    "$CONTAINER"

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
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="phpMyAdmin" \
    --annotation org.opencontainers.image.description="A php-fpm container of phpMyAdmin." \
    --annotation org.opencontainers.image.version="$PMA_VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/phpmyadmin" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

cmd buildah commit "$CONTAINER" "$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "$IMAGE:${TAGS[0]}" "$IMAGE:$TAG"
done

