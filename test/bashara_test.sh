#!/bin/bash

#shellcheck source=../bashara.sh
source "$(dirname "${BASH_SOURCE[0]}")"/../bashara.sh
script_under_test=./dummy_script.sh


init; (
any_failure=0

ok_result() {
    cat - | grep -q -- "-> OK"
    return $?
}
fail_result() {
    cat - | grep -q -- "-> FAIL"
    return $?
}

print_success() {
    local res=$?
    local lineno=${BASH_LINENO[0]}
    if [[ "$res" -eq 0 ]]; then
        printf "%-65s %-12s %4s\n" "$1" "(line $lineno)" "OK"
    else
        printf "%-65s %-12s %4s\n" "$1" "(line $lineno)" "FAILED"
        any_failure=1
    fi
}

if [[ "$1" == "generate_docs" ]]; then
    print_success() { true; }
    ok_result() {
        cat -;
        echo "-> OK"
        echo '```'
        echo ""
    }
    fail_result() {
        cat -;
        echo "-> FAIL"
        echo '```'
        echo ""
    }
    expect_script() {
        fmtted=()
        for arg in "$@"; do
            fmtted+=( "'$arg'" )
        done
        echo "### $example_name"
        echo '```sh'
        echo "expect_script ${fmtted[*]}"
    }
fi


# to_print 'regex'
#   Tests for matching output using a bash regex
# Examples:
example_name="Can successfully detect matching output"
expect_script 'to_print "Finished"' | ok_result ; print_success "$example_name"

example_name="Can match multiple expectations"
expect_script 'to_print "Finished"' 'and_print "nished"' | ok_result ; print_success "$example_name"

example_name="Can successfully detect missing output"
expect_script 'to_print "Unfinito"' | fail_result ; print_success "$example_name"

# to_take_arguments arg1 'arg 2'
#  Passes arguments on the command line to the script
# Examples:
example_name="Can successfully pass multiple arguments including spaces"
expect_script 'to_take_arguments one two "thr ee"' \
        'and_print "ARG 0 = one"' \
        'and_print "ARG 1 = two"' \
        'and_print "ARG 2 = thr ee"' \
        'and_print "Finished"' \
        | ok_result ; print_success "$example_name"

# to_call 'function_name'
#  Stubs/replaces a function and verifies that it's been called
# Examples:
example_name="Can detect a function call"
expect_script 'to_take_arguments test_function' 'and_call my_function' | ok_result ; print_success "$example_name"

example_name="Can detect a missing function call"
expect_script 'to_take_arguments test_function' 'and_call not_my_function' | fail_result ; print_success "$example_name"

# to_call_original
#   Spies on a function to make sure it's run but otherwise runs the original
example_name="Spies on a function and returns original"
expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed"' | ok_result ; print_success "$example_name"

example_name="Spies on a function but doesn't replace \$?"
expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed 1"' | ok_result ; print_success "$example_name"

exit $any_failure
); any_failure=$?; cleanup

exit $any_failure