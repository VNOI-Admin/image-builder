set -e

CMD=$(basename "$0")
HAS_FAILED=0

unhandled_error() {
	local lineno="$1"
	local message="$2"
	local code="${3:-1}"
	if [[ -n "$message" ]] ; then
		echo "$CMD: Error at or near line ${lineno}: ${message}; exiting with status ${code}"
	else
		echo "$CMD: Error at or near line ${lineno}; exiting with status ${code}"
	fi
	exit 2
}

exit_handler() {
    if [[ $? -eq 2 ]] ; then
        exit 2
    else
        exit $HAS_FAILED
    fi
}

trap 'unhandled_error ${LINENO}' ERR
trap 'exit_handler' EXIT

if [[ -z "${CASE_COUNT+x}" ]] ; then
    CASE_COUNT=0
    PASS_COUNT=0
fi

test_case() {
    CASE_COUNT=$(( $CASE_COUNT + 1 ))
    echo -e "\e[33mCASE $CASE_COUNT\e[0m\t$CMD $1"
}

pass() {
    PASS_COUNT=$(( $PASS_COUNT + 1 ))
    echo -e "\e[32mPASS $1\e[0m"
}

fail() {
    HAS_FAILED=$(( $HAS_FAILED | 1 ))
    echo -e "\e[31mFAIL $1\e[0m"
}
