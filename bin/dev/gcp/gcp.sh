#!/usr/bin/env bash
##   Helper function to interact with google cloud
. $BASH_LIB/argparse.sh
. $BASH_LIB/constants.sh
. $BASH_LIB/environment.sh
. $BASH_LIB/script_util.sh

## environment:
script_dir="$(__script_dir ${BASH_SOURCE[0]})"
script_name="$(__script_name ${BASH_SOURCE[0]})"
wk_dir="$(__wk_dir ${BASH_SOURCE[0]})"

## default profile
default_profile_path=$HOME/.env/gcp_env

function __help {
    sed -e "s/{{script_name}}/${script_name}/g" \
			$script_dir/_config/gcp/help.info
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
            __run_cmd $script_dir/_config/gcp/info.cmd.sh
        fi
    else
        if [ -z $proj_opt ]; then
            echo "Error! Target project is expected. "; exit
        fi

        cat $script_dir/_config/gcp/default_pre.config  > $default_profile_path  && echo "" >> $default_profile_path
        cat $script_dir/_config/gcp/$proj_opt.config    >> $default_profile_path && echo "" >> $default_profile_path
        cat $script_dir/_config/gcp/default_post.config >> $default_profile_path && echo "" >> $default_profile_path

        . $default_profile_path
        gcloud config set project $GCP_PROJECT
    fi
}

main
