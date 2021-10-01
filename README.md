# Bashara

Bashara is a "framework" (using the word loosely) for testing Bash scripts that adhere to certain parameters.

## Getting started
You only need to download `bashara.sh` and then use it per the help:
Create a new file, e.g. `my_bash_script_test.sh` and put in the following.
```sh
#!/bin/bash
source "./bashara.sh"
script_under_test="../my_bash_script.sh"
# debug=1 # Uncomment to enable debug output
init; (
    # expect_script 'to_call_original default_init" "and_print \"Boot\"'
    # expect_script "to_call default_init"

    # it should print help when bad arguments are given
    # expect_script "to_take_arguments derp" 'and_print "Help.*Unexpected.*derp"'
); cleanup
```

## Examples

### Can successfully detect matching output
```sh
expect_script 'to_print "Finished"'
-> OK
```

### Can match multiple expectations
```sh
expect_script 'to_print "Finished"' 'and_print "nished"'
-> OK
```

### Can successfully detect missing output
```sh
expect_script 'to_print "Unfinito"'
-> FAIL
```

### Can successfully pass multiple arguments including spaces
```sh
expect_script 'to_take_arguments one two "thr ee"' 'and_print "ARG 0 = one"' 'and_print "ARG 1 = two"' 'and_print "ARG 2 = thr ee"' 'and_print "Finished"'
-> OK
```

### Can detect a function call
```sh
expect_script 'to_take_arguments test_function' 'and_call my_function'
-> OK
```

### Can detect a missing function call
```sh
expect_script 'to_take_arguments test_function' 'and_call not_my_function'
-> FAIL
```

### Spies on a function and returns original
```sh
expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed"'
-> OK
```

### Spies on a function but doesn't replace $?
```sh
expect_script 'to_take_arguments test_function' 'and_call_original my_function' 'to_print "my_function executed 1"'
-> OK
```

### Note
All of the expectations can start with either `to_` or `and_` for readability.

## FAQ
### Why isn't `to_call` working?
The `to_call` and `to_call_original` expectations inject code into your script by using `trap` to find the first line with a statement (vs. comments or function definitions). This requires that any functions you want to spy on are defined before the first statement.

This is bad, and you wont be able to test/inject on `my_function()`:
```sh
#!/bin/bash
echo "Hello"
my_function() {
    echo "do stuff"
}
```

This is good:
```sh
#!/bin/bash
my_function() {
    echo "do stuff"
}

echo "Hello"
```


## See also

Check out `test/bashara_test.sh` for the self-testing, and `test/dummy_script_test.sh` for live examples.