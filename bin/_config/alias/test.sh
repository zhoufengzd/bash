# nosetests
function test_sh() {
    export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.../_keys/test/air_svc_key.json
    export PROJECT=test
    if [ ! -d venv ] || [ ! -d test ]; then
        echo GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS
        echo PROJECT=$PROJECT
    else
        source venv/bin/activate

        nosetests -v
        unset GOOGLE_APPLICATION_CREDENTIALS
        unset PROJECT

        if [ -e venv/bin/deactivate ]; then
            source venv/bin/deactivate
        else
            deactivate > /dev/null 2>&1
        fi
    fi
}
