# dev working environment
* on linux, host and docker container share the same layout.
    * /host/bin/[env|svc|shell]/...
    * env: dev sdk installations, like java, go, etc
    * svc: service installations, like mysql, airflow, nifi, etc.
    * shell: handy shell script utilities
* tracking changes in git
    * scripts are under env repo
    * add a deploy.sh to drop these scripts into target folder.
