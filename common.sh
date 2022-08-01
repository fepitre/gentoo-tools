#!/bin/bash

QUBES_GENTOO_KEYID=9FA64B92F95E706BF28E2CA6484010B5CDC576E2

find_qubes_ebuilds() {
    local OVERLAYDIR="$1"
    find "$OVERLAYDIR" -type f -name ".qubes-*.ebuild.0" 2>/dev/null
}

get_version_ebuild() {
    local ebuild="$1"
    if [ -e "$ebuild" ]; then
        ebuild="$(basename "$ebuild")"
        ebuild="${ebuild/.ebuild/}"
        version="${ebuild##*-}"
        echo "$version"
    fi
}

update_manifest() {
    local ebuild="$1"
    local GPGID="${2:-"$QUBES_GENTOO_KEYID"}"
    GEMATO="$(command -v gemato)"
    if [ -z "$GEMATO" ]; then
        echo "Cannot find 'gemato'"
        return 1
    fi
    if [ -e "$ebuild" ]; then
        pkg_dir="$(dirname "$ebuild")"
        if [ -n "$(git -C "$pkg_dir" diff .)" ] || [ -n "$(git -C "$pkg_dir" status -s .)" ] || [ ! -e "$pkg_dir/Manifest" ]; then
            rm -f "$pkg_dir/Manifest"
            pushd "$pkg_dir" || return 1
            GNUPG=qubes-gpg-client "$GEMATO" create -s -k "$GPGID" -H "BLAKE2B SHA512" "$pkg_dir"
            sed -i 's|^DATA \(.*.ebuild.*\)$|EBUILD \1|g' "$pkg_dir/Manifest"
            sed -i 's|^DATA files/\(.*\)$|AUX \1|g' "$pkg_dir/Manifest"
            popd || return 1
        fi
    else
        echo "Cannot find ebuild directory $ebuild"
        return 1
    fi
}

bump_version() {
    local ebuild0="$1"
    repo="$(grep -R QubesOS/qubes- "$ebuild0")"
    branch=master
    if grep -R release4.1 "$ebuild0"; then
        branch="release4.1"
    fi
    qubes_name="${repo//*qubes-/}"
    qubes_name="${qubes_name//.git\"/}"
    version=$(curl --silent https://raw.githubusercontent.com/qubesos/qubes-${qubes_name}/${branch}/version)
    if [ -n "$version" ]; then
        pkg_dir="$(dirname "$ebuild0")"
        name="${ebuild0/.}"
        name="$(basename "${name/.ebuild.0/}")"
        pushd "$pkg_dir" || return 1
        ln -sf "$(basename "$ebuild0")" "${name}-${version}.ebuild"
        git add "${name}-${version}.ebuild"
        update_manifest "$ebuild"
        if [ -n "$(git diff .)" ] || [ -n "$(git status -s .)" ]; then
            commit_msg="app-emulation/$name: bump to version ${version}"
            git add Manifest
            git commit -m "$commit_msg"
        fi
        popd || return 1
    fi
}

clear_older_version() {
    local ebuild0="$1"
    pkg_dir="$(dirname "$ebuild0")"
    name="$(basename "$pkg_dir")"
    pushd "$pkg_dir" || return 1
    older_ebuilds="$(find . -name "qubes-*.ebuild" 2>/dev/null | sort --version-sort | head -n -2)"
    for ebuild in $older_ebuilds
    do
        unlink "$ebuild"
        git rm "$ebuild"
        update_manifest "$ebuild0"
        if [ -n "$(git diff .)" ] || [ -n "$(git status -s .)" ]; then
            commit_msg="app-emulation/$name: drop old $(get_version_ebuild "$ebuild")"
            git add Manifest
            git commit -m "$commit_msg"
        fi
    done
    popd || return 1
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
        done
    else
        echo "Cannot find overlay directory $OVERLAYDIR"
        return 1
    fi
}
