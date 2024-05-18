#!/bin/bash
source "$(dirname "$0")/common.sh"

# gcc -x c -g -O2 -std=gnu11 -static ${files} -lm
test_case "c11 compiler"
src_path=$(mktemp -q /tmp/src.XXXXX.c)
cat > "$src_path" << EOF
#include <stdio.h>

#if __STDC_VERSION__ == 201112
int main() {
    int ch;
    while ((ch = getchar()) != EOF)
        putchar(ch);
    return 0;
}
#endif
EOF

out_path=$(mktemp -q /tmp/main.XXXXX.out)
if gcc -x c -g -O2 -std=gnu11 -static "$src_path" -lm -o "$out_path"; then
    exitcode=0
    output=$( echo "Hello world!" | "$out_path" ) || exitcode=$?
    if [[ $exitcode -eq 0 ]] ; then
        if [[ $output == "Hello world!" ]] ; then
            pass
        else
            fail "Expecting 'Hello world!', '$output' received"
        fi
    else
        fail "Runtime error"
    fi
else
    fail "Compile error"
fi

# g++ -x c++ -g -O2 -std=gnu++20 -static ${files}
test_case "c++20 compiler"
src_path=$(mktemp -q /tmp/src.XXXXX.cpp)
cat > "$src_path" << EOF
#include <iostream>

#if __cplusplus == 202002
int main() {
    std::strong_ordering comparison = 1 <=> 2;
    auto input = std::cin.rdbuf();
    std::cout << input;
    return 0;
}
#endif
EOF

out_path=$(mktemp -q /tmp/main.XXXXX.out)
if $(g++ -x c++ -g -O2 -std=gnu++20 -static "$src_path" -o "$out_path"); then
    exitcode=0
    output=$( echo "Hello world!" | "$out_path" ) || exitcode=$?
    if [[ $exitcode -eq 0 ]] ; then
        if [[ $output == "Hello world!" ]] ; then
            pass
        else
            fail "Expecting 'Hello world!', '$output' received"
        fi
    else
        fail "Runtime error"
    fi
else
    fail "Compile error"
fi
