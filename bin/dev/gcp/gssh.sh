#!/usr/bin/env bash
## automatically figure project / zone info, build parameters for ssh tunneling
source $BASH_LIB/argparse.sh
source $BASH_LIB/constants.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help() {
    script_name=$(basename "$0")
    echo "Usage: $script_name <vm_instance> [OPTIONS]"
    echo "  vm_instance: [project-id]:<vm> or <vm>. "
    echo "     may use \"?\" to represent any project-id or vm. for example: "
    echo "       \"?:?\" will list all running vm in all projects. "
    echo "       \"?\" will list all running vm in current project. "
    echo "  additional options: "
    echo "    -p|--port: ssh tunnel ports. multiple port options are delimited by \";\""
    echo "               by default each port is mapped to the local same port. "
    echo "               also support explicit mapping, in the format of \"remote_port=local_port;\""
    echo "               for example: --port \"8080\", or --port \"8080=18080;8081\" "
    echo "    -z|--zone: vm_instance time zone. default to current configuration."
}

key_map["p"]="port"
key_map["z"]="zone"

declare -A vm_map
target=""

## list all vm under each project
function __list_all_vms {
    local target_proj=$1
    local target_vm=$2

    local map_idx=1
    local projects=$(gcloud projects list | grep -v "PROJECT_ID" | awk '{print $1}')
    for proj in ${projects[@]}; do
        if [[ $target_proj != "?" ]] && [[ $target_proj != $proj ]]; then
            continue
        fi

        IFS=$'\n' vm_lines=($(gcloud compute instances list --project $proj 2>/dev/null | grep RUNNING)) IFS=$default_ifs
        for vm_line in "${vm_lines[@]}"; do
            local vm=$(echo $vm_line | awk '{print $1}')
            local zone=$(echo $vm_line | awk '{print $2}')

            vm_map[$map_idx]="$vm --project $proj --zone $zone"
            if [[ $target_vm == $vm ]]; then
                target=${vm_map[$map_idx]}
                return
            fi

            map_idx=$((map_idx+1))
        done
    done
}

function main() {
    __parse_arguments

    #1. check input project / vm name
    local vm_args=${args[0]}
    IFS=":"; read -a proj_vm <<< "${vm_args}"; IFS=$default_ifs
    if [ ${#proj_vm[@]} -eq 1 ]; then  # no spec of project, default to current
        gcp_project=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
        vm_name=${proj_vm[0]}
    elif [ ${#proj_vm[@]} -eq 2 ]; then
        gcp_project=${proj_vm[0]}
        vm_name=${proj_vm[1]}
    fi
    if [ -z $vm_name ]; then
        __help; exit
    fi

    #2. build target.
    ##  -- check running instances, fetch project / zone info
    echo "check running vm..."
    __list_all_vms $gcp_project $vm_name
    if [ ${#vm_map[@]} -eq 0 ]; then
        echo "Error! Can't locate any running vm!"; exit
    fi

    ##  -- check user's choice if needed
    if [[ "$vm_name" == "?" ]]; then  # prompt user to choose from running instance
        echo ""
        local map_idx=1
        while [ $map_idx -le ${#vm_map[@]} ]; do
            echo "$map_idx: ${vm_map[$map_idx]}"
            map_idx=$((map_idx+1))
        done

        echo "Please pick the vm to connect [enter 0 to quit]:"
        read map_idx
        if [ $map_idx -lt 1 ]; then
            exit
        fi
        target="${vm_map[$map_idx]}"
    fi

    #3. build the command and execute it
    local cmd="gcloud compute ssh $target"

    ##  -- ssh tunnel
    vm_ssh_ports=${args["port"]}
    local local_port=""
    local remote_port=""
    if [ ! -z $vm_ssh_ports ] && [[ $vm_ssh_ports != $VALUE_DUMMY ]]; then
        IFS=";"; read -a port_array <<< "${vm_ssh_ports}"; IFS=$default_ifs
        for port_opt in ${port_array[@]}; do
            IFS="="; read -a port_pair <<< "${port_opt}"; IFS=$default_ifs
            if [ ${#port_pair[@]} -eq 2 ]; then
                remote_port=${port_pair[0]}
                local_port=${port_pair[1]}
            else
                remote_port=${port_pair[0]}
                local_port=${port_pair[0]}
            fi
            cmd+=" --ssh-flag=\"-L $local_port:localhost:$remote_port\""
        done

    fi

    clear && echo "...$ "$cmd && echo $SC_LONG_LINE
    sh -c "$cmd"
}

main
