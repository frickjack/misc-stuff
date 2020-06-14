# TL;DR

Helpers for interacting with `cloudformation`.

## Overview

Most commands take form:
```
little stack command-name path/to/stackParams.json
```
where `stackParams.json` includes properties for the stack name and parameters, and a `Littleware` block that includes the path to the template relative to the path in the `$LITTLE_HOME` environment variable (TODO - introduce a search path variable).

The stack commands upload the template to the cloudformation bucket (see `aws stack bucket`).  
If the template folder has an `openapi.yaml` file, then the stack helpers inline its contents as the `Body` of the first `ApiGateway::RestApi` resource in the template.


## Use

### bucket

Get the name of the S3 bucket devoted to cloudformation template staging (under the `/cf/` prefix) and other similar devops tasks.

```
little stack bucket
```

### create

Create a new stack

```
little stack create path/to/stackParams.json
```

### describe

Describe an existing stack

```
little stack describe path/to/stackParams.json
```

### make-change

Create a change set (with name `little stack change-name`) for the specified stack

```
little stack make-change path/to/stackParams.json
```

### rm-change

Remove an unapplied change, so a new change may be submitted

```
little stack rm-change path/to/stackParams.json
```

### show-change

Show the last change set created via `make-change`

```
little stack show-change path/to/stackParams.json
```

### exec-change

Execute the last change set created via `make-change`

```
little stack exec-change path/to/stackParams.json
```

### change-name

The change-set name for change-set operations (`make-change`, `show-change`, `exec-change`) has form `little-$USER-$HOSTNAME` 

### update

Update an existing stack

```
little stack update path/to/stackParams.json
```

### delete

Delete an existing stack, and its associated resources.

```
little stack delete path/to/stackParams.json
```

### events

Retrieve the event log for a stack

```
little stack update path/to/stackParams.json
```

### filter-template

Apply the following filters to a cloudformation template.

* inline an `openapi.yaml` or `openapi.json` file in the template directory as the `Body` property
* apply the nunjucks variables from the optional json `$variablesStr` - see `little stack variables` below.

Ex:
```
little stack filter-template path/to/template [$variablesStr]
```

Filter a template with variables extracted from a littleware stack json:
```
little stack filter-template "$LITTLE_HOME/AWS/lib/cloudformation/cellSetup/apiGateway.json" "$(little stack variables "$LITTLE_HOME/AWS/lib/cloudformation/cellSetup/sampleStackParams.json")"
```

### resources

Shortcut for `aws cloudformation list-resources` - ex:

```
little stack resources ./stackParams.json
```

### variables

Extract template variables (for `filter-template`) from the given
stack parameters

Ex:
```
little stack variables path/to/stack.json
```

### validate-template

Validate a filtered (see filter-template) cloudformation template

```
little stack validate-template path/to/template
```
