#!/usr/bin/env bash
#set -e
source $BASH_LIB/argparse.sh
source $BASH_LIB/constants.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

# global variables
declare -A projects
declare -A distribute_targets
repo_root=""
repo_root_default="Data"
log_file=$wk_dir"/build_"$(date '+%Y%m%d_%H%M%S').log

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> [repo_root]"
    echo "  action: "
    echo "    pull: pull from git."
    echo "    build: build local projects"
    echo "    pack : pack into single tar file and upload to gcs. "
    echo "      pack=[all]|[s|source]|[j|jar]. may set optional pack target. default is source files only. "
    echo "    config: check config on each repo. "
    echo "      use [config-] to remove auto generated configurations. "
    echo "  repo_root: [Data|Other]. default to \"\$GIT_ROOT\Data\". "
    echo "      optionally: use \".\" for current directory."
}

function __load_config {
    local in_file=$1
    if [ ! -e $in_file ]; then
        echo "Error! Can't locate project config file $in_file. "
        exit
    fi

    local proj_idx=0
    local dist_idx=0
    default_ifs="$IFS"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $line = \#* ]] || [ -z $line ]; then  # skip comments and empty lines
            continue
        fi

        if [[ $line = "[projects]"* ]]; then
            proj_idx=1
            dist_idx=0
            continue
        elif [[ $line = "[distribute_targets]"* ]]; then
            proj_idx=0
            dist_idx=1
            continue
        elif [[ $line = "["* ]]; then  ## unknown section
            echo "Warning: Unknown section $line ignored. "
            proj_idx=0
            dist_idx=0
            continue
        fi

        if [ $proj_idx -gt 0 ]; then
            projects[$proj_idx]=$line
            proj_idx=$((proj_idx+1))
        elif [ $dist_idx -gt 0 ]; then
            distribute_targets[$dist_idx]=$line
            dist_idx=$((dist_idx+1))
        fi
    done < "$in_file"
    IFS=$default_ifs
}

function __clean {
    local proj_dir=$1
    local CLEAN_SCRIPT="clean_source_code.sh"

    cd $repo_root/$proj_dir
    if [ -e pom.xml ]; then
        echo "cd $proj_dir && mvn clean"
        mvn clean > /dev/null 2>&1
    fi

    if [ -e $CLEAN_SCRIPT ]; then  ## allow customized cleaning before package the source
        echo "cd $proj_dir && $CLEAN_SCRIPT"
        ./$CLEAN_SCRIPT #> /dev/null 2>&1
    fi

    cd $wk_dir
}

function __mvn_build {
    local proj_dir=$1

    cd $repo_root/$proj_dir
    if [ -e pom.xml ]; then
        echo $SC_LONG_LINE >> $log_file
        echo "cd $proj_dir && mvn clean install ..."
        mvn clean install -Dmaven.test.skip=true >> $log_file
        echo $SC_LONG_LINE >> $log_file
    fi

    cd $wk_dir
}

