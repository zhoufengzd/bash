#!/usr/bin/env bash
## run service
source $BASH_UTIL_LIB/params.sh

svc_list="airflow|elasticsearch|h2o|hadoop|kibana|mongo|mysql|nifi|postgres|rabbit|redis"
function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <service name> <action: start | stop | reset | status>"
    echo "  service supported: [$svc_list]"
}

function __killx {
    local target=$1
    local excluded=$2
    if [ -z $target ]; then return; fi

    #local pids=()
    if [ -z $excluded ]; then
        pids=$(ps -ef | grep $target | grep -v "grep" | awk '{print $2}')
    else
        pids=$(ps -ef | grep $target | grep -v -e $excluded -e "grep" | awk '{print $2}')
    fi

    pid_list="${pids[*]}"
    if [ ! -z "$pid_list" ]; then
        cmd="kill $pid_list"
        echo $cmd && $cmd
    fi
}

function main() {
    __parse_arguments
    clear

    local svc_name=${args[0]}
    if [ -z $svc_name ]; then
        __help; exit
    fi

    local action=${args[1]}
    if [ -z $action ]; then
        action="start"
    fi

    profile_path=".""$svc_name""_env"
    /host/bin/service/svc_env.sh set $svc_name $profile_path && source $profile_path && rm $profile_path
    local pids=""
    if [[ $svc_name == "airflow" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            echo "airflow scheduler"
            airflow scheduler >> /dev/null 2>&1 &
            sleep 3
            echo "airflow webserver -p $AIRFLOW_PORT_WEB"
            airflow webserver -p $AIRFLOW_PORT_WEB &
        elif [[ $action == "stop" ]]; then
            pids=$(ps -ef | grep "airflow scheduler" | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then kill $pids; sleep 2; fi
            pids=$(ps -ef | grep airflow | grep master | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then kill $pids; sleep 3; fi
            pids=$(ps -ef | grep "airflow run" | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then kill $pids; sleep 0; fi
            pids=$(ps -ef | grep airflow | grep webserver | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then kill $pids; sleep 0; fi
        elif [[ $action == "reset" ]]; then
            echo "airflow resetdb"
            airflow resetdb
            sudo rm -rf $HOME/airflow/logs/*
        fi
    elif [[ $svc_name == "elasticsearch" ]] || [[ $svc_name == "es" ]]  || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            sudo -u svc $ELASTICSEARCH_HOME/bin/elasticsearch &
            sleep 5
            $KIBANA_HOME/bin/kibana &
        elif [[ $action == "stop" ]]; then
            pids=$(ps -ef | grep "bootstrap.Elasticsearch" | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then sudo kill $pids; sleep 0; fi
            pids=$(ps -ef | grep "kibana" | grep -v grep | awk '{print $2}')
            if [ ! -z "$pids" ]; then kill $pids; sleep 0; fi
        fi
    elif [[ $svc_name == "hadoop" ]] || [[ $svc_name == "all" ]]; then
        echo "not supported!"
    elif [[ $svc_name == "mongo" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            mongod --dbpath /host/data/mongo &
        elif [[ $action == "stop" ]]; then
            __killx mongod
        fi
    elif [[ $svc_name == "mysql" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            mysql.server start
        elif [[ $action == "stop" ]]; then
            mysql.server stop
        fi
    elif [[ $svc_name == "nifi" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            nifi.sh start
        elif [[ $action == "stop" ]]; then
            nifi.sh stop
        elif [[ $action == "status" ]]; then
            nifi.sh status
        fi
    elif [[ $svc_name == "rabbit" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            rabbitmq-plugins enable rabbitmq_management
            rabbitmq-server &
        elif [[ $action == "stop" ]]; then
            rabbitmqctl stop
        elif [[ $action == "status" ]]; then
            rabbitmqctl status
        fi
    elif [[ $svc_name == "redis" ]] || [[ $svc_name == "all" ]]; then
        if [[ $action == "start" ]]; then
            redis-server $REDIS_HOME/redis.conf
        elif [[ $action == "stop" ]]; then
            __killx "redis-server"
        fi
    else
        echo "Error! Service $svc_name is not configured. Please add $svc_name to svc_env.sh first. "
    fi
}

main
