# bash profile for interactive shell
#   -- linked as $HOME/.bash_profile

## env: bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

# shell prompt & color
if [ "$USER" = root ]; then
    PS1="root@...\W# "
else
    PS1="...\W$ "
fi

## env:
sys_path="/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
local_bin="$HOME/workspace/bin"
export PATH=$local_bin:$sys_path
export BASH_UTIL_LIB="$local_bin/util"

envs=$(ls $HOME/.env/* 2>/dev/null)
for env in ${envs[@]}; do source $env; done

## aliases
aliases=$(ls $HOME/.alias/* 2>/dev/null)
for alias in ${aliases[@]}; do source $alias; done
