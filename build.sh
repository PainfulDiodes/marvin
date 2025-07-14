#!/usr/bin/env bash
echo "./build-z88dk.sh beanboard" $@
./build-z88dk.sh beanboard $@
echo "./build-z88dk.sh beanzee" $@
./build-z88dk.sh beanzee $@
echo "./build-sjasmplus.sh beanboard" $@
./build-sjasmplus.sh beanboard $@
echo "./build-sjasmplus.sh beanzee" $@
./build-sjasmplus.sh beanzee $@
