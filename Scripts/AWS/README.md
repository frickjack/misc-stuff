# TL;DR

Helpers for interacting with AWS.

## Catalog

### arun profile command

Run a command with AWS credential environment variables set.  Handles caching creds for assumed roles.

ex:
```
alias arun='bash AWS/bin/arun.sh'
arun admin-ohio env
```

### accountBootstrap

Setup a cloudformation bucket in the region for the
active profile, so that the `bootstrap` cloudformation
stack can be deployed.

ex:
```
arun accountBootstrap
```

### arun stack

* `arun stack create`
* `arun stack update`
* `arun stack events`
* `arun stack list`

## Account Hidration

* Authz - IAM setup

```
arun stack create lib/cloudFormation/accountSetup/iamSetup.json db/cloudformaton/frickjack/accountSetup/iamSetup.json
```

* Notification - SNS setup

```
 arun stack events lib/cloudFormation/accountSetup/snsNotifyTopic.json db/cloudformaton/frickjack/accountSetup/snsNotify.json
 ```
