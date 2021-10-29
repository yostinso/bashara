#!/bin/bash

print_usage() {
    cat <<'EOF'
Create a new file and source this one using the following template:

#!/bin/bash
source "${0}"
script_under_test="../my_bash_script.sh"
# debug=1 # Uncomment to enable debug output
init; (
    # expect_script 'to_call_original default_init" "and_print \"Boot\"'
    # expect_script "to_call default_init"

    # it should print help when bad arguments are given
    # expect_script "to_take_arguments derp" 'and_print "Help.*Unexpected.*derp"'
); cleanup

# There are also a couple of helpers for temp files, you can use them like so:
init
new_tempfile
mytmp=$(get_tempfile)
(
    expect_script 'to_read_stdin_from "'"$mytmp"'"'
)
cleanup
EOF
}

tmpfiles=()
init() {
    echo "Initializing..."
    local dirname
    dirname=$(dirname "${BASH_SOURCE[1]}")
    orig_script_path="$dirname"/"${script_under_test:?}"
    script_path=$(mktemp -p /tmp "bash-test.XXX" --suffix ".$(basename "$script_under_test")") || exit

    if [[ ! -f $script_path ]]; then
        echo_indent "  Unable to find \"$script_path\""
        exit 1
    fi

    # Find the injection point
    {
        echo "#!/bin/bash"
        #echo "shopt -s extdebug"
        #echo "trap 'echo \"\$LINENO\"; false' DEBUG"
        echo "trap 'echo \"\$LINENO\"; exit' DEBUG"
        cat "$orig_script_path"
    } > "$script_path"
    chmod 755 "$script_path"

    injection_line=$("$script_path")
    injection_line=$((injection_line - 3)) # Subtract the extra trap lines, and move up above the first statement
    echo_debug "Injection line discovered at line $injection_line"

    # Rebuild the script
    cat "$orig_script_path" > "$script_path"
    bashara_initialized=1
    tmpfiles=()
    echo ""
}

cleanup() {
    bashara_initialized=""
    echo "Cleaning up..."
    rm "$script_path"
    for tmpfile in "${tmpfiles[@]}"; do
        rm "$tmpfile"
    done
}

inject_spies() {
    # Rebuild the script
    local line_after=$((injection_line+1))
    {
        head -n "$injection_line" "$orig_script_path"
        for injection in "${injections[@]}"; do
            echo "$injection"
        done
        tail -n +"$line_after" "$orig_script_path"
    } > "$script_path"
}

format_args() {
    local args=()
    for arg in "$@"; do
        if [[ "$arg" =~ " " ]]; then
            args+=("'$arg'")
        else
            args+=("$arg")
        fi
    done
    echo "${args[*]}"
}

echo_debug() {
    if [[ -n $debug ]]; then
        echo "  ${*//$'\n'/$'\n  '}"
    fi
}

echo_indent() {
    local spacecount=${2:-2}
    local prefix="$3"
    local spaces=""
    for ((i=0; i<spacecount; i++)); do
      spaces+=" "
    done
    echo "${spaces}${prefix}${1//$'\n'/$'\n'${spaces}${prefix}}"
}

echo_pp() {
    for s in "$@"; do
        printf '%s\n' "$s"
    done
}

and_take_arguments() {
    # xhellcheck disable
    for arg in "$@"; do
        echo "take_args+=( \"$arg\" );"
    done
}
to_take_arguments() {
    and_take_arguments "$@"
}

and_print() {
    echo "print_matches+=(\"$*\");"
}
to_print() {
    and_print "$@"
}

and_print_to() {
    echo "print_to=\"$1\";"
}
to_print_to() {
    and_print_to "$@"
}

and_read_stdin_from() {
    echo "read_stdin_from=\"$1\";"
}
to_read_stdin_from() {
    and_read_stdin_from "$@"
}

# https://stackoverflow.com/questions/1203583/how-do-i-rename-a-bash-function
and_call() {
    local method_name="$1" uuid
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "injections+=( \"$method_name() { echo '$uuid'; true; }\" )"
    echo "inject_expects+=(\"$method_name=$uuid\")"
    echo "should_call+=(\"$method_name\")"
}
to_call() {
    and_call "$@"
}

and_call_original() {
    local method_name="$1" uuid
    uuid=$(cat /proc/sys/kernel/random/uuid)
    local copy_function
    # Some magic here, this is meant to generate:
    # eval "$(
    #         echo "my_function()"
    #         echo "{"
    #         echo "  local bashara_res=\$?;"
    #         echo "  echo 'ad01dca0-c92e-4d1c-8429-29bb764e42ed';"
    #         echo "  (exit $bashara_res);"
    #         declare -f 'my_function' | tail -n +3;
    # )"
    # ... which in turn generates a modified copy of the function:
    # my_function()
    # {
    #   local bashara_res=$?
    #   echo 'spy-uuid-here'
    #   (exit $bashara_res) # to reset $?
    #   ... original function body ...
    # }
    copy_function=$(cat << EOF
        eval "\$(
            echo "${method_name}()"
            echo "{"
            echo "  local bashara_res='\\\\'\$?;"
            echo "  echo '\\'$uuid\\'';"
            echo "  (exit '\\\\'\$bashara_res);"
            declare -f '\\'$method_name\\'' | tail -n +3;
        )"
EOF
    )
    echo "injections+=( '$copy_function' )"
    echo "inject_expects+=(\"$method_name=$uuid\")"
    echo "should_call+=(\"$method_name\")"
}
to_call_original() {
    and_call_original "$@"
}

