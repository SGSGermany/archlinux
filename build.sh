#!/bin/bash
# Arch Linux
# @SGSGermany's base image for containers based on Arch Linux.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
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

trunc() {
    for FILE in "$@"; do
        if [ -f "$FILE" ]; then
            : > "$FILE"
        elif [ -d "$FILE" ]; then
            find "$FILE" -mindepth 1 -delete
        fi
    done
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "Container environment file 'container.env' not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $BASE_IMAGE)\""
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

cmd buildah run "$CONTAINER" -- \
    pacman -Syu --noconfirm

cmd buildah run "$CONTAINER" -- \
    pacman -Sc --noconfirm

echo + "trunc …/run …/tmp …/var/cache/pacman/pkg …/var/log/pacman.log …/var/tmp"
trunc \
    "$MOUNT/run" \
    "$MOUNT/tmp" \
    "$MOUNT/var/cache/pacman/pkg" \
    "$MOUNT/var/log/pacman.log" \
    "$MOUNT/var/tmp"

echo + "rm -f …/etc/resolv.conf"
rm -f \
    "$MOUNT/etc/resolv.conf"

cmd buildah config \
    --annotation org.opencontainers.image.title="Arch Linux" \
    --annotation org.opencontainers.image.description="@SGSGermany's base image for containers based on Arch Linux." \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/archlinux" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

cmd buildah commit "$CONTAINER" "localhost/$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "localhost/$IMAGE:${TAGS[0]}" "localhost/$IMAGE:$TAG"
done
