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
    expect_script 'to_take_arguments test_function' 'and_call not_my_function'
    expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed"'
    expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed 1"'
); cleanup