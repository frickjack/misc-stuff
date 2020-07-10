# TL;DR

Helpers for interacting with `cloudformation`.

## Overview

The `little stack` commands allow us to extend cloudfront templates with expressions (from the [nunjucks](https://mozilla.github.io/nunjucks/) template library) that can dynamically add resources to a stack based on variable values.
The `little stack` tools consume a json stack definition
with three main parts:
* a reference to a clouformation template
* values for the cf parameters defined in the template
* values for the nunjucks variables leveraged in the template

If an optional `openapi.yaml` file is present, then its contents are also exposed as a nunjucks variable

Most commands take form:
```
little stack command-name [--dryRun] path/to/stackParams.json
```
where `stackParams.json` includes properties for the stack name and parameters, and a `Littleware` block that includes the path to the template relative to the path in the `$LITTLE_HOME` environment variable (TODO - introduce a search path variable), and nunjucks variable values.

The stack commands upload the template to the cloudformation bucket (see `little stack bucket` below).
If the template folder has an `openapi.yaml` file, then the stack helpers publish its contents as a nunjucks variable value.


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

### filter

Apply the nunjucks variables from a stack definition to the cloudformation
tempalte referenced by the stack.
Ex:
```
little stack filter-template path/to/stackParams.json
```

### filter-template

Apply the nunjucks variables from the `$variablesStr` option - see `little stack variables` and `little stack filter`.

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
stack parameters file and adjacent `openapi.yaml`:

Ex:
```
little stack variables path/to/stack.json
```

### validate-template

Validate a filtered (see filter-template) cloudformation template

```
little stack validate-template path/to/template
```
