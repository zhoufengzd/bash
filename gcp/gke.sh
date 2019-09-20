#!/usr/bin/env bash
##   Help interact with google container engine
source $BASH_UTIL_LIB/params.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <target> [options]"
    echo "  action: [push|pull|delete|info|run|stop|connect|setenv]"
    echo "    note: all actions are docker image operations except \"setenv\"."
    echo "  target: <image_tag | image_tag=image_id>"
    echo "     image_tag: <tag_name | image_name:image_version>. use \"?\" to list all images."
    echo "     to push/upload image, requires both image_tag and image_id in local docker images."
    echo "     to run image or pull/download image to local docker repository, only image_tag is needed."
    echo "  options  "
    echo "    -- image options:"
    echo "      -p|--project: gcp project. "
    echo "      -c|--cluster: kubenetes cluster name. optional when running image. use the current one if not set. "
    echo "      -b|--storage: gcs bucket. default to \"gcr.io\". may also use \"us.gcr.io\""
    echo "    -- deployment options:"
    echo "      --port: port exposed when running image. "
    echo "      --replicas: default to 1"
    echo "    -- service options:"
    echo "      -s|--service: service flag. Only if set, the image will be exposed as service. "
    echo "           e.g., < -s | -s \"service_name\" > service name is optional."
    echo "      --type: service type. default to ClusterIP. other options: NodePort, LoadBalancer, ExternalName"
}

key_map["p"]="project"
key_map["c"]="cluster"
key_map["b"]="storage"
key_map["s"]="service"

declare -A cluster_list  ## cluster spec list
declare -A cluster_map   ## cluster name -> cluster spec (name, project, zone)

function __list_all_clusters {
    local target_proj=$1
    local target_cluster=$2
    cluster_list=()
    cluster_map=()

    local map_idx=1
    local projects=$(gcloud projects list | grep -v "PROJECT_ID" | awk '{print $1}')
    for proj in ${projects[@]}; do
        if [[ $target_proj != "?" ]] && [[ $target_proj != $proj ]]; then
            continue
        fi

        IFS=$'\n' out_lines=($(gcloud container clusters list --project $proj 2>/dev/null | grep RUNNING)) IFS=$default_ifs
        for line in "${out_lines[@]}"; do
            local cluster=$(echo $line | awk '{print $1}')
            local zone=$(echo $line | awk '{print $2}')
            cluster_list[$map_idx]="$cluster --zone $zone --project $proj"
            cluster_map[$cluster]=${cluster_list[$map_idx]}

            if [[ $target_cluster == $cluster ]]; then
                return
            fi
            map_idx=$((map_idx+1))
        done
    done
}

