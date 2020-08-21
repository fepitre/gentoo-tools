#!/bin/bash

[[ "$DEBUG" == 1 ]] && set -x

DIR="$(readlink -f "$1")"
GPGID="${2:-9FA64B92F95E706BF28E2CA6484010B5CDC576E2}"
FLAVOR="$3"

if [ -z "$FLAVOR" ]; then
    CACHEDIR=cache_gentoo
else
    CACHEDIR="cache_gentoo_$FLAVOR"
fi

if [ -d "$DIR" ]; then
    if [ -e "$DIR/$CACHEDIR/binpkgs/Packages" ]; then
        qubes-gpg-client-wrapper --local-user "$GPGID" --armor --detach-sign -o "$DIR/$CACHEDIR/binpkgs/Packages.gpgsig" "$DIR/$CACHEDIR/binpkgs/Packages"
        rsync -av --progress --delete "$DIR/$CACHEDIR/binpkgs/" mirror.notset.fr:"/data/gentoo/qubes/${FLAVOR:-gnome}/"
    fi
else
    echo "Cannot find directory $DIR"
    exit 1
fi
