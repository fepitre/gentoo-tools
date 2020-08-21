#!/bin/bash

[[ "$DEBUG" == 1 ]] && set -x

OVERLAYDIR="$(readlink -f "$1")"
GPGID="${2:-9FA64B92F95E706BF28E2CA6484010B5CDC576E2}"

GEMATO="$(command -v gemato)"

if [ -z "$GEMATO" ]; then
    echo "Cannot find 'gemato'"
    exit 1
fi

if [ -d "$OVERLAYDIR" ]; then
    ebuilds="$(find "$OVERLAYDIR" -type f -name "*.ebuild.0")"
    for ebuild in $ebuilds
    do
        pkg_dir="$(dirname "$ebuild")"
	if [ -n "$(git -C "$pkg_dir" diff .)" ] || [ ! -e $pkg_dir/Manifest ]; then
            rm -f "$pkg_dir/Manifest"
            GNUPG=qubes-gpg-client "$GEMATO" create -s -k "$GPGID" -H "BLAKE2B SHA512" "$pkg_dir"
            sed -i 's|^DATA \(.*.ebuild.*\)$|EBUILD \1|g' "$pkg_dir/Manifest"
            sed -i 's|^DATA files/\(.*\)$|AUX \1|g' "$pkg_dir/Manifest"
        fi
    done
else
    echo "Cannot find overlay directory $OVERLAYDIR"
    exit 1
fi
