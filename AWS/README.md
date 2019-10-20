# TL;DR

Helpers for interacting with AWS.

## Catalog

### Account Bootstrap

In the AWS console, as the root user:

* enable root account MFA
* enable billing alerts
* `temp-admin` user group and `temp-admin` IAM user with MFA

### little profile command

Run a command with AWS credential environment variables set.  Handles caching creds for assumed roles.

ex:
```
alias little='bash AWS/bin/little.sh'
little --profile admin-ohio env
```

### accountBootstrap

Setup a cloudformation bucket in the region for the
active profile, so that the `bootstrap` cloudformation
stack can be deployed.

ex:
```
little accountBootstrap
```

### little stack

* `little stack create`
* `little stack update`
* `little stack events`
* `little stack list`

## Account Hidration

Assume role in web console ...

* Authz - IAM setup

```
little stack create lib/cloudFormation/accountSetup/iamSetup.json db/cloudformaton/frickjack/accountSetup/iamSetup.json
```

* Notification - SNS setup

```
 little stack events lib/cloudFormation/accountSetup/snsNotifyTopic.json db/cloudformaton/frickjack/accountSetup/snsNotify.json
 ```

* Alarms
    - budget alarm
    ```
  little stack create AWS/lib/cloudFormation/accountSetup/budgetAlarm.json AWS/db/cloudformaton/frickjack/accountSetup/budgetAlarm.json
    ```  
    - root account activity alarm
    ```
little stack create AWS/lib/cloudFormation/accountSetup/rootAccountAlarm.json AWS/db/cloudformaton/frickjack/accountSetup/rootAccountAlarm.json
     ```

# Resources

* https://asecure.cloud/