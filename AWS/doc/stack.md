# TL;DR

Helpers for interacting with `cloudformation`.

## Overview

Most commands take form:
```
arun stack command-name path/to/stackParams.json
```
where `stackParams.json` includes properties for the stack name and parameters, and a `Littleware` block that includes the path to the template relative to the path in the `$LITTLE_HOME` environment variable (TODO - introduce a search path variable).

The stack commands upload the template to the cloudformation bucket (see `aws stack bucket`).  
If the template folder has an `openapi.yaml` file, then the stack helpers inline its contents as the `Body` of the first `ApiGateway::RestApi` resource in the template.

If the stack folder has a `code/` subfolder, then the stack helpers zip up the code, upload the zip file to the cloudformation bucket, and insert `LambdaBucket` and `LambdaKey` into the stack parameters before sending them onto the underlying cloudformation commands, so a template may specify those parameters as inputs when defining lambda resources.


## Use

### bucket

Get the name of the S3 bucket devoted to cloudformation template staging (under the `/cf/` prefix) and other similar devops tasks.

```
arun stack bucket
```

### create

Create a new stack

```
arun stack create path/to/stackParams.json
```

### describe

Describe an existing stack

```
arun stack describe path/to/stackParams.json
```

### make-change

Create a change set (with name `arun stack change-name`) for the specified stack

```
arun stack make-change path/to/stackParams.json
```

### show-change

Show the last change set created via `make-change`

```
arun stack show-change path/to/stackParams.json
```

### exec-change

Execute the last change set created via `make-change`

```
arun stack exec-change path/to/stackParams.json
```

### change-name

The change-set name for change-set operations (`make-change`, `show-change`, `exec-change`) has form `little-$USER-$HOSTNAME` 

### update

Update an existing stack

```
arun stack update path/to/stackParams.json
```

### delete

Delete an existing stack, and its associated resources.

```
arun stack delete path/to/stackParams.json
```

### events

Retrieve the event log for a stack

```
arun stack update path/to/stackParams.json
```

### filter-template

Apply filters to a cloudformation template.
Currently the only filter inlines an `openapi.yaml` or `openapi.json` file in the template directory as the `Body` property

```
arun stack filter-template path/to/template
```

### validate-template

Validate a filtered (see filter-template) cloudformation template

```
arun stack validate-template path/to/template
```
