# TL;DR

So you just got your brand spankin' new AWS account, and your team is launching like a rocket into the cloud.
How should you set this account thing up?
Before playing with EC2 instances
and S3 buckets and all the other toys at the application layer of the stack; 
you should figure out how you want to authenticate,
authorize, and monitor users manipulating your base cloud infrastructure.  

The following process describes one approach to inflating an AWS account before beginning application development.  Although the steps taken here are only suitable for a single account setup for an individual or small team, the approach (setting up authentication, roles for authorization, monitoring, a simple budget, and basic alerts) generalizes for use with a multi-account [AWS organization](https://aws.amazon.com/organizations/).


## The Plan

Here's what we're going to do

* login as the account's `root` user, and setup an IAM `bootstrap` user with `admin` privileges, so we can acquire credentials to run through a suite of account-bootstrap scripts.

* run an `accountBootstrap` script to setup some basic infrastructure for deploying [cloudformation stacks](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html).
* deploy a series of cloudformation stacks
    - IAM groups and roles for:
        * administrators - with write access to IAM and cloudtrail as well as operator permissions
        * operators - with write access to whatever services you want available for use in the account, except only read access to cloudtrail and IAM
        * developers - with access required to develop, test, deploy, and monitor applications that use infrastructure put into place by administrators and operators
    - an [SNS topic](https://docs.aws.amazon.com/sns/latest/dg/welcome.html) for publishing alert notifications
    - a [cloudtrail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html) that logs updates to your account
    - a set of [cloudwatch alarms]() that publish notifications to administrators (via the SNS topic described above) when various events occur:
        * IAM policy changes
        * root account access
        * budget limit exceeded
        * [guard duty](https://aws.amazon.com/guardduty/) event
* finally - setup an initial `administrator` account using the new infrastructure, and delete the temporary `bootstrap` user


## Setup an AWS bootstrap user

Login to the root account, and do the following:

* enable MFA on the root account
* setup a `bootstrap` IAM user with MFA enabled and admin privileges:

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

* download the access key pair for the new account, and setup `~/.aws/credentials` and `~/.aws/config` - ex:

```
[profile bootstrap-ohio]
region = us-east-2
output = json
mfa_serial = arn:aws:iam::123456789:mfa/bootstrap
```

* enable the billing API https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_billing.html?icmpid=docs_iam_console#tutorial-billing-step1

* enable the [security hub](https://aws.amazon.com/security-hub/)

## Install software tools

These instructions assume your command shell has access to the following tools: [bash](https://www.gnu.org/software/bash/), the [jq](https://stedolan.github.io/jq/) json tool, [git](https://git-scm.com/), and the [aws cli](https://aws.amazon.com/cli/).

* download the cloudformation templates and helper scripts from our [git repository](https://github.com/frickjack/misc-stuff):
```
git clone https://github.com/frickjack/misc-stuff.git
```
* add the `arun` tool to your command path
```
# assuming you're running a bash shell or similar
alias arun="bash $(pwd)/misc-stuff/AWS/bin/arun.sh"
export LITTLE_HOME="$(pwd)/misc-stuff/AWS"
```

* run the bootstrap script - it does the following:
    - deploys a block on s3 public access
    - creates an s3 bucket for cloudformation templates
    - sets a password policy for IAM users

ex:
```
export AWS_PROFILE="bootstrap-ohio"
arun accountBootstrap
```

* finally - prepare the inputs to our cloudformation stacks.
    - make a copy of the account-specific stack-parameters:
    ```
    cp AWS/misc-stuff/db/frickjack AWS/misc-stuff/db/YOUR-ACCOUNT
    ```
    - make whatever changes are appropriate for your account.  For example - change the 
    SNS notify e-mail in [AWS/db/cloudformation/YourAccount/accountSetup/snsNotify.json](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/db/cloudformaton/frickjack/accountSetup/snsNotify.json#L7)
    - customize the cloudformation templates under `misc-stuff/AWS/lib/cloudformation/` for your account.  For example - the `IamSetup.json` template sets up an IAM policy that allows access to `S3` and `lambda` and `APIGateway` API's, because I'm interested in those serverless technologies, but you may want to add permissions for accessing the `EC2` and `VPC` API's.


## What's the idea?

Before we start deploying stacks let's talk about the ideas we're implementing.

### Authentication

#### The Right Way to Authenticate

First, authentication - how should a user prove who he is?  AWS IAM has primitives for setting up users and groups, but that's not your best option for establishing a user's identity, because it's one more thing you need to maintain.  

Instead of administering identity with users and groups in IAM under an AWS account - it's better to setup [federated](https://aws.amazon.com/identity/federation/) authentication 
[with Google Apps](https://aws.amazon.com/blogs/security/how-to-set-up-federated-single-sign-on-to-aws-using-google-apps/)
or [Office365](https://jvzoggel.com/2015/10/16/cloud-integration-using-federation-between-microsoft-office-365-azure-active-directory-aad-and-amazon-web-service-aws/)
or some other identity provider that you already maintain
with multi-factor auth and a password policy and all that other good stuff.
If you don't already have an identity provider, then AWS has its own
service, [AWS SSO](https://aws.amazon.com/single-sign-on/)

While you're at it - you might [setup an organization](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_org.html), 
because whatever you're doing it
is bound to be wildly successful, and you'll wind up setting up multiple accounts for
your galloping unicorn, and an organization helps simplify that administration.

#### Not the Right Way to Authenticate

If you don't already have an SSO identity provider, and you don't have someone to do it for you, 
then setting up an SSO and AWS federation
and an AWS organization may seem like a lot of work just to manage a small team's access
to AWS API's.  So let's not do things the right way, but let's not be completely wrong either.
We can emulate the right way.

* require MFA for user authentication 
* enforce a password length and rotation policy 
* require rotation of user access keys 
* associate each user with at least one group 
* associate each group with an IAM role, so that a group member gains access to AWS API's by
acquiring a temporary credentials via a multifactor-signed call to [sts](https://docs.aws.amazon.com/STS/latest/APIReference/Welcome.html)

This authentication setup ensures that access to AWS API's comes either
from AWS managed temporary credentials passed directly to AWS resources like EC2 or
labmda via something like the [AWS metadata service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html), or a user must pass mutlifactor authentication to 
acquire a temporary token directly.  Hopefully this authentication setup will protect our account from being compromised due to an exposed secret.


### Authorization

Now that we have a mechanism to securely authenticate users and services that want to access AWS API's, how should we decide which privileges to grant different users?  Our [iamSetup](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/iamSetup.json) cloudformation stack sets up three groups of users each
associated with its own IAM role:
* administrator
* operator
* developer

We restrict write permission to IAM policies to
the administrators that are trained to enforce least privilege access.
We want to restrict which users can disable cloudtrail, because there's
no reason to do that.  

The administrator group also shared permissions to create other AWS
resources (whatever we want to allow in our account) with the group of operators.
I'm not sure if it makes sense to have both an administrator group and an operator group -
but one scenario might be that an administrator can setup IAM policies conditional on resource tags
for a particular application or whatever, and an operator (maybe a `devops` specialist on a team) can then create and delete resources with the appropriate tags.

The developer group cannot create new resources directly, but they
do have permissions to deploy new versions of an application (udpate a lambda, or change the backend on an api gateway, or upgrade an EC2 AMI, or modify S3 objects - that kind of thing).

Finally - each application service has its own IAM role attached to its ECS container or EC2 instances or lambda or whatever.
The administrator, operator, and developer roles should only be available to human users; each application's role grants the minimum privilege that service requires.

### Tagging

A consistent tagging strategy allows
everyone to easily determine the general purpose of a resource and who is responsible for the resource's allocation and billing.  Something like this works, but there are many ways to do it.


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

### Logs, Metrics, Monitoring, and Alerts

I was slow to understand what's up with `cloudwatch` and `sns`, but
it's not that complicated.  `SNS` is a pub-sub system - a client publishes something to a topic,
and subscribers (lambda functions, e-mail, SQS, queues, ...) immediately receive whatever was published - no queueing or flow control - just a
way to decouple systems.  

`Cloudwatch logs` is a place to save log ("event") streams.
`Cloudwatch events` lets listeners subscribe for notificates of various events from the AWS control plane.  `Cloudwatch metrics` lets applications publish metrics like
load, response time, number of requests, whatever.  `Cloudwatch alarms` fire actions (lambda, SNS publication, ...)
triggered by rules applied to metrics, events, and logs.

For example - our cloudformation stack sets up a [`notifications` topic in SNS](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/snsNotifyTopic.json) that
our `cloudwatch alarms` publish to; and we setup alarms to send notifications
when [changes are made to IAM](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/iamAlarm.json), or when the [`root` account is accessed](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/rootAccountAlarm.json), or when an account [approaches 
its budget limit](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/budgetAlarm.json), or when AWS [guard duty detects something](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/lib/cloudFormation/accountSetup/guardDuty.json) ... that kind of thing.


## Deploy the stacks

Ok - let's do this thing.  As the `bootstrap` user:

* setup IAM groups and roles

```
arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/iamSetup.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/iamSetup.json"
```

Check if the stack came up successfully:
```
arun stack events "$LITTLE_HOME/lib/cloudformation/accountSetup/iamSetup.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/iamSetup.json"
```

If not, then you can delete the stack, fix whatever the problem is, and try again:
```
arun stack delete "$LITTLE_HOME/lib/cloudformation/accountSetup/iamSetup.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/iamSetup.json"
```

Similarly, you can modify a successfully deployed stack later:
```
arun stack update "$LITTLE_HOME/lib/cloudformation/accountSetup/iamSetup.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/iamSetup.json"
```

* setup a real user for yourself

The `iamSetup` stack creates administrator, operator, and developer groups and roles - where members of each group can assume the corresponding role.  Use the AWS web console to create a user (with MFA, etc) for yourself via the console, and add the user to the administrator group.  Download an access key for the new user, and configure your local `~/.aws/config`, so that you can run commands with an administrator token - something like this:

```
[default]
region = us-east-1
output = json
mfa_serial = arn:aws:iam::012345678901:mfa/yourUser

[profile admin-ohio]
region = us-east-2
role_arn = arn:aws:iam::012345678901:role/littleware/account/user/littleAdmin
source_profile = default
mfa_serial = arn:aws:iam::012345678901:mfa/yourUser
```

With these credentials in place, you can run commands like the following.  These tools will prompt you for an MFA code when necessary to acquire a fresh access token:
```
export AWS_PROFILE=admin-ohio
aws s3 ls
arun env | grep AWS_
```

You can now deploy the following stacks as the new administrator user, and delete the bootstrap user.

* setup cloudtrail

Update the cloudtrail parameters ([AWS/db/cloudformation/YourAccount/accountSetup/cloudTrail.json](https://github.com/frickjack/misc-stuff/blob/e458983f39ed100c38ab254ea6d626725f13d796/AWS/db/cloudformaton/frickjack/accountSetup/cloudTrail.json#L10)) with a bucket name unique to your account - something like `cloudtrail-management-$YourAccountName`.  You can retrieve the name of your account with `aws iam list-account-aliases`.

```
arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/cloudTrail.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/cloudTrail.json"
```

* setup an SNS topic

Remember to set the notification e-mail in the parameters before deploying the SNS stack; or customize the template with a subscriber for whatever notification channel (Slack, SMS, ...) you prefer.  You can always add more subscribers to the topic later.

```
arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/snsNotify.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/snsNotify.json"
```

* setup alarms

Update the stack parameter files for the alaram stacks (`AWS/db/YourAccount/accountSetup/*Alarm.json`) to reference the new SNS topic
(`aws sns list-topics`) before deploying the following stacks:

```
arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/guardDuty.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/guardDuty.json"

arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/budgetAlarm.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/budgetAlarm.json"

arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/rootAccountAlarm.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/rootAccountAlarm.json"

arun stack create "$LITTLE_HOME/lib/cloudformation/accountSetup/iamAlarm.json" "$LITTLE_HOME/db/cloudformation/YourAccountNameHere/accountSetup/iamAlarm.json"
```

## Summary

We presented a simple way to secure API access in a new AWS account with authentication, authorization, a tagging strategy, a notification topic in SNS, basic cloudtrail logging, guard duty monitoring, and a few alarms.  This simple setup is just a first step for a small team's journey into cloud security.  A more sophisticated deployment would leverage AWS organizations and SSO.  A larger organization may setup [configuration rules](https://aws.amazon.com/config/), administrative accounts for centralized logging and alerts, and the journey goes on and on (we haven't even deployed an application yet).
