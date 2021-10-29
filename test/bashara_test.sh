#!/bin/bash

#shellcheck source=../bashara.sh
source "$(dirname "${BASH_SOURCE[0]}")"/../bashara.sh
script_under_test=./dummy_script.sh


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
init > /dev/null; (
any_failure=0


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

# to_print_to
#  Redirects output to a file
example_name="Redirects output to a file"
tmpfile=$(mktemp -p /tmp "test_stdout.XXX" --suffix ".txt")
if [[ "$1" == "generate_docs" ]]; then
    expect_script 'to_take_arguments test_function' 'and_print_to '"$tmpfile" | ok_result ; print_success "$example_name"
else
( (expect_script 'to_take_arguments test_function' 'and_print_to '"$tmpfile" >/dev/null && [[ $(cat "$tmpfile") =~ "my_function executed 1" ]]) \
    && echo " -> OK" || echo " -> FAIL") | ok_result; print_success "$example_name"
fi
rm "$tmpfile"

# to_read_stdin_from
#  Read input from a file
example_name="Reads input (stdin) from a file"
tmpfile=$(mktemp -p /tmp "test_stdin.XXX" --suffix ".txt")
echo "TESTING123" > "$tmpfile"
expect_script 'to_take_arguments test_stdin' 'and_read_stdin_from '"$tmpfile" 'and_print "STDIN:.*TESTING123"' | ok_result ; print_success "$example_name"
rm "$tmpfile"

exit $any_failure
); any_failure=$?; cleanup > /dev/null

if [[ "$any_failure" -ne 0 ]]; then exit $any_failure; fi

# new_tempfile / get_tempfile
#  Helpers for creating a new tempfile and getting the filename of it
if [[ "$1" == "generate_docs" ]]; then
    echo '### Generate temp file'
    echo '```sh'
    # shellcheck disable=SC2016
    echo 'init; new_tempfile; mytmp=$(get_tempfile); ( expect_script '\''to_read_stdin_from "'\''$mytmp'\''" ); cleanup'
    echo '-> OK'
    echo '```'
else
    example_name="Can't create a tempfile without initting"
    ([[ $( new_tempfile; init; ) =~ "You didn't call init" ]] && echo " -> OK" || echo " -> FAIL") | ok_result ; print_success "$example_name"

    example_name="Can create a tempfile"
    init > /dev/null; new_tempfile > /dev/null; tmpf=$(get_tempfile)
    if [[ -n "$tmpf" && -f "$tmpf" ]]; then echo " -> OK"; else echo " -> FAIL"; fi | ok_result; print_success "$example_name"

    example_name="Can clean up a tempfile"
    cleanup > /dev/null
    if [[ ! -f "$tmpf" ]]; then echo " -> OK"; else echo " -> FAIL"; fi | ok_result; print_success "$example_name"
fi


exit $any_failure