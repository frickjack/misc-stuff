# TL;DR

Helpers for interacting with AWS 
[secrets manager](https://aws.amazon.com/secrets-manager/).

## Use

### create

Create a new secretsmanager secret.  The secret name should take form `$org/$project/$stack/$stage/$role` - details [here](./README.md)

```
little secret create org/project/stack/stage/role value description
```

Use `aws secretsmanager put-secret-value` to update a secret - ex:
```
aws secretsmanager put-secret-value --secret-id $(little secret lookup $name) --secrets-string $newValue
```

### lookup

Lookup a secret by name

```
secretInfoJson="$(little secret lookup org/project/stack/stage/role)"
```

## SSM Integration

Secretsmanager secrets are also accessible as ssm parameters, for use in services that integrate with ssm.

Ex:
```
aws ssm get-parameter --name /aws/reference/secretsmanager/applications/cicd/cell0/dev/npmjs-token --with-decryption
```

See https://docs.aws.amazon.com/systems-manager/latest/userguide/integration-ps-secretsmanager.html
