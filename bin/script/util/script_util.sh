#!/usr/bin/env sh

function __load_file() {
    local in_file=$1
    local skip_comment=$2

    local idx=0
    local project_name=""
    local read_settings="false"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $skip_comment != "false" ]]; then
            if [[ ${line:0:1} == "#" ]] || [ -z "$line" ]; then
                continue
            fi
        fi

        lines[$idx]="$line" && idx=$((idx+1))
    done < "$in_file"
    IFS=$default_ifs
}

function __run_cmd() {
    local in_file=$1
    __load_file $in_file
    for cmd in "${lines[@]}"; do
        echo $cmd && echo $SC_SHORT_LINE && $cmd && echo $SC_SHORT_LINE && echo ""
    done
}