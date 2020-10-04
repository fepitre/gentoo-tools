#!/bin/bash

[[ "$DEBUG" == 1 ]] && set -x

DIR="$(readlink -f "$1")"
GPGID="${2:-9FA64B92F95E706BF28E2CA6484010B5CDC576E2}"

for flavor in gnome xfce minimal
do
    if [ -e "$DIR/$flavor/Packages" ]; then
        qubes-gpg-client-wrapper --local-user "$GPGID" --armor --detach-sign -o "$DIR/$flavor/Packages.gpgsig" "$DIR/$flavor/Packages"
    fi
done