function __mvn_package {
    local proj_dir=$1
    local target_dir=$2

    cd $repo_root/$proj_dir
    if [ -e pom.xml ]; then
        echo $default_SC_LONG_LINE >> $log_file
        echo "cd $proj_dir && mvn package ..."
        mvn package -Dmaven.test.skip=true >> $log_file
        echo $default_SC_LONG_LINE >> $log_file

        if [ ! -z $target_dir ] && [ -d $target_dir ]; then
            local target="$(basename $(pwd))"
            target=${target//"zd-gcp-analytic-"/}
            target=${target//"zd-gcp-"/}
            target_jar=$target".jar"

            # copy jar file
            local source_jar=$(ls target/*.jar | grep -v original)
            cp $source_jar $target_dir/$target_jar  ## make the distributed jar version independent
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $source_jar ==> $target_jar " >> $target_dir/package.log

            # copy configurations
            # cp *.yaml $target_dir/
        fi
    fi

    ls $target_dir/
    cd $wk_dir
}

function __upload {
    local jar_file=$1
    local update_log="update.log"
    local gcs_dir=${repo_root//"$HOME/"/}

    gcs_bucket=$GCP_STAGING_BUCKET
    if [ -z $gcs_bucket ]; then
        gcp_project=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
        gcs_bucket="staging-"$gcp_project
    fi

    echo "-- upload to gcs..."
    cmd="gsutil cp $jar_file $gcs_bucket/$gcs_dir/"
    echo $cmd && sh -c "$cmd" > /dev/null 2>&1

    echo $(date -u +"%Y-%m-%dT%H:%M:%SZ") > $update_log \
        && gsutil cp $update_log $gcs_bucket/$gcs_dir/ > /dev/null 2>&1 && rm $update_log

    ## provide download hint
    echo "-- to download: gsutil cp $gcs_bucket/$gcs_dir/$jar_file ./ "
    echo ""
}

# pack into tar.gz
function __pack {
    local target=$1
    distribute_dir="_distributed"
    git_tar_file="git_src.tar.gz"
    build_tar_file="git_build.tar.gz"

    if [ -z $target ]; then
        target="all"
    fi

    if [[ $target == "j"* ]] || [[ $target == "all" ]]; then
        echo "-- build distributed jars..."
        for proj in ${distribute_targets[@]}; do
            __mvn_package $proj $repo_root/$distribute_dir
        done
        rm -f $log_file
        echo ""

        echo "-- pack jar files..."
        cd $repo_root
        cmd="tar -czf $HOME/$build_tar_file $distribute_dir"
        echo $cmd && sh -c "$cmd" && echo ""

        cd $HOME && __upload $build_tar_file && rm $build_tar_file && cd $wk_dir
    fi

    if [[ $target == "s"* ]] || [[ $target == "all" ]]; then
        echo "-- clean project source..."
        local target_list=""
        for proj in ${projects[@]}; do
            target_list+=" "$proj
            __clean $proj
        done

        echo ""
        echo "-- pack project source files..."
        cd $repo_root
        cmd="tar -czf $HOME/$git_tar_file $target_list"
        echo $cmd && sh -c "$cmd" && echo ""

        cd $HOME && __upload $git_tar_file && rm $git_tar_file && cd $wk_dir
    fi
}

function __build {
    local current_root=$1
    cd $current_root

    echo "" && echo "-- @$current_root"
    local git_projects=($(ls -l | grep ^d | awk '{print $9}' | grep -v _archive))
    if [ ${#git_projects[@]} -eq 0 ]; then cd $wk_dir && return; fi
    for proj in ${git_projects[@]}; do
        __mvn_build $proj
    done
    rm -f $log_file

    cd $wk_dir
}

function __do_pull() {
    IFS=$'\n' branches=($(git branch --list)) IFS=$default_ifs
    for branch in "${branches[@]}"; do
        branch=${branch//"*"/} ## remove mark on active branch
        branch=${branch//" "/}
        cmd="git pull origin $branch"
        echo "-- $cmd" && $cmd
    done
}

function __pull {
    local current_root=$1
    cd $current_root
    echo "" && echo "-- @$current_root"

    if [ -d "$current_root/.git" ]; then
        __do_pull
        return
    fi

    local git_projects=($(ls -l | grep ^d | awk '{print $9}'))
    if [ ${#git_projects[@]} -eq 0 ]; then cd $wk_dir && return; fi
    local branch=""
    for proj in ${git_projects[@]}; do
        if [[ $proj == "_"* ]]; then
            continue;
        fi
        if [ ! -d "$current_root/$proj/.git" ]; then
            ## check sub directories
            __pull "$current_root/$proj"
            continue
        fi

        echo "-- cd $proj " && cd $current_root/$proj
        __do_pull
    done
    cd $wk_dir
}

function __config {
    local current_root=$1
    local config_option=$2

    cd $current_root
    local git_projects=($(ls -l | grep ^d | awk '{print $9}' | grep -v _archive))
    if [ ${#git_projects[@]} -eq 0 ]; then cd $wk_dir && return; fi

    echo "" && echo "-- @$current_root"
    local branch=""
    for proj in ${git_projects[@]}; do
        if [ ! -d "$current_root/$proj/.git" ]; then
            ## check sub directories
            __config "$current_root/$proj" $config_option
            continue;
        fi

        echo "-- cd $proj " && cd $current_root/$proj
        if [ -z $config_option ] && [ ! -e ".gitconfig" ]; then
            cmd="ln $HOME/.gitconfig .gitconfig"
            echo $cmd && sh -c "$cmd"
        elif [[ $config_option == "-" ]] && [ -e ".gitconfig" ]; then
            cmd="unlink .gitconfig"
            echo $cmd && sh -c "$cmd"
        fi
    done
    cd $wk_dir
}

function main() {
    __parse_arguments

    IFS="="; read -a action_pair <<< "${args[0]}"; IFS=$default_ifs
    local action=${action_pair[0]}
    local action_flag=${action_pair[1]}
    if [ -z $action ]; then
        __help; exit
    fi

    local repo_root=${args[1]}
    if [ -z $repo_root ]; then
        repo_root=$GIT_ROOT/$repo_root_default
    elif [[ $repo_root == "." ]]; then
        repo_root=$wk_dir
    elif [ ! -d $repo_root ]; then
        repo_root=$GIT_ROOT/$repo_root
    fi

    if [ -e $repo_root/git.config ]; then
        __load_config $repo_root/git.config
    fi

    start_time=$(date +%Y-%m-%dT%H:%M:%S)
    if [[ $action == "pack" ]]; then
        __pack $action_flag
    elif [[ $action == "build" ]]; then
        __build $repo_root
    elif [[ $action == "pull" ]]; then
        __pull $repo_root
    elif [[ $action == config* ]]; then
        __config $repo_root ${action//"config"/}
    else
        echo "-- invalid action: $action" && echo "" &&  __help && return
    fi
    end_time=$(date +%Y-%m-%dT%H:%M:%S)
    echo "-- started at: $start_time. completed at: $end_time"
    echo ""
}

main
