#!/bin/bash

my_function() {
    echo "my_function executed $?"
}

args=( "$@" )
if [[ "$1" == "test_function" ]]; then
    false
    my_function
elif [[ "$1" == "test_stdin" ]]; then
    echo "STDIN:"
    cat -
else
    if [[ "${#args}" -gt 0 ]]; then
        for (( i=0; i<"${#args[@]}"; i++ )); do
            arg="${args[$i]}"
            echo "ARG $i = $arg"
        done
    fi
fi

echo "Finished"