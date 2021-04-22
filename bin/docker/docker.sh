#!/usr/bin/env bash

source $BASH_UTIL_LIB/params.sh
key_map["h"]="host"
key_map["p"]="port"
key_map["m"]="mount"
key_map["e"]="entrypoint"
key_map["v"]="preview"

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help() {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <image_name> [options]"
    echo "  action: [run|rm,remove|c,config]. "
    echo "    remove:  remove stoped containers and images. "
    echo "    config: set default docker mount directories, docker hostname, etc. "
    echo "  image_name: "
    echo "    tag or id to run or remove images."
    echo "  options:"
    echo "    -h|--host: set docker hostname, default to \$DOCKER_HOSTNAME."
    echo "    -p|--port: <[local:]remote>. e.g., -p \"18080:8080;8081\""
    echo "    -m|--mount: mount host directories, default to \$DOCKER_MOUNT_DIR."
    echo "    -e|--entrypoint: <entrypoint[=arguments]>. entry point command with optional arguments. default: \"sh\""
    echo "    -v|--preview: preview list of targets only. "
}

function __set_env() {
    local profile_path="$HOME/.env/docker_env"

    local host_dir="/host"
    local source_dir="$HOME/workspace/docker_images/_shared"
    local -a dirs=(bin config data log downloads workspace)

    mkdir -p $host_dir && cd $host_dir
    echo "#!/usr/bin/env bash" > $profile_path
    echo "" >> $profile_path
    echo "export DOCKER_HOSTNAME=\"$(hostname)\"" >> $profile_path
    for dir_mapped in ${dirs[@]}; do
        if [ -L $dir_mapped ]; then sudo unlink $dir_mapped; fi
        sudo ln -s $source_dir/$dir_mapped $dir_mapped

        echo "export DOCKER_MOUNT_DIR=\"\$DOCKER_MOUNT_DIR -v $source_dir/$dir_mapped:/host/$dir_mapped\"" >> $profile_path
    done

    cmd="cat $profile_path"
    echo $cmd && echo "" && $cmd
    cd $wk_dir
}

function main() {
    __parse_arguments

    local action=${args[0]}
    if [ -z $action ]; then
        __help; return
    fi

    if [[ $action == "config" ]] || [[ $action == "c" ]]; then
        __set_env; return
    fi

    image=${args[1]}
    local cmd=""
    if [[ $action == "remove" ]] || [[ $action == "rm" ]]; then
        cids=$(docker ps -a -q -f status=exited)
        if [ ! -z "$cids" ]; then
            cmd="docker rm -v $cids"
            echo $cmd && if [ -z ${args["preview"]} ]; then $cmd > /dev/null 2>&1; fi
        fi

        if [ -z "$image" ] || [[ $image == "-"* ]]; then image="<none>"; fi
        imgids=$(docker images | grep "$image" | awk '{print $3}')
        if [ ! -z "$imgids" ]; then
            echo "docker images | grep \"$image\""
            docker images | grep "$image"
            cmd="docker rmi -f $imgids"
            echo "" && echo $cmd && if [ -z ${args["preview"]} ]; then $cmd > /dev/null 2>&1; fi
        fi
        return
    fi

    ## docke run...
    if [[ $action != "run" ]] || [ -z "$image" ]; then
        __help; return
    fi

    cmd="docker run "
    if [ ! -z ${args["host"]} ]; then
        if [[ "${args["host"]}" == $VALUE_DUMMY ]]; then
            cmd+=" -h $DOCKER_HOSTNAME"
        else
            cmd+=" -h ${args["host"]}"
        fi
    fi

    local ports=""
    if [ ! -z ${args["port"]} ] && [[ ${args["port"]} != $VALUE_DUMMY ]]; then
        IFS=";"; read -a element_array <<< "${args["port"]}"; IFS=$default_ifs
        for element in ${element_array[@]}; do
            if [[ $element == *":"* ]]; then
                ports+=" -p $element"
            else
                ports+=" -p $element:$element"
            fi
        done
        cmd+="\n    $ports"
    fi

    if [ ! -z ${args["mount"]} ]; then
        if [[ "${args["mount"]}" == $VALUE_DUMMY ]]; then
            cmd+="\n    $DOCKER_MOUNT_DIR"
        else
            cmd+="\n    ${args["mount"]}"
        fi
    fi

    local entrycmd="sh"
    if [ ! -z ${args["entrypoint"]} ] && [[ "${args["entrypoint"]}" != $VALUE_DUMMY ]]; then
        IFS="="; read -a element_array <<< "${args["entrypoint"]}"; IFS=$default_ifs
        entrycmd=${element_array[0]}
        entrycmd_args=${element_array[1]}
    fi
    cmd+="\n    -it --entrypoint $entrycmd $image $entrycmd_args"

    cmd=$(echo -e "$cmd")
    echo "" && echo $cmd && if [ -z ${args["preview"]} ]; then $cmd; fi
}

main
