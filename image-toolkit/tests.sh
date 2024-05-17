#!/bin/bash
set +e

DIRNAME="$(dirname "$0")"
export CASE_COUNT=0
export PASS_COUNT=0

log() {
    echo -e "\e[36m$1\e[0m"
}

run_test() {
    OUTPUT=$("$DIRNAME/tests/$1")
    exitcode=$?
    echo "$OUTPUT"

    _CASE_COUNT=$(echo "$OUTPUT" | sed -e 's/\x1b\[[0-9;]*m//g' | grep '^CASE [0-9;]*' | wc -l)
    _PASS_COUNT=$(echo "$OUTPUT" | sed -e 's/\x1b\[[0-9;]*m//g' | grep '^PASS' | wc -l)
    CASE_COUNT=$(( $CASE_COUNT + $_CASE_COUNT ))
    PASS_COUNT=$(( $PASS_COUNT + $_PASS_COUNT ))

    if [[ $exitcode -eq 2 ]] ; then
        exit 2
    fi
}

log "Running all tests"

log "Completed with \e[32m$PASS_COUNT PASSED\e[36m, \e[31m$(($CASE_COUNT - $PASS_COUNT)) FAILED\e[0m"