function main() {
    __parse_arguments
    local cmd=""

    #1. check action and target
    local action=${args[0]}
    if [ -z $action ]; then
        __help; exit
    fi

    ##1.1 -- image: <image_name:image_version>=image_id
    local target_args=${args[1]}
    IFS="="; read -a target_pair <<< "${target_args}"; IFS=$default_ifs
    local image_tag=${target_pair[0]}
    if [ -z $image_tag ]; then
        __help; exit
    fi
    local image_id=${target_pair[1]}
    if [ -z $image_id ] && [[ $action == "push" ]]; then
        __help; exit
    fi
    IFS=":"; read -a image_pair <<< "${image_tag}"; IFS=$default_ifs
    local image_name=${image_pair[0]}
    local image_version=${image_pair[1]}

    ##1.2 -- gcp project: check project, and switch project if needed
    local curr_proj=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
    local gcp_project=${args["project"]}
    if [ -z $gcp_project ] || [[ $gcp_project == $VALUE_DUMMY ]]; then
        gcp_project=$curr_proj
    fi
    if [[ $gcp_project != $curr_proj ]] || [[ $action == "setenv" ]]; then
        cmd="gcloud config set project $gcp_project"
        echo $cmd && $cmd
    fi

    ##1.3 -- kubernetes cluster
    local cluster=${args["cluster"]}
    local cluster_default=$(gcloud info | grep cluster | awk '{print $2}')
    cluster_default=${cluster_default//"["/} && cluster_default=${cluster_default//"]"/}
    if [ -z $cluster ] || [[ $cluster == $VALUE_DUMMY ]]; then
        cluster=$cluster_default
    fi
    if [[ $cluster != $cluster_default ]] || [[ $action == "setenv" ]]; then
        __list_all_clusters $gcp_project $cluster
        cmd="gcloud container clusters get-credentials ${cluster_map[$cluster]}"
        echo $cmd && $cmd
    fi

    local image_bucket=${args["storage"]}
    if [ -z $image_bucket ]; then
        image_bucket="gcr.io"
    fi
    local image_spec="$image_bucket/$gcp_project/$image_tag"

    local service=${args["service"]}
    #echo action=$action service=$service image_spec=$image_spec

    #2. actions
    if [[ $action == "info" ]]; then
        echo "current project: $curr_proj"
        echo ""
        cmd="gcloud projects list"
        echo $cmd && $cmd && echo ""

        cmd="gcloud container clusters list"
        echo $cmd && $cmd && echo ""

        echo "gcloud container images list --repository=$image_bucket/$gcp_project"
        IFS=$'\n' out_lines=($(gcloud container images list --repository=$image_bucket/$gcp_project 2>/dev/null)) IFS=$default_ifs
        for line in "${out_lines[@]}"; do
            if [[ $image_tag == "?" ]] || [[ $line == $image_spec* ]]; then
                echo $line
            fi
        done

        echo ""
        cmd="gcloud compute firewall-rules list"
        echo $cmd && $cmd 2> /dev/null && echo ""
    elif [[ $action == "push" ]]; then
        cmd="docker tag $image_id $image_spec" && echo $cmd && $cmd
        cmd="gcloud docker -- push $image_spec" && echo $cmd && $cmd
        cmd="docker rmi $image_spec" && echo $cmd && $cmd
    elif [[ $action == "delete" ]]; then
        cmd="gcloud container images delete $image_tag --repository=$image_bucket/$gcp_project"
        echo $cmd && $cmd
    elif [[ $action == "run" ]]; then
        ###1. deployment

        ### -- ready to deploy
        cmd="kubectl run $image_name --image=$image_spec"
        local port=${args["port"]}
        if [ -z $port ]; then
            if [ ! -z $service ]; then
                echo "Error! port is not specified."; echo ""; exit
            fi
        else
            cmd+=" --port=$port"
        fi

        local replicas=${args["replicas"]}
        if [ -z $replicas ]; then
            replicas="1"
        fi
        cmd+=" --replicas=$replicas"
        echo $cmd && $cmd

        ###2. expose as service?
        if [ ! -z $service ]; then
            if [[ $service == $VALUE_DUMMY ]]; then
                service=$image_name
            fi
            cmd="kubectl expose deployment $image_name --name=$service"

            local type=${args["type"]}
            if [ -z $type ]; then
                type="ClusterIP"
            fi
            cmd+=" --type=$type"

            if [ ! -z $port ]; then
                cmd+=" --port=$port"
            fi

            echo $cmd && $cmd
        fi
    elif [[ $action == "stop" ]]; then
        ### delete ingress and service
        if [ ! -z $service ] ; then
            if [[ $service == $VALUE_DUMMY ]]; then
                service=$image_name
            fi
            cmd="kubectl delete ingress $service"
            echo $cmd && $cmd > /dev/null 2>&1
        fi

        if [ ! -z $service ] ; then
            if [[ $service == $VALUE_DUMMY ]]; then
                service=$image_name
            fi
            cmd="kubectl delete service $service"
            echo $cmd && $cmd
        fi

        ### delete deployment
        cmd="kubectl delete deployment $image_name"
        echo $cmd && $cmd

        ### delete from pods
        IFS=$'\n' out_lines=($(kubectl get pods 2>/dev/null | grep $image_name)) IFS=$default_ifs
        local pods=""
        for line in "${out_lines[@]}"; do
            pod_spec="$(echo $line | awk '{print $1}')"  # airflow-708121430-h64pl
            pod_name=${pod_spec:0:${#image_name}}
            if [[ $pod_name == $image_name ]]; then
                pods+="$pod "
            fi
        done
        if [ ! -z $pods ]; then
            cmd="kubectl delete pods $pods --grace-period=0 --force"
            echo $cmd && $cmd
        fi
    elif [[ $action == "connect" ]]; then
        ### connect one of the running pods
        IFS=$'\n' out_lines=($(kubectl get pods 2>/dev/null | grep Running | grep $image_name)) IFS=$default_ifs
        local pods=""
        for line in "${out_lines[@]}"; do
            pod_spec="$(echo $line | awk '{print $1}')"  # airflow-708121430-h64pl
            pod_name=${pod_spec:0:${#image_name}}
            if [[ $pod_name == $image_name ]]; then
                cmd="kubectl exec -it $pod_spec -- bash"
                echo $cmd && $cmd
                break
            fi
        done
    fi

    ##3. reset
    if [[ $action != "setenv" ]]; then
        if [[ $gcp_project != $curr_proj ]]; then
            cmd="gcloud config set project $curr_proj"
            echo $cmd && $cmd
        fi
        if [[ $cluster != $cluster_default ]]; then
            __list_all_clusters $curr_proj $cluster_default
            cmd="gcloud container clusters get-credentials ${cluster_map[$cluster]}"
            echo $cmd && $cmd
        fi
    fi
}

main
