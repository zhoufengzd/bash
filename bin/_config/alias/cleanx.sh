## code cleaner

function cleanx() {
    local targets=("upload_for_composer" "*.egg-info" "build" "_generated" "*.pyc" "__pycache__" ".idea")

    local flist=($(ls -l | awk '{print $9}'))
    for f in ${flist[@]}; do
        for t in ${targets[@]}; do
            if [[ $f == $t ]]; then
                if [ -d $f ]; then
                    echo "-- rm -rf $f";
                    if [[ $preview != "-p" ]]; then
                        rm -rf $f
                    fi
                else
                    echo "-- rm $f";
                    if [[ $preview != "-p" ]]; then
                        rm $f
                    fi
                fi
            fi
        done
    done
}
