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

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "Container environment file 'container.env' not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

# pull current image
echo + "CONTAINER=\"\$(buildah from $REGISTRY/$OWNER/$IMAGE:${TAGS[0]})\"" >&2
CONTAINER="$(buildah from "$REGISTRY/$OWNER/$IMAGE:${TAGS[0]}" || true)"

if [ -z "$CONTAINER" ]; then
    echo "Failed to pull image '$REGISTRY/$OWNER/$IMAGE:${TAGS[0]}': No image with this tag found" >&2
    echo "Image rebuild required" >&2
    echo "build"
    exit
fi

# run `pacman -Sy` and `pacman -Qu` to check for package updates
echo + "buildah run $CONTAINER -- pacman -Sy" >&2
buildah run "$CONTAINER" -- pacman -Sy >&2

echo + "PACKAGE_UPGRADES=\"\$(buildah run $CONTAINER -- pacman -Qu)\"" >&2
PACKAGE_UPGRADES="$(buildah run "$CONTAINER" -- sh -c 'pacman -Qu || true')"

if [ -n "$PACKAGE_UPGRADES" ]; then
    echo "Image is out of date: Package upgrades are available" >&2
    echo "$PACKAGE_UPGRADES" >&2
    echo "Image rebuild required" >&2
    echo "build"
    exit
fi
