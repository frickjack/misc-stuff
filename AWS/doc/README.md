# TL;DR

Use documentation for the `little` helper script and its sub commands.

## Setup

The `little` scripts are currently installed and updated via `git`.

```
git clone https://github.com/frickjack/misc-stuff.git
alias little='bash ~/Code/misc-stuff/AWS/little.sh'
```

### Dependencies

* bash 4+
* [jq](https://stedolan.github.io/jq/manual/)
* [aws cli](https://aws.amazon.com/cli/).

### Credentials

The `little` commands require AWS credentials to interact with the AWS API.  There are a variety of ways to configure the AWS SDK - the [account setup notes](../../Notes/explanation/accountHydrate.md) have more details.

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

A developer laptop might have the
following AWS config that requires multifactor
authentication.

```
$ cat ~/.aws/config 
[default]
region = us-east-2
output = json
mfa_serial = arn:aws:iam::XXXXXXXXX:mfa/frickjack

[profile admin-virginia]
region = us-east-1
role_arn = arn:aws:iam::XXXXXXXXX:role/trystuff-admin
source_profile = default
mfa_serial = arn:aws:iam::XXXXXXXXX:mfa/frickjack

[profile admin-ohio]
region = us-east-2
role_arn = arn:aws:iam::XXXXXXXXX:role/littleware/account/user/littleAdmin
source_profile = default
mfa_serial = arn:aws:iam::XXXXXXXXX:mfa/frickjack

```

The `little` command prompts the user her MFA token as necessary, and sets environment variables for subsequently invoked sub-commands.

```
little env | grep AWS
little --profile admin-ohio env | grep AWS
```


## Sub-commands

The `little` command includes a suite of subcommands under `AWS/bin/` for various common tasks.  By convention the commands in `AWS/bin/basic/` do not require AWS credentials to be setup in the environment.

* profiles

List the profiles available in `~/.aws/config`

```
little profiles
```

* [accountBootstrap](./accountBootstrap.md)

Setup an AWS account to run `cloudformation`.


* [lambda](./lambda.md)

lambda management helpers

* [markdown](./markdown.md)

simple markdown renderer

* [publish](./publish.md)

publish a message to an sns topic

* [stack](./stack.md)

cloudformation helpers

* [secret](./secret.md)

secretsmanager helpers

* [ssm](./ssm.md)

systems manager properties helpers

* [testsuite](./testsuite.md)

## Tagging

Littleware uses the following resource tags:

* org: which billing organization owns this resource
* project: which project or application
* stack: a project or application may have multiple deployments - for different clients, tenant cells, or whatever
* stage: a particular application stack may have multiple deployments for different stages of the development process (qa, staging, production)
* role: what is the purpose of the resource?

# Resources

* https://asecure.cloud/
