#!/usr/bin/env bash
##   setup shell script links
wk_dir=$(pwd)

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name [--symbolic | -s]"
}

## -- build links from src_dir to target_dir
function __build_links {
    local src_dir=$1
    local file_ext=$2
    local optional_link_flag=$3

    cd $src_dir
    local file_filter="*"$file_ext
    local file_list=($(ls *$file_ext))
    for fl in ${file_list[@]}; do
        cmd="ln $optional_link_flag $src_dir/$fl $wk_dir/$fl"
        echo $cmd && $cmd
    done
    cd $wk_dir
}

function main() {
    local arg=$1
    if [[ $arg == "-h" ]] || [[ $arg == "--help" ]]; then
        __help; exit
    fi

    local link_flag=""
    if [[ $arg == "-s" ]] || [[ $arg == "--symbolic" ]]; then
        link_flag="-s"
    fi

    # bash profile
    ln $link_flag $HOME/workspace/local_dev/bash/profile/bash_profile_remote $HOME/.bash_profile
    ln $link_flag $HOME/workspace/local_dev/bash/profile/bashrc $HOME/.bashrc
    ln $link_flag /usr/local/bin/gtar $wk_dir/tar

    __build_links $HOME/workspace/local_dev/bash "sh" $link_flag

    __build_links $HOME/workspace/local_dev/bash/docker "sh" $link_flag
    __build_links $HOME/workspace/local_dev/bash/docker/bin/env "sh" $link_flag
    __build_links $HOME/workspace/local_dev/bash/docker/bin/service "sh" $link_flag

    __build_links $HOME/workspace/local_dev/bash/gcp "sh" $link_flag

    __build_links $HOME/workspace/local_dev/python/db "py" $link_flag
}

main $1
