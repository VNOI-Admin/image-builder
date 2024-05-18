#!/bin/bash
source "$(dirname "$0")/common.sh"

# javac -encoding UTF-8 -sourcepath . -d . ${files}
test_case "javac compiler"
src_dir=$(mktemp -q -d /tmp/java.test.XXXXX)
cat > "$src_dir/self_test.java" << EOF
import java.io.IOException;

interface IORunnable {
    public void run() throws IOException;
}

public class self_test {
    public static void run(IORunnable target) throws IOException {
        target.run();
    }

    public static void main(String[] args) throws IOException {
        run(() -> {
            byte[] buffer = new byte[4096];
            int read;
            while ((read = System.in.read(buffer)) >= 0)
                System.out.write(buffer, 0, read);
        });
    }
}
EOF
if javac -encoding UTF-8 -sourcepath "$src_dir" -d "$src_dir" "$src_dir/self_test.java"; then
    pass
else
    fail "Compile error"
fi

# java -Dfile.encoding=UTF-8 -XX:+UseSerialGC -Xss64m -Xms1920m -Xmx1920m
test_case "java executor"
if [[ $HAS_FAILED -eq 1 ]] ; then
    fail "Execution is skipped since compilation has failed"
    exit 1
fi

exitcode=0
output=$( echo "Hello world!" | java -Dfile.encoding=UTF-8 -XX:+UseSerialGC -Xss64m -Xms1920m -Xmx1920m -classpath "$src_dir" self_test ) || exitcode=$?
if [[ $exitcode -eq 0 ]] ; then
    if [[ $output == "Hello world!" ]] ; then
        pass
    else
        fail "Expecting 'Hello world!', '$output' received"
    fi
else
    fail "Runtime error"
fi
