#!/bin/bash

tmp=$(which gem)

if [ -z "${tmp}" ]; then
    echo "need to install ruby's gem tool"
else
    tmp=$(gem list --local | grep bundler)
    if [ -z "${tmp}" ]; then
        echo "try to install gem : bundler"
        gem install bundler
    fi

    bundle install --path `pwd`
    ruby ./www.rb
fi