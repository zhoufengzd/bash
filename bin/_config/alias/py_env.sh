## python environment quick access

function pyenv() {
    py_env_home="$HOME/workspace/bin/svc/bin/venv/py_env"

    venv_name=$1
    if [ -e ${py_env_home}/${venv_name}/bin/activate ]; then
        source ${py_env_home}/${venv_name}/bin/activate
    elif [[ $venv_name == "." ]]; then
        export PYTHONPATH=$(pwd):$PYTHONPATH
        echo PYTHONPATH=$PYTHONPATH
    else
        echo "python venv at \$HOME/workspace/env/py_env:"
        echo "-------------------------------------------"
        echo "$(cd ${py_env_home} && ls -d */ | grep -v _requirements)"
    fi
}

alias venv="if [ -e ./venv/bin/activate ]; then source ./venv/bin/activate; else python3 -m venv venv && source ./venv/bin/activate; fi"
alias pipup="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install --upgrade && pip install pipdeptree > /dev/null"
alias pipoff="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip uninstall -y"
alias pip3off="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 uninstall -y"
