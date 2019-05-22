# TL;DR

Cloudformation templates to bootstrap a new account.

## Setup

### Bootstrap

The bootstrap runs as SuperAdmin.
```
{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*",
    "Condition": {
        "Bool": {
            "aws:MultiFactorAuthPresent": "true"
        }
    }
}
```

Run with:
```
arun accountBootstrap
```

### Cloudformation

```
aws cloudformation validate-template --template-body "$(cat IamSetup.json)"
```

Deploying the stack requires the cloudformation capablity flag: `CAPABILITY_NAMED_IAM` (details [here](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-template.html)).

## User Groups and Roles

* IamAdmin - full access to IAM APIs
* UserAdmin - user and group administration
    - add/remove user to groups
    - create new user
    - rotate user passwords and keys
* Operator - full access to all non-IAM API's

The AWS policies granting API access are attached to a role, and a group has a policy attached to it that allows its members to assume the group's role.  This pattern
mirrors that of federated authentication - where an
authenticated user assumes a role.

## Cloud trail

* Cloud trail for all management events
* Cloudwatch logs setup for management events
* Daily reports


## AWS Config

* enforce tagging conventions
```
"Tagging": {
        "TagSet": [
            {
                "Key": "org",
                "Value": "devops"
            },
            {
                "Key": "project",
                "Value": "infrastructure"
            },
            {
                "Key": "stack",
                "Value": "main"
            },
            {
                "Key": "stage",
                "Value": "prod"
            },
            {
              "Key": "role",
              "Value": "cloudformation-bucket"
            }
        ]
    }
```

* https://aws.amazon.com/config/


## Notes

* This started as a copy of https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/WordPress_Single_Instance.template

