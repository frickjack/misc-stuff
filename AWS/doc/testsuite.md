# TL;DR

Run through the testsuite


## Overview

* Run the entire test suite
```
little testsuite
```

* Run the tests tagged with the "local" tag - local test do not require a 
test environment (kubernetes and AWS) to test against
```
little testsuite --filter local
```

* Run the tests tagged with either the "local" or the "stack" tag
```
little testsuite --filter local,stack
```

* Run particular test functions
```
little testsuite --filter test_stack_list,test_little
```
