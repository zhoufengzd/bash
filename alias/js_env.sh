### js env
js_env_home=$HOME/workspace/bin/svc/bin/venv/js_env

alias js_chrome="if [ ! -d node_modules ]; then ln -s $js_env_home/puppeteer/node_modules node_modules; fi"
alias js_gcp="if [ ! -d node_modules ]; then ln -s $js_env_home/gcp/node_modules node_modules; fi"
alias js_env="pushd . && cd $js_env_home"
