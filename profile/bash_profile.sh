# bash profile for interactive shell
#   -- linked as $HOME/.bash_profile

## env: bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

## env:
sys_path="/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
local_bin="$HOME/workspace/bin"
app_path="/usr/local/MacGPG2/bin:/Applications/Wireshark.app/Contents/MacOS"
export PATH=$local_bin:$sys_path
export BASH_UTIL_LIB="$local_bin/util"

envs=$(ls $HOME/.env/* 2>/dev/null)
for env in ${envs[@]}; do source $env; done

# shell prompt & color
if [ "$USER" = root ]; then
    PS1="root@...\W# "
else
    PS1="...\W$ "
fi

### git env
export GIT_ROOT="$HOME/workspace/git"
export GIT_ROOT_DATA="$GIT_ROOT/Data"

## aliases

### functions
aliases=$(ls $HOME/.alias/* 2>/dev/null)
for alias in ${aliases[@]}; do source $alias; done

### general
function psx() {
    if [ ! -z $1 ]; then ps -ef | grep -v "grep " | grep $1; fi
}

### gcp
function gcp() {
    gcp.sh $1 $2 && source $HOME/.env/gcp_env
}

### misc
alias ansid="ansible-vault decrypt --vault-password-file=$HOME/.zd-infra-keys/url-coverage-$GCP_PROJECT --output ./decrypted.out"
alias locateup="sudo /usr/libexec/locate.updatedb &"

### python env
export PYTHON_ENV_HOME="$HOME/workspace/python_env"
# alias python=python3
alias venv="if [ -e ./venv/bin/activate ]; then source ./venv/bin/activate; else python3 -m venv venv && source ./venv/bin/activate; fi"
alias pipup="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install --upgrade && pip install pipdeptree > /dev/null"
alias pipoff="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip uninstall -y"
alias pip3off="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 uninstall -y"

alias air="source $PYTHON_ENV_HOME/airflow/bin/activate"
alias urlapi="source $PYTHON_ENV_HOME/urlapi/bin/activate"
alias kaggle="source $PYTHON_ENV_HOME/kaggle/bin/activate"
alias scikit="source $PYTHON_ENV_HOME/scikit/bin/activate && export SCIKIT_LEARN_DATA=/Users/fzhou/workspace/test/_downloaded/scikit/tutorial/_data"
alias quant="source $PYTHON_ENV_HOME/quant/bin/activate"

#### python dev env
alias devrest="source $PYTHON_ENV_HOME/rest/bin/activate"
alias rabbit="source $PYTHON_ENV_HOME/rabbit/bin/activate"
alias random="source $PYTHON_ENV_HOME/random/bin/activate"
alias glab="source $PYTHON_ENV_HOME/glab/bin/activate"

### js env
alias js_chrome="if [ ! -d node_modules ]; then ln -s $HOME/workspace/js_env/puppeteer/node_modules node_modules; fi"
alias js_gcp="if [ ! -d node_modules ]; then ln -s $HOME/workspace/js_env/gcp/node_modules node_modules; fi"
alias js_env="pushd . && cd $HOME/workspace/js_env"

### go env

### -- allow export env variables (x=v) without "export x=v"
# set -a
