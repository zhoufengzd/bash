#!/usr/bin/env bash
## build local dev directories

wk_dir=$(pwd)
workspace=$HOME/workspace

function _mkdir() {
    mkdir -p $workspace/git/_config

    mkdir -p $workspace/local/test
    mkdir -p $workspace/local/tmp/downloads
    mkdir -p $workspace/local/tmp/misc

    mkdir -p $workspace/bin/_config/env
    mkdir -p $workspace/bin/_config/alias
    mkdir -p $workspace/bin/script
    mkdir -p $workspace/bin/dev
    mkdir -p $workspace/bin/svc/data/data
    mkdir -p $workspace/bin/svc/data/config
    mkdir -p $workspace/bin/svc/data/log
    mkdir -p $workspace/bin/svc/bin/venv/py_env
    mkdir -p $workspace/bin/svc/bin/venv/js_env
    mkdir -p $workspace/bin/docker
}

function _update_desktop() {
    # build some convenient desktop links
    local desktop=$HOME/Desktop

    if [ ! -f $desktop/daily.md ]; then
        local links=(daily.md random.json random.sql random.py)
        for f in ${links[@]}; do
            touch $workspace/local/tmp/misc/$f
            ln -s $workspace/local/tmp/misc/$f $desktop/$f
        done
    fi
}

function _update_profile() {
    local profiles=(.bash_profile)

    # backup existing profile
    cd $HOME
    for f in ${profiles[@]}; do
        if [[ ! -L ${f} && -e ${f} ]]; then
            cmd="mv ${f} ${f}.bak"
            echo $cmd && $cmd
        fi
    done

    cd $wk_dir
    cmd="ln -s $wk_dir/bin/_config/profile/bash_profile.sh $HOME/.bash_profile"
    echo $cmd && $cmd
}

function _link_env_alias() {
    if [ ! -e $HOME/.env ]; then
        ln -s $workspace/bin/_config/env $HOME/.env
        ln -s $workspace/bin/_config/alias $HOME/.alias
    fi
}

function _link_git_config() {
    if [ ! -e $workspace/git/_config/gitconfig ]; then
        local links=(gitconfig git-credentials)
        for f in ${links[@]}; do
            touch $HOME/.$f
            ln -s $HOME/.$f $workspace/git/_config/$f
        done
    fi
}

function main() {
    _mkdir
    _link_env_alias
    _link_git_config
    _update_desktop
    _update_profile
}

main