expect_script() {
    if [[ -z "$bashara_initialized" ]]; then
        echo $'\n'"You didn't call init!"$'\n'
        print_usage
        exit
    fi

    local args=()
    for var in "$@"; do
        args+=( "$(eval "$var")" ) || exit 1
    done
    execute_tests "${args[@]}"
    return $?
}

new_tempfile() {
    if [[ -z "$bashara_initialized" ]]; then
        echo $'\n'"You didn't call init before trying to create a temp file!"$'\n'
        print_usage
        exit
    fi
    local tmp
    tmp=$(mktemp -p /tmp "test_tempfile.XXX" --suffix ".txt")
    tmpfiles+=("$tmp")
    echo "Created $tmp"
}

get_tempfile() {
    echo "${tmpfiles[-1]}"
}

execute_tests() {
    # Overridden by eval below
    local take_args=() print_matches=() print_to="" read_stdin_from=""
    local injections=() inject_expects=() should_call=()

    for var in "$@"; do
        if [[ -n $var ]]; then
            eval "${var[@]}"
        fi
    done
    inject_spies "${injections[@]}"

    local cmd desc

    cmd="$script_path ${take_args[*]}"

    desc=( "$(basename "$script_under_test")" )
    if [[ -n "$read_stdin_from" ]]; then desc+=("should read STDIN from $read_stdin_from"); fi
    if [[ ${#should_call[@]} -gt 0 ]]; then desc+=("should call '$(format_args "${should_call[@]}")'"); fi
    if [[ ${#print_matches[@]} -gt 0 ]]; then desc+=("should print $( echo_pp "${print_matches[@]}" )"); fi
    if [[ ${#take_args[@]} -gt 0 ]]; then desc+=("take args ( $(format_args "${take_args[@]}") )"); fi
    if [[ -n "$print_to" ]]; then desc+=("should print to $print_to"); fi

    local desc_count="${#desc[@]}"
    for ((i=0; i<desc_count; i++)); do
        if [[ $i -gt 0 ]]; then echo -n " "; fi
        if [[ $i -gt 1 ]]; then echo -n "and "; fi
        echo -n "${desc[$i]}"
    done

    echo_debug $'\n'"  Running $cmd"
    if [[ -n "$read_stdin_from" ]]; then
        results=$("$script_path" "${take_args[@]}" < "$read_stdin_from" 2>&1)
    else
        results=$("$script_path" "${take_args[@]}" 2>&1)
    fi

    failure=0
    errmsg=""

    local trimmed_results="$results"
    if [[ ${#inject_expects[@]} -gt -0 ]]; then
        for inject_expect in "${inject_expects[@]}"; do

            local method_name="${inject_expect%=*}"
            local uuid="${inject_expect##*=}"

            trimmed_results=${trimmed_results//$uuid$'\n'/}

            if [[ ! "$results" == *"$uuid"* ]]; then
                errmsg+=$(
                    echo_indent "Missed calling: $method_name"
                    echo_debug "$(echo_indent "For UUID $uuid", 4)"
                )
                failure=1
            fi
        done
    fi


    if [[ ${#print_matches[@]} -gt -0 ]]; then
        print_match_failure=0
        print_match_msg=""
        for print_match in "${print_matches[@]}"; do
            if [[ ! "$trimmed_results" =~ $print_match ]]; then
                print_match_msg+=$(
                    echo_indent "Expected:"
                    echo_indent "$print_match" 4 ">  "
                )
                print_match_failure=1
            fi
        done
        if [[ $print_match_failure -gt 0 ]]; then
            failure=1
            errmsg+=$(
                echo_indent "Bad output:"
                echo_indent "$results" 4 ">  "
                echo "$print_match_msg"
            )
        fi
    fi

    if [[ -n "$print_to" ]]; then
        echo "$trimmed_results" > "$print_to"
    fi

    if [[ $failure -eq 0 ]]; then
        echo_debug "$(echo_indent "Output:" 4)"
        echo_debug "$(echo_indent "$trimmed_results" 4 "> ")"
        if [[ -n $debug ]]; then echo_indent "OK"; else echo " -> OK"; fi
    else
        if [[ -n $debug ]]; then
            echo_indent "FAIL"
        else
            echo " -> FAIL [${BASH_SOURCE[2]}:${BASH_LINENO[1]}]"
        fi
        if [[ -z $debug ]]; then echo ""; fi
        echo "$errmsg"
    fi
    return $failure
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_usage
    exit
fi
