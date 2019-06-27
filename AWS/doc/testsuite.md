# TL;DR

Run through the testsuite


## Examples

* Run the entire test suite
```
arun testsuite
```

* Run the tests tagged with the "local" tag - local test do not require a 
test environment (kubernetes and AWS) to test against
```
arun testsuite --filter local
```

* Run the tests tagged with either the "local" or the "stack" tag
```
arun testsuite --filter local,stack
```

* Run particular test functions
```
arun testsuite --filter test_stack_list,test_arun
```
