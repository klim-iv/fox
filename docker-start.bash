#!/bin/bash

docker_image="fox"
name="fox-working-docker"
memory="5G"
port=4567
nginx_port=18082
work_dir="$HOME/Downloads:/Downloads"

tmp_dir="/tmp/fox-stuff"
mkdir -p ${tmp_dir}

for i in 1 2 3; do

    echo "Started:"
    date
    echo ">> try: ${i}"

    docker run \
        --rm \
        --name=${name} \
        --memory=${memory} \
        -p ${port}:${port} \
        -p ${nginx_port}:${nginx_port} \
        -v ${work_dir} \
        -v ${tmp_dir}:/res \
        -v $(pwd)/web:/fox \
        -it ${docker_image}

    echo "Finished:"
    date

done
