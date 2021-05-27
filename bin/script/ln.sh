#!/usr/bin/env bash
## -- link files by pattern
source $BASH_UTIL_LIB/argparse.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

# global variables
src_pattern=""
symbolic=""
recursive="false"
preview="false"
flattern="false"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <source_dir/pattern> <target_dir> [-s] [-r] [-p] [--flattern]"
    echo "  pattern: like \"\\.sh\", or \"gcp\", etc. "
    echo "    -- note: do *NOT* put wildcard in patterns. "
    echo "  optional flags: "
    echo "    -s: build symbolic links"
    echo "    -r: recursively"
    echo "    -p: preview only"
    echo "    --flattern: flattern the links directly under target_dir."
}

function __build_links {
    local src_dir=$1
    local tgt_dir=$2

    cd $src_dir #&& echo "-- @$src_dir"
    local commands=()
    local idx=0
    IFS=$'\n' files=$(ls) IFS=$default_ifs
    for fl in ${files[@]}; do
        if [ -z $src_pattern ] || [[ $fl == *"$src_pattern"* ]]; then
            commands[$idx]="ln $symbolic $src_dir/$fl $fl" && idx=$((idx+1))
        fi
    done

    if [ ${#commands[@]} -lt 0 ]; then
        cd $wk_dir && return
    fi
    mkdir -p $tgt_dir && cd $tgt_dir && echo "=> @$tgt_dir"
    for cmd in "${commands[@]}"; do
        if [ ! -z $preview ]; then
            echo -e "-- preview: $cmd"
        else
            echo -e "$cmd" && $cmd
        fi
    done
    cd $wk_dir
}

function main() {
    __parse_arguments

    if [ $args_count -lt 2 ]; then
        __help; exit
    fi

    local src_args="${args[0]}"
    local src_dir="$src_args"
    if [ ! -d "$src_dir" ]; then
        src_dir=$(dirname "$src_args")
        src_pattern=$(basename "$src_args")
    fi
    src_dir="$(cd $src_dir && pwd)"

    local tgt_dir="${args[1]}"
    tgt_dir="$(cd $tgt_dir && pwd)"

    symbolic=${args["s"]}
    if [ ! -z $symbolic ]; then symbolic="-s"; fi
    recursive=${args["r"]}
    preview=${args["p"]}
    flattern=${args["flattern"]}
    echo "-- $src_dir|$src_pattern => $tgt_dir"
    echo "     recursive=$recursive preview=$preview flattern=$flattern"
    echo ""

    local src_dirs=($src_dir)
    if [ ! -z $recursive ]; then src_dirs=($(find $src_dirs -type d | sort)); fi
    for sd in "${src_dirs[@]}"; do
        if [[ $flattern != "false" ]]; then
            __build_links $sd $tgt_dir
        else
            __build_links $sd "$tgt_dir""${sd/$src_dir/}"
        fi
    done
}

main
