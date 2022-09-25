### js env
js_env_home=$HOME/workspace/bin/svc/bin/venv/js_env

function nvmpath {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                    # loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # loads nvm bash_completion
}

function jsenv() {
    args=$1
    venv_name=$2
    if [ -z $args ]; then
        echo "js environment located at \$HOME/workspace/env/js_env:"
        echo "------------------------------------------------------"
        cd ${js_env_home} && ls -d */ | grep -v _requirements
    elif [[ $args == "-m" ]]; then
        mkdir -p ${js_env_home}/${venv_name}/node_modules
        touch ${js_env_home}/_requirements/${venv_name}.txt
    elif [[ $args == "-i" ]]; then
        requirements="${js_env_home}/_requirements/${venv_name}.txt"
        if [ -f ${requirements} ]; then
            __load_file "${requirements}"
            cd ${js_env_home}/${venv_name}
            for pkg in "${lines[@]}"; do
                cmd="npm install --save $pkg"
                echo $cmd && $cmd
            done
            cd -
        fi
    elif [[ $args == "-a" ]]; then
        if [ ! -d node_modules ] && [ -e ${js_env_home}/${venv_name}/node_modules ]; then
            cmd="ln -s ${js_env_home}/${venv_name}/node_modules node_modules"
            echo $cmd && $cmd
            echo "... ${venv_name} activated ..."
        fi
    fi
}


# alias js_chrome="if [ ! -d node_modules ]; then ln -s $js_env_home/puppeteer/node_modules node_modules; fi"
# alias js_gcp="if [ ! -d node_modules ]; then ln -s $js_env_home/gcp/node_modules node_modules; fi"
# alias js_env="pushd . && cd $js_env_home"

alias ndoff='npm ls --depth=0 | grep "├──" | cut -d "@" -f 2,3'
