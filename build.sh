#!/usr/bin/env bash

# Build all targets or a named target
# Usage: ./build.sh [target] [org]
# Examples:
#   ./build.sh              # build all targets
#   ./build.sh beanzee      # build beanzee only
#   ./build.sh beanboard    # build beanboard only

if [ $# -gt 0 ]; then
    target=$1
    shift
    echo "./targets/$target/build.sh" "$@"
    ./targets/$target/build.sh "$@"
else
    echo "./targets/beanzee/build.sh"
    ./targets/beanzee/build.sh
    echo "./targets/beanboard/build.sh"
    ./targets/beanboard/build.sh
fi
