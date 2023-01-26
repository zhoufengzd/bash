## python environment quick access

function pyenv() {
    py_env_home="$HOME/workspace/bin/svc/bin/venv/py_env"

    args=$1
    venv_name=$1
    if [[ $args == "-m" ]]; then
        venv_name=$2
        cmd="python3 -m venv ${py_env_home}/${venv_name}"
        echo $cmd && $cmd && echo "..."
        source ${py_env_home}/${venv_name}/bin/activate
        pip install --upgrade pip > /dev/null 2>&1
        touch ${py_env_home}/_requirements/${venv_name}.txt
    elif [ -e ${py_env_home}/${venv_name}/bin/activate ]; then
        source ${py_env_home}/${venv_name}/bin/activate
    else
        echo "python venv at \$HOME/workspace/env/py_env:"
        echo "-------------------------------------------"
        # echo "$(cd ${py_env_home} && ls -d */ | grep -v _requirements)"
        cd ${py_env_home} && ls -d */ | grep -v _requirements
    fi
}

function pypath() {
    py_dir=$1
    if [[ $venv_name == "." ]]; then
        export PYTHONPATH=$(pwd):$PYTHONPATH
    elif [ -d ${py_dir} ]; then
        export PYTHONPATH=$(pwd):$PYTHONPATH
    fi
    echo PYTHONPATH=$PYTHONPATH
}

function pjson() {
    json_file=$1
    cat $json_file | python -m json.tool > tmp.json
    cat tmp.json
    echo -e "\nreplace $json_file? [Y|N]:"
    read reply
    if [[ $reply == "Y"* ]] | [[ $reply == "y"* ]]; then
        mv tmp.json $json_file
    else
        rm tmp.json
    fi
}

alias venv="if [ -e ./venv/bin/activate ]; then source ./venv/bin/activate; else python3 -m venv venv && source ./venv/bin/activate; fi"
alias pipup="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install --upgrade && pip install pipdeptree > /dev/null"
alias pipoff="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip uninstall -y"

alias condaenv="source /usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh"

# charm: opens up pycharm
