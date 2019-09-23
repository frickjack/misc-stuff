# TL;DR

Helpers for interacting with AWS 
[secrets manager](https://aws.amazon.com/secrets-manager/).

## Use

### create

Create a new secret.  The secret name should take form `$org/$project/$stack/$stage/$role` - details [here](./README.md)

```
arun secret create org/project/stack/stage/role value description
```

### lookup

Lookup a secret by name

```
secretInfoJson="$(arun secret lookup org/project/stack/stage/role)"
```

## SSM Integration

Secretsmanager secrets are also accessible as ssm parameters, for use in services that integrate with ssm.

Ex:
```
aws ssm get-parameter --name /aws/reference/secretsmanager/applications/cicd/cell0/dev/npmjs-token --with-decryption
```

See https://docs.aws.amazon.com/systems-manager/latest/userguide/integration-ps-secretsmanager.html
