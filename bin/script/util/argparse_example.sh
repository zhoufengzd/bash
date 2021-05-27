#!/usr/bin/env bash
##   shows the usage of argparse.sh with named and positional arguments
source $BASH_LIB/argparse.sh
source $BASH_LIB/environment.sh

key_map["h"]="host"
key_map["p"]="port"

## environment: source directory and script name
script_dir="$(script_dir ${BASH_SOURCE[0]})"
script_name="$(script_name ${BASH_SOURCE[0]})"
wk_dir="$(wk_dir ${BASH_SOURCE[0]})"

function __help() {
    #script_name=$(basename "$0")
    echo "Usage: $script_name <action> <target> [options]"
    echo "  example: $script_name -h localhost -p 8088 "
}

function main() {
    __parse_arguments
    echo "## arguments parsed:"
    echo action=${args[0]}
    echo target=${args[1]}
    echo host=${args["host"]}
    echo port=${args["port"]}

    echo ""
    echo "## environment:"
    echo script_dir=$script_dir
    echo script_name=$script_name
    echo wk_dir=$wk_dir
}

main
