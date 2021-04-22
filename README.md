# dev working environment
* git: source controlled stuff
    * may add deploy.sh for easy usage
* local: local files / data, not intended to keep them in git. Not for execution.
    * test: test files / link to downloads as needed
    * tmp: temporary stuff
    * downloads: git repo downloads
* bin: executable binaries, could be in docker as well
    * script: to make life easier. source controlled in git
        * add script path to $PATH
    * dev: dev tools, dev sdk and tools, like java / maven, go / glide
    * svc: packages for specific services, like postgresql, airflow, superset, etc
        * data: config / data / log
        * bin: executable packages
            * venv: virtual environment
                * py_env
                * js_env
    * docker: docker images to serve dev environment or services
        * When should we not use docker?
            * already in virtual environment, like py_env
            * debugging purpose
        * When to use docker:
            * separation from host deployment, like mac update, unsupported ssl libraries, etc
            * deployed service could stay with older versions.
        * volumn:
            * required: mount svc bin/svc/data directory to allow shared data content
            * optional: mount workspace / downloads
