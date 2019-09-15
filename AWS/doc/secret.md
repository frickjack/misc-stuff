# TL;DR

Helpers for interacting with AWS 
[secrets manager](https://aws.amazon.com/secrets-manager/).

## Use

### create

Create a new secret.  The secret name should take form `$org/$project/$stack/$stage/$role` - details [here](./README.md)

```
arun secrets org/project/stack/stage/role value description
```

### lookup
