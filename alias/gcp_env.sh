### gcp
function gcp() {
    gcp.sh $1 $2 && source $HOME/.env/gcp_env
}

function gup() {
    gcloud components update --quiet
}

function gsql_ssh() {
    local db_host=$1
    cmd="cloud_sql_proxy -instances=${GCP_PROJECT}:us-east4:${db_host}=tcp:5432"
    echo $cmd ## && $cmd
}
