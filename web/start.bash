#!/bin/bash

tmp=$(which gem)

if [ -z "${tmp}" ]; then
    echo "need to install ruby's gem tool"
else
    tmp=$(gem list --local | grep bundler)
    if [ -z "${tmp}" ]; then
        echo "try to install gem : bundler"
        sudo gem install bundler
    fi

    tmp=$(which bundle)
    if [ -z "${tmp}" ]; then
        echo "*** Need to install bundler ***"
        echo "execute : sudo gem install bundler"
        exit 1
    fi

    bundle install
    ruby ./www.rb -r '/res/' $@
fi
