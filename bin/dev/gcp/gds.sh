#!/usr/bin/env bash
source $BASH_LIB/argparse.sh
source $HOME/.env/gcp_env

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

# gcloud datastore export
# gcloud datastore import
# gcloud datastore indexes cleanup
# gcloud datastore indexes create
# gcloud datastore indexes describe
# gcloud datastore indexes list
# gcloud datastore operations cancel
# gcloud datastore operations delete
# gcloud datastore operations describe
# gcloud datastore operations list

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <target> [optional flags]"
    echo "  action: support [i|import] | [e|export] | [rm|remove]"
    echo "  target: action targets. Multiple targets could be delimited by semicolon. "
    echo "    to import and export, set target as: <target_entity*>=<data_file>. "
    echo "      -- use \"*\" to export to multiple files, for example, \"entity_xxx=data_*.csv\" "
    echo "    to create entity, set target as: <target_entity>=<schema_file>. "
    echo "  optional flags: any other optional flags supported by bq. "
    echo "      -- run \"gcloud datastore --help\" for other options."
}
key_map["r"]="run_sql"
key_map["i"]="import"
key_map["e"]="export"
key_map["p"]="preview"
key_map["s"]="schema"
key_map["rm"]="remove"
key_map["c"]="create"
key_map["cp"]="copy"

# global temp variables
proj_id=""
entity_name=""
target_opt=""

function _parse_entity_identifier {
    local tgt=$1
    ifs_current=$IFS; IFS='.' read -a target_parts <<< "${tgt}"; IFS=$ifs_current
    if [[ ${#target_parts[@]} -eq 2 ]]; then
        proj_id=${target_parts[0]}
        entity_name=${target_parts[1]}
    elif [[ ${#target_parts[@]} -eq 1 ]]; then
        proj_id=""
        entity_name=${target_parts[0]}
    else
        proj_id=""
        entity_name=""
    fi
    # echo tgt=$tgt proj_id=$proj_id entity_name=$entity_name
}

function _format_target_opt {
    local tgt=$1
    _parse_entity_identifier "$tgt"

    target_opt=""
    if [ ! -z $proj_id ]; then
        target_opt="--project_id $proj_id "
    fi
    if [ ! -z $entity_name ]; then
        target_opt+="--kinds=$entity_name"
    fi
}

function main {
    __parse_arguments

    local action=${args[0]}
    local targets=${args[1]}
    if [[ -z $action ]] || [[ -z "$targets" ]]; then
        __help; exit
    fi
    # echo "action=$action targets=\"$targets\""

    local optional_flags=""
    local idx=2  # skip action and taget
    while [ $idx -lt $args_count ]; do
        optional_flags+=${args[$idx]}" "
        idx=$((idx+1))
    done

    local commands=()
    idx=0
    IFS=';' read -a target_array <<< "${targets}"; IFS=$default_ifs
    for tgt in "${target_array[@]}"; do
        target_opt=""
        if [[ $action == "import" ]]; then
            old_ifs=$IFS; IFS='=' read -a target_pair <<< "${tgt}"; IFS=$old_ifs
            if [ ${#target_pair[@]} -ne 2 ]; then
                echo "Error! expects <target_entity>=<data_file> pair!"
                __help; exit
            fi
            tbl=${target_pair[0]}
            _format_target_opt "$tbl"

            # try decides data format
            # --source_format: <CSV|NEWLINE_DELIMITED_JSON|DATASTORE_BACKUP|AVRO|PARQUET
            data_file=${target_pair[1]}
            if [[ $data_file == *.json ]]; then
                data_file_fmt="NEWLINE_DELIMITED_JSON"
            elif [[ $data_file == *.avro ]]; then
                data_file_fmt="AVRO"
            elif [[ $data_file == *.csv ]]; then
                data_file_fmt="CSV"
            fi
            data_fmt_opt="--autodetect"
            if [ ! -z $data_file_fmt ]; then
                data_fmt_opt="--source_format=$data_file_fmt"
            fi
            commands[$idx]="gcloud datastore import $data_fmt_opt $optional_flags $target_opt $data_file" && idx=$((idx+1))
        elif [[ $action == "export" ]]; then
            old_ifs=$IFS; IFS='=' read -a target_pair <<< "${tgt}"; IFS=$old_ifs
            tbl=${target_pair[0]}
            _format_target_opt "$tbl"

            ## output file and format
            multi_files="false"
            raw_data_file=${target_pair[1]}
            data_file=${raw_data_file//"*"/}
            if [[ $raw_data_file != $data_file ]]; then
                multi_files="true"
            fi
            if [ -z $data_file ]; then
                data_file=$tbl".csv"
            fi

            ### either by file extension, or default to csv.
            if [[ $data_file == *.json ]]; then
                data_file_fmt="json"
                fmt_opt="--destination_format=NEWLINE_DELIMITED_JSON"
            elif [[ $data_file == *.avro ]]; then
                data_file_fmt="avro"
                fmt_opt="--destination_format=AVRO"
            else
                data_file_fmt="csv"
                fmt_opt="--destination_format=CSV"
            fi

            if [[ ${data_file:0:5} == "gs://" ]]; then
                commands[$idx]="gcloud datastore export $fmt_opt $optional_flags $target_opt $data_file" && idx=$((idx+1))
            else    ## local file. copy to gcs first then to local
                if [ -z ${args["compression"]} ]; then
                    optional_flags+=" --compression=GZIP"
                fi
                gcs_data_file=$GCP_DS_BUCKET/extracted/$entity_name/"dt_*."$data_file_fmt".gz"
                commands[$idx]="bq extract $fmt_opt $optional_flags $target_opt $gcs_data_file > /dev/null 2>&1" && idx=$((idx+1))
                commands[$idx]="mkdir -p $entity_name && gsutil cp $gcs_data_file $entity_name/ > /dev/null 2>&1 && gunzip $entity_name/*.gz" && idx=$((idx+1))
                commands[$idx]="gsutil rm $gcs_data_file > /dev/null 2>&1" && idx=$((idx+1))
                if [[ $multi_files != "true" ]]; then
                    commands[$idx]="cat $entity_name/* > $data_file && rm -rf $entity_name/" && idx=$((idx+1))
                fi
            fi
        fi
    done

    for cmd in "${commands[@]}"; do
        echo -e "$cmd" && sh -c "$cmd"
    done
}

main
