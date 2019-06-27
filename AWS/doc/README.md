# TL;DR

Use documentation for the `arun` helper script and its sub commands.

## Overview

The `arun` helper acquires an access token
for the active AWS profile (in `~/.aws/config`) as determined by the
`AWS_PROFILE` environment variable,
sets the `AWS_SECRET_ACCESS_KEY` environment variable and its friends,
and invokes a sub-command.

For example, `arun ./launchServer.sh` runs the
`launchServer.sh` script after setting the `AWS_*` environment variables with the credentials for the temporary token acquired for the active profile.

```
arun env | grep AWS_
```

## Sub-commands

The `arun` command also includes a suite of built-in subcommands for various common tasks.

* profiles

List the profiles available in `~/.aws/config`

```
arun profiles
```

* [accountBootstrap](./accountBootstrap.md)

Setup an AWS account to run `cloudformation`.