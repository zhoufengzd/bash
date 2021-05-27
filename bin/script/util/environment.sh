#!/usr/bin/env sh

function script_name() {
    # expect ${BASH_SOURCE[0]}
    local bash_src=$1
    script_name=$(basename "$bash_src")
    echo ${script_name}
}

function wk_dir() {
    echo $(pwd)
}

function script_dir() {
    # expect ${BASH_SOURCE[0]}
    local bash_src=$1
    local script_path=${bash_src}
    if [ -L "$bash_src" ]; then
        script_path=$(readlink ${bash_src})
    fi
    script_dir="$(cd "$(dirname "${script_path}")" && pwd)"
    echo ${script_dir}
}
