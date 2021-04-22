#!/usr/bin/env bash
## build local dev directories

wk_dir=$(pwd)
workspace=$HOME/workspace

function _mkdir() {
    mkdir -p $workspace/git

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
    local desktop=$HOME/Desktop

    if [ ! -f $desktop/daily.md ]; then
        touch $workspace/local/tmp/misc/daily.md
        touch $workspace/local/tmp/misc/random.json
        ln -s $workspace/local/tmp/misc/daily.md $desktop/daily.md
        ln -s $workspace/local/tmp/misc/random.json $desktop/random.json
    fi
}

function _update_venv() {
    ln -s $(pwd)/venv/py_env/_requirements $workspace/bin/svc/bin/venv/py_env/_requirements
}

function _update_env_alias() {
    if [ ! -e $HOME/.env ]; then
        ln -s $workspace/bin/_config/env $HOME/.env
        ln -s $workspace/bin/_config/alias $HOME/.alias
    fi
}

function main() {
    _mkdir
    _update_env_alias
    _update_venv
    _update_desktop
}

main
