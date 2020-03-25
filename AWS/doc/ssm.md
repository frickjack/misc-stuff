# TL;DR

Helpers for interacting with AWS 
[system manager](https://aws.amazon.com/systems-manager/) - especially the parameter store.
We usually prefer systems manager parameters over secrets manager secrets, because ssm parameter are free.  However, secrets have integrated versioning and lambda based rotation mechanism that may be useful in some situations.

## Use

### put-parameter

Create or update an ssm parameter.  The parameter name should take form `$org.$project.$stack.$stage.$role` - details [here](./README.md)

```
little ssm put-param org.project.stack.stage.role $value $description
```

Retrieve a parameter value with `aws ssm get-parameter` - ex:
```
aws ssm get-parameter --name $paramName --with-decryption
```
