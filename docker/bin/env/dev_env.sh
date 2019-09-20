#!/usr/bin/env bash
## build dev profile
source $BASH_UTIL_LIB/params.sh

default_profile_path="$HOME/.env/dev_env"
env_home="/host/bin/env"
evn_list="chrome|gcp|gradle|go|glide|java|maven"

function __help {
    script_name=$(basename "$0")
    echo "Usage: $script_name <action> <env_name|all|reset> [profile_path]. "
    echo "  -- Update development profile. \"profile_path\" default to $default_profile_path if not set. "
    echo "  action:  "
    echo "    set:   set environment setttings. "
    echo "    reset: will remove all development env settings. "
    echo "    check: display current environment settings. "
    echo "  env_name: [$evn_list]. use all to set all the environment. "
}

function main() {
    __parse_arguments
    local action=${args[0]}
    local env_name=${args[1]}
    local profile_path=$default_profile_path
    if [[ $args_count -eq 3 ]]; then
        profile_path=${args[2]}
    fi

    if [[ $action == "reset" ]]; then
        echo "#!/usr/bin/env bash" > $profile_path
        return
    elif [[ $action == "check" ]]; then
        cat $profile_path
        return
    fi

    local paths=()
    local idx=0
    echo "" >> $profile_path
    if [[ $env_name == "chrome" ]] || [[ $env_name == "all" ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            google_chrome_home="/Applications/Google\\ Chrome\\ Canary.app/Contents/MacOS"
            echo "export GOOGLE_CHROME_HOME=$google_chrome_home" >> $profile_path
            echo "alias chrome=\"$google_chrome_home/\Google\ Chrome\ Canary --headless --disable-gpu\""  >> $profile_path
        fi
        #paths[$idx]="$google_sdk_home/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "gcp" ]] || [[ $env_name == "all" ]]; then
        google_sdk_home="$env_home/google-cloud-sdk"
        echo "export GOOGLE_SDK_HOME=$google_sdk_home" >> $profile_path
        paths[$idx]="\$GOOGLE_SDK_HOME/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "gradle" ]] || [[ $env_name == "all" ]]; then
        gradle_home="$env_home/gradle-5.4.1"
        echo "export GRADLE_HOME=$gradle_home" >> $profile_path
        paths[$idx]="\$GRADLE_HOME/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "go" ]] || [[ $env_name == "all" ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            go_root="$env_home/go1.12.6.darwin-amd64"
            echo "export GOPATH=\$HOME/workspace/go_env" >> $profile_path
        else
            go_root="$env_home/go1.8.3.linux-amd64"
        fi

        echo "export GOROOT=$go_root" >> $profile_path
        paths[$idx]="\$GOROOT/bin" && idx=$((idx+1))
        paths[$idx]="\$GOPATH/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "glide" ]] || [[ $env_name == "all" ]]; then
        if [[ $(uname) == "Darwin" ]]; then
            glide_home="$env_home/glide-v0.13.1-darwin"
        else
            glide_home="$env_home/glide-v0.13.1-linux-amd64"
        fi

        echo "export GLIDE_HOME=$glide_home" >> $profile_path
        paths[$idx]="\$GLIDE_HOME" && idx=$((idx+1))
    fi

    if [[ $env_name == "java"* ]] || [[ $env_name == "all" ]]; then
        jdk_version="jdk-11.0.2"
        if [[ $env_name == "java9" ]]; then
            jdk_version="jdk-9.0.4";
        elif [[ $env_name == "java8" ]]; then
            jdk_version="jdk1.8.0_202"
        fi
        if [[ $(uname) == "Darwin" ]]; then
            java_home="/Library/Java/JavaVirtualMachines/$jdk_version.jdk/Contents/Home"
        else
            java_home="$env_home/$jdk_version"
        fi

        echo "export JAVA_HOME=$java_home" >> $profile_path
        paths[$idx]="\$JAVA_HOME/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "maven" ]] || [[ $env_name == "all" ]]; then
        m2_home="$env_home/apache-maven-3.6.1"
        echo "export M2_HOME=$m2_home" >> $profile_path
        paths[$idx]="\$M2_HOME/bin" && idx=$((idx+1))
    fi

    if [[ $env_name == "all" ]]; then echo "" >> $profile_path; fi
    for key in "${!paths[@]}"; do
        echo "export PATH=\$PATH:${paths[$key]}" >> $profile_path
    done
}

main
