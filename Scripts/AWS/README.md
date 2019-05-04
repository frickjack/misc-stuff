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
bash AWS/bin/accountBootstrap.sh
```
