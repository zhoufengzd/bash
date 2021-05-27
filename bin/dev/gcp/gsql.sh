#!/usr/bin/env bash
## automatically set up proxy and connect to instances
source $BASH_LIB/argparse.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <cloud_sql_instance> [OPTIONS]"
    echo "  cloud_sql_instance: [project-id]:<db_server> or <db_server>. "
    echo "     may use \"?\" to represent any project-id or db server. for example: "
    echo "       \"?:?\" will list all running db server in all projects. "
    echo "       \"?\" will list all running db server in current project. "
    echo "  additional options: "
    echo "    -u|--user: user name"
    echo "    -pwd|--password: optional password"
    echo "    -d|--database: database name"
    echo "    -p|--port: proxy ports."
}

key_map["u"]="user"
key_map["pwd"]="password"
key_map["d"]="database"
key_map["p"]="port"

declare -A server_map
declare -A sql_version_map
target=""
target_db_version=""

function __list_all_db_server {
    local target_proj=$1
    local target_server=$2

    local map_idx=1
    local projects=$(gcloud projects list | grep -v "PROJECT_ID" | awk '{print $1}')
    for proj in ${projects[@]}; do
        if [[ $target_proj != "?" ]] && [[ $target_proj != $proj ]]; then
            continue
        fi

        IFS=$'\n' out_lines=($(gcloud sql instances list --project $proj | grep RUNNABLE)) IFS=$default_ifs
        for line in "${out_lines[@]}"; do
            local server=$(echo $line | awk '{print $1}')
            local db_version=$(echo $line | awk '{print $2}')
            local zone=$(echo $line | awk '{print $3}')
            server_map[$map_idx]="$proj:$zone:$server"
            sql_version_map[$map_idx]=$db_version

            if [[ $target_server == $server ]]; then
                target=${server_map[$map_idx]}
                target_db_version=$db_version
                return
            fi

            map_idx=$((map_idx+1))
        done
    done
}

function main() {
    __parse_arguments

    #1. check input project / vm name
    local sql_args=${args[0]}
    IFS=":"; read -a proj_sql <<< "${sql_args}"; IFS=$default_ifs
    if [ ${#proj_sql[@]} -eq 1 ]; then  # no spec of project, default to current
        gcp_project=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
        sql_name=${proj_sql[0]}
    elif [ ${#proj_sql[@]} -eq 2 ]; then
        gcp_project=${proj_sql[0]}
        sql_name=${proj_sql[1]}
    fi
    if [ -z $sql_name ]; then
        __help; exit
    fi

    #2. build target.
    ##  -- check running instances, fetch project / zone info
    echo "check running cloud sql server..."
    __list_all_db_server $gcp_project $sql_name
    if [ ${#server_map[@]} -eq 0 ]; then
        echo "Error! Can't locate any running cloud sql server!"; exit
    fi

    ##  -- check user's choice if needed
    if [[ "$sql_name" == "?" ]]; then  # prompt user to choose from running instance
        echo ""
        local map_idx=1
        while [ $map_idx -le ${#server_map[@]} ]; do
            echo "$map_idx: ${server_map[$map_idx]}"
            map_idx=$((map_idx+1))
        done

        echo "Please pick the server to connect [enter 0 to quit]:"
        read map_idx
        if [ $map_idx -lt 1 ]; then
            exit
        fi
        target="${server_map[$map_idx]}"
        target_db_version="${sql_version_map[$map_idx]}"
    fi

    # start building the command
    local cmd=""

    ##  -- client and port
    local default_port=0
    if [[ $target_db_version == MYSQL* ]]; then  # e.g., MYSQL_5_7
        client="mysql"
        default_port=3306
    else  # e.g., POSTGRES_9_6
        client="psql"
        default_port=5432
    fi
    if [ -z $port ]; then
        port=$default_port
    fi

    ##  -- user and password, db_name
    db_user=${args["user"]}
    db_password=${args["password"]}
    db_name=${args["database"]}
    if [[ $client == "psql" ]]; then
        if [ -z $db_user ]; then
            db_user="postgres"
        fi
        cmd="psql -h 127.0.0.1 -p $port -U $db_user"
        if [ ! -z $db_name ]; then
            cmd+=" -d $db_name"
        fi
    else
        if [ -z $db_user ]; then
            db_user="mysql"
        fi
        cmd="mysql -h 127.0.0.1 --port $port -u $db_user -p $db_password"
        if [ ! -z $db_name ]; then
            cmd+=" $db_name"
        fi
    fi

    local proxy_cmd="cloud_sql_proxy -instances=$target=tcp:$port & "
    echo $proxy_cmd
    #sh -c "$proxy_cmd"

    echo $cmd
    #sh -c "$cmd"
}

main
