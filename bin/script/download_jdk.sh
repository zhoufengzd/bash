#!/usr/bin/env bash

tar_package="tar.gz"
rmp_package="rpm"

ext=$1
jdk_version=8

if [ -n $ext ]; then
    ext=$tar_package
fi

if [ $ext == "tar" ]; then
    ext=$tar_package
fi

readonly base_url="http://www.oracle.com"
readonly index_page="$base_url/technetwork/java/javase/downloads/index.html"
readonly jdk_version_url=$(curl -s $index_page | egrep -o "\/technetwork\/java/\javase\/downloads\/jdk${jdk_version}-downloads-.+?\.html" | head -1 | cut -d '"' -f 1)
if [[ -z "$jdk_version_url" ]]; then
    echo "Error! Failed to find jdk download url from \"$index_page\""
    exit
fi

readonly jdk_download_url=($(curl -s ${base_url}${jdk_version_url} | egrep -o "http\:\/\/download.oracle\.com\/otn-pub\/java\/jdk\/[7-8]u[0-9]+\-(.*)+\/jdk-[7-8]u[0-9]+(.*)linux-x64.$ext"))
dl_url=${jdk_download_url[0]}
echo wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" -N $dl_url
echo "..."
wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" -N $dl_url

## extract and update java home
downloaded=($(ls j*.$ext))
tar -xzf ${downloaded[0]}
rm ${downloaded[*]}
