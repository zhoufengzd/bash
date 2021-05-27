#!/usr/bin/env bash
#set -e
source $BASH_LIB/argparse.sh

key_map["h"]="host"
key_map["p"]="port"

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help() {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <target> [options]"
    echo "  action: [run|rm,remove|c,config]. "
    echo "    rm|remove:  remove leftover entries."
    echo "    config: set default configurations"
    echo "  target: "
    echo "    script target"
    echo "  options:"
    echo "    -h|--host: hostname"
    echo "    -p|--port: host port"
}

function main() {
    __parse_arguments
    echo "## arguments parsed:"
    echo action=${args[0]}
    echo target=${args[1]}
    echo host=${args["host"]}
    echo port=${args["port"]}
}

main
