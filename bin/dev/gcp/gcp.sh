#!/usr/bin/env bash
##   Help interact with google cloud
source $BASH_UTIL_LIB/params.sh
source $BASH_UTIL_LIB/constants.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

shared_settings="__shared__"
projects=""
declare -A project_settings

default_profile_path=$HOME/.env/gcp_env

### specialized config function
function __load_config() {
    local in_file=$1
    local proj=$2

    project_settings=()
    projects=""

    local idx=0
    local project_name=""
    local read_settings="false"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ ${line:0:1} == "#" ]] || [ -z "$line" ]; then  # skip comments and empty lines
            continue
        fi

        if [[ ${line:0:1} == "[" ]]; then
            project_name=${line//"["/}
            project_name=${project_name//"]"/}

            if [[ $project_name != "$shared_settings" ]]; then
                if [[ ! -z $projects ]]; then
                    projects+="|"
                fi
                projects+=$project_name
            fi

            if [[ $project_name == "$proj" ]] || [[ $project_name == "$shared_settings" ]]; then
                read_settings="true"
            else
                read_settings="false"
            fi
            continue
        fi

        if [[ $read_settings == "true" ]]; then
            #IFS="="; read -a element_array <<< "${line}"; IFS=''
            #project_settings[${element_array[0]}]=${element_array[1]}
            project_settings[$idx]="$line" && idx=$((idx+1))
        fi
    done < "$in_file"
    IFS=$default_ifs
}

function __help {
    if [ -z $projects ]; then
        __load_config $script_dir/gcp.config "$shared_settings"
    fi

    script_name=$(basename "$0")
    echo "Usage: $script_name <action> [project]"
    echo "  action: [info|setenv]"
    echo "  project: [$projects] "
    echo "    required for \"setenv\". check \"$script_dir/gcp.config\" for more detail."
    echo "    optional for \"info\". may use \"?\" to get detailed info for current project."
}

function main() {
    __parse_arguments
    local action=${args[0]}
    local proj_opt=${args[1]}
    if [ -z $action ]; then
        __help; exit
    fi

    local cmd=""
    if [[ $action == "info" ]]; then
        local curr_proj=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
        echo $SC_SHORT_LINE
        echo "current project: $curr_proj"
        echo $SC_SHORT_LINE && echo ""

        if [ ! -z $proj_opt ]; then
            cmd="gcloud projects list"
            echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""

            cmd="gcloud config list"
            echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""

            cmd="gcloud auth list"
            echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""

            cmd="gcloud container clusters list"
            echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""

            #cmd="gcloud components list"
            #echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""
        fi
    else
        if [ -z $proj_opt ]; then
            echo "Error! Target project is expected. "; exit
        fi

        __load_config $script_dir/gcp.config $proj_opt
        echo "# gcp project environment settings" > $default_profile_path
        #echo "export KUBECONFIG=\$KUBECONFIG:\$HOME/.kube/config" >> $default_profile_path
        echo "" >> $default_profile_path

        for ((i=0; i<${#project_settings[*]}; i++)); do
            echo "${project_settings[$i]}" >> $default_profile_path
        done

        source $default_profile_path
        cmd="gcloud config set project $GCP_PROJECT"
        echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""

        ## TODO: temporarily disabled
        # cmd="gcloud config set compute/region $GCP_REGION"
        # echo $cmd && $cmd > /dev/null 2>&1
        # cmd="gcloud config set compute/zone $GCP_ZONE"
        # echo $cmd && echo $SC_SHORT_LINE && $cmd > /dev/null 2>&1 && echo ""
        #
        # if [ ! -z "$GCP_CLUSTER" ]; then
        #     cmd="gcloud container clusters get-credentials $GCP_CLUSTER"
        #     echo $cmd && echo $SC_SHORT_LINE && $cmd && echo ""
        # fi
    fi
}

main
