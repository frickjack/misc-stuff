# TL;DR

Use documentation for the `little` helper script and its sub commands.

## Overview

The `little` helper acquires an access token
for the active AWS profile (in `~/.aws/config`) as determined by the
`AWS_PROFILE` environment variable,
sets the `AWS_SECRET_ACCESS_KEY` environment variable and its friends,
and invokes a sub-command.

For example, `little ./launchServer.sh` runs the
`launchServer.sh` script after setting the `AWS_*` environment variables with the credentials for the temporary token acquired for the active profile.

```
little env | grep AWS_
```

## Sub-commands

The `little` command also includes a suite of built-in subcommands for various common tasks.

* profiles

List the profiles available in `~/.aws/config`

```
little profiles
```

* [accountBootstrap](./accountBootstrap.md)

Setup an AWS account to run `cloudformation`.


* [lambda](./lambda.md)

lambda management helpers

* [stacks](./stacks.md)

cloudformation helpers

* [secret](./secret.md)

secretsmanager helpers

## Tagging

Littleware uses the following resource tags:

* org: which billing organization owns this resource
* project: which project or application
* stack: a project or application may have multiple deployments - for different clients, tenant cells, or whatever
* stage: a particular application stack may have multiple deployments for different stages of the development process (qa, staging, production)
* role: what is the purpose of the resource?
