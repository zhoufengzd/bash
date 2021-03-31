# cat file and replace with env variables

function env_cat() {
    local in_file=$1
    if [ ! -e $in_file ]; then return; fi

    default_ifs="$IFS"
    local line=""
    while IFS= read -r line; do
        sh -c "echo \"$line\""
    done < "$in_file"
    IFS=$default_ifs
}
