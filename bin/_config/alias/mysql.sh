# mysql shortcut

mysql_env="$HOME/.env/mysql_env"
container_name="mysql"
mysql_home="$HOME/workspace/bin/svc/data/mysql"

function mysqlm() {
    echo "mysql shortcut"
    echo "--------------------"
    echo "  init_mysql, start_mysql, stop_mysql"
}

function init_mysql() {
    server_port=${1:-13306}
    server_dir=${mysql_home}/${server_port}
    mkdir -p ${server_dir}/config && mkdir -p ${server_dir}/data

    random_str=$(date +%s | sha256sum | base64 | head -c 16)
    mysql_root="MYSQL_PWD=${random_str} mysql -h 127.0.0.1 --port ${server_port} -u root"

    echo "export MYSQL_ROOT_PASSWORD=${random_str}" > ${mysql_env}
    echo "alias mysqlr=\"${mysql_root}\"" >> ${mysql_env}

    echo "docker run -p ${server_port}:3306 -e MYSQL_ROOT_PASSWORD=${random_str} mysql:latest"
    docker run --detach \
        --name ${container_name} \
        -p ${server_port}:3306 \
        -v ${server_dir}/config:/etc/mysql/conf.d \
        -v ${server_dir}/data:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=${random_str} \
        mysql:latest
}

function start_mysql() {
    docker start ${container_name}
}

function stop_mysql() {
    docker stop ${container_name}
}
