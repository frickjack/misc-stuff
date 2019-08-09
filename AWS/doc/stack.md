# TL;DR

Helpers for interacting with `cloudformation`.

## Commands

### bucket

Get the name of the S3 bucket devoted to cloudformation template staging (under the `/cf/` prefix) and other similar devops tasks.

```
arun stack bucket
```

### create

Create a new stack

```
arun stack create path/to/template path/to/cli-parameters.json
```

### update

Update an existing stack

```
arun stack update path/to/template path/to/cli-parameters.json
```

### delete

Delete an existing stack, and its associated resources.

```
arun stack delete path/to/template path/to/cli-parameters.json
```

### events

Retrieve the event log for a stack

```
arun stack update path/to/template path/to/cli-parameters.json
```

### validate

Validate a cloudformation template

```
arun stack validate path/to/template
```
