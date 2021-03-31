### js env
alias js_chrome="if [ ! -d node_modules ]; then ln -s $HOME/workspace/js_env/puppeteer/node_modules node_modules; fi"
alias js_gcp="if [ ! -d node_modules ]; then ln -s $HOME/workspace/js_env/gcp/node_modules node_modules; fi"
alias js_env="pushd . && cd $HOME/workspace/js_env"
