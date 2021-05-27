#!/usr/bin/env bash
source $BASH_UTIL_LIB/argparse.sh
source $HOME/.env/gcp_env

## environment:
default_ifs="$IFS"
wk_dir=$(pwd)
script_dir="$(cd "$(dirname "$(readlink ${BASH_SOURCE[0]})")" && pwd)"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <target> [optional flags]"
    echo "  action: support [r|run_sql] | [i|import] | [e|export] | [p|preview] | [s|schema] | [rm|remove] | [c|create]"
    echo "  target: action targets. Sql, sql file, or table. Multiple targets could be delimited by semicolon. "
    echo "    to import and export, set target as: <target_table*>=<data_file>. "
    echo "      -- use \"*\" to export to multiple files, for example, \"table_xxx=data_*.csv\" "
    echo "    to create table, set target as: <target_table>=<schema_file>. "
    echo "  optional flags: any other optional flags supported by bq. "
    echo "      -- run \"bq help\" or \"bq help <command>\" for other options."
    echo "      -- like \"--replace\", \"--format=prettyjson\". "
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
dataset_name=""
table_name=""
target_opt=""

function _parse_table_identifier {
    local tgt=$1
    ifs_current=$IFS; IFS='.' read -a target_parts <<< "${tgt}"; IFS=$ifs_current
    if [[ ${#target_parts[@]} -eq 3 ]]; then
        proj_id=${target_parts[0]}
        dataset_name=${target_parts[1]}
        table_name=${target_parts[2]}
    elif [[ ${#target_parts[@]} -eq 2 ]]; then
        proj_id=""
        dataset_name=${target_parts[0]}
        table_name=${target_parts[1]}
    else
        proj_id=""
        dataset_name=${target_parts[0]}
        table_name=""
    fi
    # echo tgt=$tgt proj_id=$proj_id  dataset_name=$dataset_name table_name=$table_name
}

function _format_target_opt {
    local tgt=$1
    _parse_table_identifier "$tgt"

    target_opt=""
    if [ ! -z $proj_id ]; then
        target_opt="--project_id $proj_id "
    fi
    if [ ! -z $dataset_name ]; then
        target_opt+="$dataset_name"
    fi
    if [ ! -z $table_name ]; then
        target_opt+=".$table_name"
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
        if [[ $action == "run_sql" ]]; then
            old_ifs=$IFS; IFS='=' read -a target_pair <<< "${tgt}"; IFS=$old_ifs
            sql=${target_pair[0]}

            ## destination table?
            dest_tbl_opt=""
            if [ ${#target_pair[@]} -eq 2 ]; then
                dest_tbl_opt="--max_rows=0 --allow_large_results --destination_table=${target_pair[1]}"
            fi

            if [ -e "$sql" ]; then
                commands[$idx]="cat $sql | grep -v -e \"^\s*--\" -e \"^\s*#\" -e \"^\s*$\" | bq query --nouse_legacy_sql $optional_flags $dest_tbl_opt" && idx=$((idx+1))
            else
                commands[$idx]="bq query --nouse_legacy_sql $optional_flags $dest_tbl_opt \"$sql\"" && idx=$((idx+1))
            fi
        elif [[ $action == "preview" ]]; then
            tbl=$tgt
            _format_target_opt "$tbl"
            commands[$idx]="bq head -n 10 $optional_flags $target_opt " && idx=$((idx+1))
        elif [[ $action == "schema" ]]; then
            tbl=$tgt
            _format_target_opt "$tbl"
            if [[ "$optional_flags" != "--format"* ]]; then grep_pattern="| tail -n +3 | cut -b 20-"; fi
            commands[$idx]="bq show $optional_flags $target_opt $grep_pattern" && idx=$((idx+1))
        elif [[ $action == "import" ]]; then
            old_ifs=$IFS; IFS='=' read -a target_pair <<< "${tgt}"; IFS=$old_ifs
            if [ ${#target_pair[@]} -ne 2 ]; then
                echo "Error! expects <target_table>=<data_file> pair!"
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
            commands[$idx]="bq load $data_fmt_opt $optional_flags $target_opt $data_file" && idx=$((idx+1))
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
                commands[$idx]="bq extract $fmt_opt $optional_flags $target_opt $data_file" && idx=$((idx+1))
            else    ## local file. copy to gcs first then to local
                if [ -z ${args["compression"]} ]; then
                    optional_flags+=" --compression=GZIP"
                fi
                gcs_data_file=$GCP_BQ_BUCKET/extracted/$table_name/"dt_*."$data_file_fmt".gz"
                commands[$idx]="bq extract $fmt_opt $optional_flags $target_opt $gcs_data_file > /dev/null 2>&1" && idx=$((idx+1))
                commands[$idx]="mkdir -p $table_name && gsutil cp $gcs_data_file $table_name/ > /dev/null 2>&1 && gunzip $table_name/*.gz" && idx=$((idx+1))
                commands[$idx]="gsutil rm $gcs_data_file > /dev/null 2>&1" && idx=$((idx+1))
                if [[ $multi_files != "true" ]]; then
                    commands[$idx]="cat $table_name/* > $data_file && rm -rf $table_name/" && idx=$((idx+1))
                fi
            fi
        elif [[ $action == "remove" ]]; then
            _parse_table_identifier "$tgt"
            table_name=${table_name/\*/}
            if [ ! -z $table_name ]; then
                tbl_list=($(bq ls $dataset_name | grep $table_name | grep -v ".tableId" | grep -v ".------" | awk '{print $1}'))
            else
                tbl_list=($(bq ls $dataset_name | grep -v ".tableId" | grep -v ".------" | awk '{print $1}'))
            fi

            for tbl in "${tbl_list[@]}"; do
                commands[$idx]="bq rm -ft $dataset_name.$tbl" && idx=$((idx+1))
            done
        elif [[ $action == "create" ]]; then
            old_ifs=$IFS; IFS='=' read -a target_pair <<< "${tgt}"; IFS=$old_ifs
            tgt=${target_pair[0]}
            _parse_table_identifier "$tgt"

            target_opt=""
            if [ ! -z $proj_id ]; then
                target_opt="--project_id $proj_id "
            fi
            if [ ! -z $table_name ]; then
                target_opt+="-t $dataset_name.$table_name"
            else
                target_opt+="$dataset_name"
            fi

            # check if "--schema <schema_file>" options are provided
            local schema_opt=""
            if [ ! -z $table_name ]; then
                schema_file=${args["schema"]}
                if [ -z $schema_file ] || [[ $schema_file == $VALUE_DUMMY ]]; then
                    if [ ${#target_pair[@]} -ne 2 ]; then
                       echo "Error! expecting a schema file! Please use <target_table>=<schema_file>"
                        __help; exit
                    fi
                    schema_file=${target_pair[1]}
                    schema_opt="--schema $schema_file"
                fi
            fi
            commands[$idx]="bq mk $optional_flags $schema_opt $target_opt" && idx=$((idx+1))
        fi
    done

    for cmd in "${commands[@]}"; do
        echo -e "$cmd" && sh -c "$cmd"
    done
}

main
