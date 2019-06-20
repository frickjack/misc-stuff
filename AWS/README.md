# TL;DR

Helpers for interacting with AWS.

## Catalog

### Account Bootstrap

Root user

* enable root account MFA
* enable billing alerts
* `temp-admin` user group and `temp-admin` IAM user with MFA

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

Assume role in web console ...

* Authz - IAM setup

```
arun stack create lib/cloudFormation/accountSetup/iamSetup.json db/cloudformaton/frickjack/accountSetup/iamSetup.json
```

* Notification - SNS setup

```
 arun stack events lib/cloudFormation/accountSetup/snsNotifyTopic.json db/cloudformaton/frickjack/accountSetup/snsNotify.json
 ```

* Alarms
    - budget alarm
    ```
  arun stack create AWS/lib/cloudFormation/accountSetup/budgetAlarm.json AWS/db/cloudformaton/frickjack/accountSetup/budgetAlarm.json
    ```  
    - root account activity alarm
    ```
arun stack create AWS/lib/cloudFormation/accountSetup/rootAccountAlarm.json AWS/db/cloudformaton/frickjack/accountSetup/rootAccountAlarm.json
     ```

# Resources

* https://asecure.cloud/