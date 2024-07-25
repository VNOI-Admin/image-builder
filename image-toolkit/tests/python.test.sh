#!/bin/bash
source "$(dirname "$0")/common.sh"

test_case "pypy3 interpreter"
src_path=$(mktemp -q /tmp/src.XXXXX.py)
cat > "$src_path" << EOF
import sys
if sys.version_info.major == 3:
    print(sys.stdin.read(), end='')
EOF

exitcode=0
output=$( echo "Hello world!" | pypy3 "$src_path" ) || exitcode=$?
if [[ $exitcode -eq 0 ]] ; then
    if [[ $output == "Hello world!" ]] ; then
        pass
    else
        fail "Expecting 'Hello world!', '$output' received"
    fi
else
    fail "Runtime error"
fi
