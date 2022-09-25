### misc
alias ansid="ansible-vault decrypt --vault-password-file=$HOME/.keys/$GCP_PROJECT --output ./decrypted.out"
alias locateup="sudo /usr/libexec/locate.updatedb &"

function killx {
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
        cmd="kill -9 $pid_list"
        echo $cmd && $cmd
    fi
}

lines=()
function __load_file() {
    local in_file=$1
    local idx=0

    lines=()
    default_ifs="$IFS"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ -z $line ] || [[ $line == "#"* ]] || [[ $line == "--"* ]]; then continue; fi
        lines[$idx]="$line" && idx=$((idx+1))
    done < "$in_file"
    IFS=$default_ifs
}