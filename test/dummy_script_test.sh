#!/bin/bash

#shellcheck source=../bashara.sh
source "$(dirname "${BASH_SOURCE[0]}")"/../bashara.sh
script_under_test=./dummy_script.sh


init; (
    expect_script 'to_print "Finished"'
    expect_script 'to_print "Finished"' 'and_print "nished"'
    expect_script 'to_print "Unfinito"' # This should fail
    expect_script 'to_take_arguments one two "thr ee"' \
            'and_print "ARG 0 = one"' \
            'and_print "ARG 1 = two"' \
            'and_print "ARG 2 = thr ee"' \
            'and_print "Finished"'
    expect_script 'to_take_arguments test_function' 'and_call my_function'
    expect_script 'to_take_arguments test_function' 'and_call not_my_function' # This should fail
    expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed"'
    expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed 1"'

    tmpfile=$(mktemp -p /tmp "test_stdout.XXX" --suffix ".txt")
    res=$(expect_script 'to_take_arguments test_function' 'and_print_to '"$tmpfile" && [[ $(cat "$tmpfile") =~ "my_function executed 1" ]]) && echo "$res -> OK" || echo "$res -> FAIL"
    echo "TESTING123" > "$tmpfile"
    expect_script 'to_take_arguments test_stdin' 'and_read_stdin_from '"$tmpfile" 'and_print "STDIN:.*TESTING123"'

); cleanup

echo -n "Can't create a tempfile without initting: "; [[ $( new_tempfile; init; ) =~ "You didn't call init" ]] && echo " -> OK" || echo " -> FAIL"
init; new_tempfile; f=$(get_tempfile)
echo -n "Can get tempfile after initting"; [[ -n "$f" ]] && echo " -> OK" || echo " -> FAIL"
echo -n "Can create tempfile after initting"; [[ -f "$f" ]] && echo " -> OK" || echo " -> FAIL"
cleanup > /dev/null
echo -n "Cleaned tempfile on cleanup"; [[ ! -f "$f" ]] && echo " -> OK" || echo " -> FAIL"
