# TL;DR

How do we think about authz.

## Overview

### Mental Model

Projects, subjects, actions, resources, conditions, policies, API's, SLO's, clusters, cells.

* A *cluster* is an isolated compute environment in a particular region of a cloud platform - ex: `aws-us-east1-cluster1`
* A *project* is where API producers meet API consumers mediated by security policy, metering, service level monitoring, and rate limiting. A project is associated with a particular cluster at creation time.
* Authorization is deny by default.
* An IAM policy grants one or more subject permission to perform one or more actions on a set of resources subject to a set of conditions.
* An IAM policy may include attribute variables to augment its set of subjects, resources, actions, or conditions.
* Example IAM consumer-policy skeleton:
```
{
    "subjects": [],
    "resources": [],
    "actions": [],
    "conditions": []
}
```
* An API producer registers its own policy
```
{
    "apiScopeName": "demoAPI",
    "actions": [
        {
            "id": "s3:GetObject",
            "quotas": [
                {
                    "type": "userRate",
                    "value": "2",
                    "unit": "reqs/sec"
                },
                ...
            ],
            "scopes" [
                "fullAccess",
                "readOnlyAccess"
            ]
        }
    ]
}
```

* An OIDC client is a tool that may acquire tokens and act on behalf of a user that approves the client.  The actions a client may perform on behalf of a user are constrained by the OAUTH scopes granted to that client.

### UX

* little iam create-project
* little iam create-policy
* little iam attach-policy
* little iam add-user
* little iam check-access

### Infrastructure

Each cluster runs on its own infrastructure independent of other clusters.
A cluster is a multi-tenant environment - it hosts projects from multiple plateform-level user accounts.
Each project in turn supports its own groups of application level users.

### Asynchronous Control Flow

Each project exports a simple asynchronous message API where a client can `push` commands to a ledger, and `dequeue` responses from the project's services.

### Tenant Isolation and Cache Performance

There are several conflicting demands placed upon the system.
* we would like to overprovision our infrastructure, so that we are running enough compute to handle active projects, and not running compute for inactive projects
* we would like to have data for active projects cached close to the compute that uses it, and let data for cold projects fall out of cache

### Control Flow - little agents

The gateway exports a single API method, `pushRequest`:

* invokes the cluster dispatcher lambda that wraps the command in an envelope, and adds it to the project's request ledger (see ledger api below) if it passes the following filters
    - authentication
    - basic command validation
    - global quota check - project and user rate limits, body size, etc
* the requests in a project's request ledger are processed by the project authorizer.  The authorizer pushes the request to a command ledger (see ledger api below) if it passes the following filters:
    - quota check
    - authorization check

A project's request ledger is only writable by the cluster dispatcher, and only readable by the project authorizer.

### Cluster Manager Agent

Communication with a project's agents (via the project ledgers) is mediated by the cluster manager agent.  When the cluster manager receives a session-initialization request from a client, then the cluster spins
up the ledger agent for the session's project on
a shard with capacity to service the project's request-throughtput SLO.  A particular cluster shard is in turn partitioned between a single writer responsible for managing data write requests, and one or more readers that handle read requests with whatever consistency requirements the deployed agent supports. 

* `startSession projectId -> (shardInfo, sessionId)`

### Ledger Agent API

The ledger API accepts the following commands.  Each record in a ledger is given a timestamp that is greater than or equal to every preceding record in the ledger.

* `pushRecords recordList -> (timestamp)`
* `fetchRecords startToken pageSize filter -> (envelopeList, nextToken)`
* `fetchHistogram timeWindow bucketSize filter -> (bucketList, summaryStats)` - for quota checks

The cluster manager associates ledger session is associated with a cluster shard server that manages all sessions for a particular project.

Each record pushed to a ledger is appended to a size and time rotated [avro](https://avro.apache.org/) journal.
The avro journals are periodically bundled into a [parquet](https://parquet.apache.org/) file that is saved to an [S3](https://aws.amazon.com/s3/) data lake.  Analytics pulled from the parquet data lake form the basis of reports and invoices for clients and partners.
A client and partner may request access to 
the portions of the S3 data lake holding parquet files 
relevant to them.

### Project Manager Agent

Bootstrap project.

* `createProject projectName projectType billingProjectId -> (projectId)`
* `setProjectState projectId projectState -> ()` - suspend or activate a project

### IAM Agent

Group membership is established by the identity provider, and included in the credential claims of the identity token.

* `addMembers memberList -> (addedMemberList, alreadyMemberList, failedList)`
* `removeMembers memberList -> (removedMemberList, notMemberList, failedList)`
* `attachPolicies policyList memberList -> (attachedPoliciesList, alreadyAttachedList, failedList)`
* `createPolicy ...`
* `updatePolicy ...`
* `deletePolicy ...`
* `checkAccess claimSet action resourcePath -> (boolean)`
