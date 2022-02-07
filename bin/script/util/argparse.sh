#!/usr/bin/env sh

# command line arguments and constants
__arguments=("$@")  # raw arguments

declare -A args
declare -i args_count
declare -A key_map

VALUE_DUMMY="true"
KEY_HELP="help"

key_map["h"]=$KEY_HELP

function __try_map_key {
    local key=$1
    local mapped_key=${key_map[$key]}
    if [ ! -z $mapped_key ]; then
        echo "$mapped_key"
    else
        echo "$key"
    fi
}

function __parse_arguments {
    local key=""
    local idx=0
    local mapped_element=""

    if [[ ${#__arguments[@]} -lt 1 ]]; then
        __help; exit 0;
    fi

    for element in "${__arguments[@]}"; do
        # echo "element = \"$element\""

        # log element using indexes.
        #   try map element only if it does not contain spaces
        if [[ $element != ${element// /} ]]; then
            args[$idx]=$element
        else
            args[$idx]=$(__try_map_key $element)
        fi
        idx=$((idx+1))

        if [[ -z $key ]] || [[ $element == "-"* ]]; then
            # remove "-" or "--", then try map the key
            key=$(__try_map_key ${element//"-"/})
            args[$key]=$VALUE_DUMMY
        else
            # echo "args[$key]=$element"
            args[$key]=$element; key=""; element=""
        fi
    done
    args_count=idx
    # echo "${args[*]}"   # print all args

    # check required parameters
    if [ ! -z ${args[$KEY_HELP]} ]; then
        __help; exit 0;
    fi
}
