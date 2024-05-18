#!/bin/bash
set +e

DIRNAME="$(dirname "$0")"
export CASE_COUNT=0
export PASS_COUNT=0

log() {
    echo -e "\e[36m$1\e[0m"
}

run_test() {
    # https://stackoverflow.com/a/12451419
    exec 5>&1
    OUTPUT=$( "$DIRNAME/tests/$1" | tee >(cat - >&5); exit ${PIPESTATUS[0]} )
    exitcode=$?

    CASE_COUNT=$((
        $CASE_COUNT +
        $(
            echo "$OUTPUT" |
            sed -e 's/\x1b\[[0-9;]*m//g' |
            grep '^CASE [0-9;]*' | wc -l
        )
    ))
    PASS_COUNT=$((
        $PASS_COUNT +
        $(
            echo "$OUTPUT" |
            sed -e 's/\x1b\[[0-9;]*m//g' |
            grep '^PASS' |
            wc -l
        )
    ))

    if [[ $exitcode -eq 2 ]] ; then
        exit 2
    fi
}

log "Running all tests"

run_test network.test.sh
run_test stream.test.sh
run_test gcc.test.sh
run_test python.test.sh
run_test permission.test.sh

log "Completed with \e[32m$PASS_COUNT PASSED\e[36m, \e[31m$(($CASE_COUNT - $PASS_COUNT)) FAILED\e[0m"
