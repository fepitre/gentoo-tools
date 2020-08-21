#!/bin/bash

[[ $DEBUG == 1 ]] && set -x

ebuild0="$(ls .*ebuild.0)"
repo="$(grep -R QubesOS/qubes- "$ebuild0")"
# qubes_name="$(echo "$repos" | sed 's|.*qubes-\(.*\).git"|\1|')"
qubes_name="${repo//*qubes-/}"
qubes_name="${qubes_name//.git\"/}"
version=$(curl https://raw.githubusercontent.com/qubesos/qubes-${qubes_name}/master/version)
if [ -n "$version" ]; then
    name="${ebuild0/.}"
    name="${name/.ebuild.0/}"

    ln -sf "$ebuild0" "${name}-${version}.ebuild"
fi