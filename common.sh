#!/bin/bash

QUBES_GENTOO_KEYID=9FA64B92F95E706BF28E2CA6484010B5CDC576E2

find_qubes_ebuilds() {
    local OVERLAYDIR="$1"
    find "$OVERLAYDIR" -type f -name ".qubes-*.ebuild.0" 2>/dev/null
}

update_manifest() {
    local ebuild="$1"
    local GPGID="${2:-"$QUBES_GENTOO_KEYID"}"
    GEMATO="$(command -v gemato)"
    if [ -z "$GEMATO" ]; then
        echo "Cannot find 'gemato'"
        exit 1
    fi
    if [ -e "$ebuild" ]; then
        pkg_dir="$(dirname "$ebuild")"
        if [ -n "$(git -C "$pkg_dir" diff .)" ] || [ -n "$(git -C "$pkg_dir" status -s .)" ] || [ ! -e $pkg_dir/Manifest ]; then
            rm -f "$pkg_dir/Manifest"
            pushd "$pkg_dir" || exit 1
            GNUPG=qubes-gpg-client "$GEMATO" create -s -k "$GPGID" -H "BLAKE2B SHA512" "$pkg_dir"
            sed -i 's|^DATA \(.*.ebuild.*\)$|EBUILD \1|g' "$pkg_dir/Manifest"
            sed -i 's|^DATA files/\(.*\)$|AUX \1|g' "$pkg_dir/Manifest"
            popd || exit 1
        fi
    else
        echo "Cannot find ebuild directory $ebuild"
        exit 1
    fi
}

bump_version() {
    local ebuild0="$1"
    repo="$(grep -R QubesOS/qubes- "$ebuild0")"
    qubes_name="${repo//*qubes-/}"
    qubes_name="${qubes_name//.git\"/}"
    version=$(curl --silent https://raw.githubusercontent.com/qubesos/qubes-${qubes_name}/master/version)
    if [ -n "$version" ]; then
        pkg_dir="$(dirname "$ebuild0")"
        name="${ebuild0/.}"
        name="${name/.ebuild.0/}"
        pushd "$pkg_dir" || exit 1
        ln -sf "$(basename "$ebuild0")" "${name}-${version}.ebuild"
        git add "${name}-${version}.ebuild"
        popd || exit 1
    fi
}

clear_older_version() {
    local ebuild0="$1"
    pkg_dir="$(dirname "$ebuild0")"
    pushd "$pkg_dir" || exit 1
    older_ebuilds="$(find . -type f -name "qubes-*.ebuild" 2>/dev/null | sort --version-sort | head -n -2)"
    for ebuild in $older_ebuilds
    do
        rm "$ebuild"
        git rm "$ebuild"
    done
    popd || exit 1
}

update_overlay() {
    local OVERLAYDIR
    OVERLAYDIR="$(readlink -f "$1")"
    if [ -d "$OVERLAYDIR" ]; then
        ebuilds="$(find_qubes_ebuilds "$OVERLAYDIR")"
        for ebuild in $ebuilds
        do
            bump_version "$ebuild"
            clear_older_version "$ebuild"
            update_manifest "$ebuild"
        done
    else
        echo "Cannot find overlay directory $OVERLAYDIR"
        exit 1
    fi
}
