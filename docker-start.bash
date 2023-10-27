#!/bin/bash

docker_image="fox"
name="fox-working-docker"
memory="5G"
port=4567
work_dir="$HOME/Downloads:/root/Downloads"

tmp_dir="/tmp/fox-stuff"
mkdir -p ${tmp_dir}


for i in 1 2 3 4 5 6 7 8; do

echo "Started:"
date
echo ">> try: ${i}"

docker run \
    --rm \
    --name=${name} \
    --memory=${memory} \
    -p ${port}:${port} \
    -v ${work_dir} \
    -v ${tmp_dir}:/res \
    -it ${docker_image}

echo "Finished:"
date

done
