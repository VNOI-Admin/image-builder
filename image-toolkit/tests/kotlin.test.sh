#!/bin/bash
source "$(dirname "$0")/common.sh"

# kotlinc -d . ${files}
test_case "kotlinc compiler"
src_dir=$(mktemp -q -d /tmp/kotlin.test.XXXXX)
cat > "$src_dir/main.kt" << EOF
fun main(@Suppress("UNUSED_PARAMETER") args: Array<String>) {
    println(readLine())
}
EOF
if kotlinc -d "$src_dir" "$src_dir/main.kt"; then
    pass
else
    fail "Compile error"
fi

# kotlin -Dfile.encoding=UTF-8 -J-XX:+UseSerialGC -J-Xss64m -J-Xms1920m -J-Xmx1920m
test_case "kotlin executor"
if [[ $HAS_FAILED -eq 1 ]] ; then
    fail "Execution is skipped since compilation has failed"
    exit 1
fi

exitcode=0
output=$( echo "Hello world!" | kotlin -Dfile.encoding=UTF-8 -J-XX:+UseSerialGC -J-Xss64m -J-Xms1920m -J-Xmx1920m -classpath "$src_dir" MainKt ) || exitcode=$?
if [[ $exitcode -eq 0 ]] ; then
    if [[ $output == "Hello world!" ]] ; then
        pass
    else
        fail "Expecting 'Hello world!', '$output' received"
    fi
else
    fail "Runtime error"
fi
