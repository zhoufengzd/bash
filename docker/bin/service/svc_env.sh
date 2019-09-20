#!/usr/bin/env bash
## build service profile
source $BASH_UTIL_LIB/params.sh

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

default_profile_path="$HOME/.env/service_env"
service_home="/host/bin/service"
config_home="/host/config"
svc_list="airflow|elasticsearch|h2o|hadoop|kibana|mongo|mysql|nifi|postgres|rabbit|redis"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name  <action> <svc_name> [profile_path]. "
    echo "  -- Update service profile. \"profile_path\" default to $default_profile_path if not set. "
    echo "  svc_name: one or multiple services delimited by \",\"."
    echo "  action:  "
    echo "    set:   set environment setttings. "
    echo "    reset: will remove all development env settings. "
    echo "    check: display current environment settings. "
    echo "  svc_name: [$svc_list]. "
    echo "    -- use \"all\" to enable all services."
}

function __set_service {
    svc_name=$1
    profile_path=$2
    if [ -z $svc_name ]; then return; fi

    local paths=()
    local idx=0
    echo "" >> $profile_path
    echo "## -- service: $svc_name --- " >> $profile_path
    if [[ $svc_name == "airflow" ]] || [[ $svc_name == "all" ]]; then
        airflow_port_base=10000
        echo "export AIRFLOW_HOME=$config_home/airflow" >> $profile_path
        echo "export AIRFLOW_PORT_BASE=$airflow_port_base" >> $profile_path
        echo "export AIRFLOW_PORT_WEB=$(($airflow_port_base + 8080))" >> $profile_path
        echo "export AIRFLOW_PORT_LOG=$(($airflow_port_base + 8793))" >> $profile_path
        echo "export AIRFLOW_PORTS=\"8080,8793\"" >> $profile_path  # exposed ports
    fi

    # elasticsearch
    if [[ $svc_name == "elasticsearch" ]] || [[ $svc_name == "es" ]] || [[ $svc_name == "all" ]]; then
        elasticsearch_home="$service_home/elasticsearch-5.4.0"
        rm $elasticsearch_home/bin/*.bat > /dev/null 2>&1
        rm $elasticsearch_home/bin/*.cmd > /dev/null 2>&1

        echo "export ELASTICSEARCH_HOME=$elasticsearch_home" >> $profile_path
        echo "export ELASTICSEARCH_PORT_BASE=11000" >> $profile_path
        echo "export ELASTICSEARCH_PORTS=\"9200,9300\"" >> $profile_path
        paths[$idx]="$elasticsearch_home/bin" && idx=$((idx+1))
    fi

    # h2o
    if [[ $svc_name == "h2o" ]] || [[ $svc_name == "all" ]]; then
        h2o_home=$service_home/h2o-3.10.5.3
        echo "export H2O_HOME=$h2o_home" >> $profile_path
        echo "export H2O_PORT_BASE=12000" >> $profile_path
        echo "export H2O_PORTS=\"\"" >> $profile_path
        echo "alias h2o=\"java -jar \$H2O_HOME/h2o.jar\"" >> $profile_path
    fi

    # hadoop
    if [[ $svc_name == "hadoop" ]] || [[ $svc_name == "all" ]]; then
        hadoop_home=$service_home/hadoop-2.7.3
        chmod +x $hadoop_home/bin/*
        chmod +x $hadoop_home/sbin/*
        echo "export HADOOP_HOME=$hadoop_home" >> $profile_path
        echo "export HADOOP_PORT_BASE=12000" >> $profile_path
        echo "export HADOOP_PORTS=\"50070,50470,8020,9000,50075,50475,50010,50020,50090\"" >> $profile_path
        paths[$idx]="$hadoop_home/bin:$hadoop_home/sbin" && idx=$((idx+1))
    fi

    # kibana
    if [[ $svc_name == "kibana" ]] || [[ $svc_name == "elasticsearch" ]] || [[ $svc_name == "es" ]] || [[ $svc_name == "all" ]]; then
        kibana_home=$service_home/kibana-5.4.0-darwin-x86_64
        echo "export KIBANA_HOME=$kibana_home" >> $profile_path
        echo "export KIBANA_PORT_BASE=13000" >> $profile_path
        echo "export KIBANA_PORTS=\"5601\"" >> $profile_path
        paths[$idx]="$kibana_home/bin" && idx=$((idx+1))
    fi

    # mongo
    if [[ $svc_name == "mongo" ]] || [[ $svc_name == "all" ]]; then
        mongo_home=$service_home/mongodb-osx-x86_64-4.0.0
        chmod +x $mongo_home/bin/*
        echo "export MONGO_HOME=$mongo_home" >> $profile_path
        echo "export MONGO_PORTS=\"27017\"" >> $profile_path
        paths[$idx]="$mongo_home/bin" && idx=$((idx+1))
    fi

    # mysql
    if [[ $svc_name == "mysql" ]] || [[ $svc_name == "all" ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            mysql_home=/usr/local/opt/mysql@5.7
        else
            # mysql_home=$service_home/mysql-5.7.18-linux-glibc2.5-x86_64
            mysql_home=$service_home/mysql-8.0.13-linux-glibc2.12-x86_64
            chmod +x $mysql_home/bin/*
        fi
        echo "export MYSQL_HOME=$mysql_home" >> $profile_path
        echo "export MYSQL_PORT_BASE=14000" >> $profile_path
        echo "export MYSQL_PORTS=\"3306\"" >> $profile_path
        paths[$idx]="$mysql_home/bin" && idx=$((idx+1))
    fi

    # nifi
    if [[ $svc_name == "nifi" ]] || [[ $svc_name == "all" ]]; then
        nifi_home=$service_home/nifi-1.9.0
        chmod +x $nifi_home/bin/*
        nifi_port_base=15000
        echo "export NIFI_HOME=$nifi_home" >> $profile_path
        echo "export NIFI_PORT_BASE=$nifi_port_base" >> $profile_path
        echo "export NIFI_PORT_WEB_HTTP=$(($nifi_port_base + 8080))" >> $profile_path
        echo "export NIFI_PORT_WEB_HTTPS=$(($nifi_port_base + 443))" >> $profile_path
        echo "export NIFI_PORTS=\"443,8080\"" >> $profile_path

        if [ ! -e "$nifi_home/conf/nifi.properties.bak" ]; then
            source $profile_path
            mv "$nifi_home/conf/nifi.properties" "$nifi_home/conf/nifi.properties.bak"
            envsubst.sh $config_home/nifi/nifi.properties > "$nifi_home/conf/nifi.properties"
        fi
        paths[$idx]="$nifi_home/bin" && idx=$((idx+1))
    fi

    # postgres
    if [[ $svc_name == "postgres" ]] || [[ $svc_name == "all" ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            postgres_home="/Applications/Postgres.app/Contents/Versions/9.6"
        else
            postgres_home="/Applications/Postgres.app/Contents/Versions/9.6"
        fi
        echo "export POSTGRES_HOME=$postgres_home" >> $profile_path
        echo "export PGDATA=/host/data/postgres" >> $profile_path
        echo "export PG_PORTS=\"5432\"" >> $profile_path
        paths[$idx]="$postgres_home/bin" && idx=$((idx+1))
    fi

    # rabbit
    if [[ $svc_name == "rabbit" ]] || [[ $svc_name == "all" ]]; then
        rabbit_home=$service_home/rabbitmq_server-3.7.7
        echo "export RABBIT_HOME=$rabbit_home" >> $profile_path
        # echo "export RABBITMQ_NODE_PORT=\"5672\"" >> $profile_path
        # echo "export RABBITMQ_CONFIG_FILE=$config_home/rabbitmq.config" >> $profile_path
        paths[$idx]="$rabbit_home/bin:$rabbit_home/sbin" && idx=$((idx+1))
    fi

    # redis
    if [[ $svc_name == "redis" ]] || [[ $svc_name == "all" ]]; then
        redis_home=$service_home/redis
        #rm $redis_home/bin/* > /dev/null 2>&1
        if [[ $(uname) == "Darwin" ]]; then
            ln -s $redis_home/bin/mac/redis-server $redis_home/bin/redis-server > /dev/null 2>&1
            ln -s $redis_home/bin/mac/redis-cli $redis_home/bin/redis-cli > /dev/null 2>&1
        else
            ln -s $redis_home/bin/linux/redis-server $redis_home/bin/redis-server > /dev/null 2>&1
            ln -s $redis_home/bin/linux/redis-cli $redis_home/bin/redis-cli > /dev/null 2>&1
        fi
        echo "export REDIS_HOME=$redis_home" >> $profile_path
        echo "export REDIS_PORTS=\"6379\"" >> $profile_path
        paths[$idx]="$redis_home/bin" && idx=$((idx+1))
    fi

    for key in "${!paths[@]}"; do
        echo "export PATH=\$PATH:${paths[$key]}" >> $profile_path
    done
}

function main() {
    __parse_arguments

    local action=${args[0]}
    local profile_path=$default_profile_path
    if [[ $args_count -eq 3 ]]; then profile_path=${args[2]}; fi
    if [[ $action == "reset" ]]; then
        echo "#!/usr/bin/env bash" > $profile_path
        return
    elif [[ $action == "check" ]]; then
        cat $profile_path
        return
    fi

    local targets=${args[1]}
    IFS=',' read -a target_array <<< "${targets}"; IFS=$default_ifs
    for tgt in "${target_array[@]}"; do
        __set_service $tgt $profile_path
    done
}

main
