### misc
alias ansid="ansible-vault decrypt --vault-password-file=$HOME/.keys/$GCP_PROJECT --output ./decrypted.out"
alias locateup="sudo /usr/libexec/locate.updatedb &"

function killx() {
    local process=$1

    pids=($(ps -ef | grep ${process} | grep -v "grep" | awk '{print $2}'))
    if [ ${#pids[@]} -gt 0 ]; then
        cmd="kill -9 ${pids[@]}"
        echo ${cmd} && ${cmd}
    else
        echo ${process} not found.
    fi
}
