# TL;DR

A sketch of the infrastructure resources ...

## Overview

Our application platform begins with this foundation: 

* a [cognito](https://aws.amazon.com/cognito/) [user pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html) that manages client authentication as an [identity provider](https://en.wikipedia.org/wiki/Identity_provider)
* an api gateway that implements an OAUTH client that manages authentication and web sessions
* an [api gateway](https://aws.amazon.com/api-gateway/) that mediates client access to our API
* an [S3 bucket]() behind a [cloudformation CDN]() that efficienly serves static assets (fonts, images, javascript, css, html, ...) and webapps to clients

## API Gateway 

An [api gateway](https://aws.amazon.com/api-gateway/) decouples several concerns from the developers and operators of an API.

* edge connection management
    - TLS, HTTP2
    - CDN
    - CORS, CSRF
    - application firewall - injection attacks, circuit breakers - ddos attacks
* autoscaling and failover
* logging and monitoring
* authentication
* authorization
* deployment management - canaries, versioning

Cloud version of an application server - ingress to a service mesh.

* the `@littleware/little-authn` node module that implements a webapp that provides a Cognito OAUTH client, and manages web sessions
* a lambda that configures and deploys the node module
* a lambda alias that references a "production" version of the lambda
* an [api gateway](https://aws.amazon.com/api-gateway/) REST api that associates an [openapi]() specifaction with a lambda via stage variables
* a production [deployment]() to a [gateway stage]() with a stage variable that associates the REST api with the production lambda alias
* a beta deployment to a stage that links the API with the un-versioned lambda
* a production gateway domain with a mapping that links the production stage to one sub-path under the domain
* a beta domain that links to the beta stage


## API Stack Overview

An API stack consists of one or more API gateways
deployed under different HTTP paths of a DNS domain
managed by a CDN or load balancer.

### API

Each littleware API has the following:

* a lambda function
* the API itself specified with `openapi.yaml` to proxy the lambda
* a deployment of the API - immutable
* a beta stage that directly references the lamda function
* a prod stage that references a `gateway_prod` lambda alias

We update the signature of an API by 
creating a new deployment, then pointing a stage at that deployment.

We update the code behind an API by pushing a new code package to the lambda, or publishing a new lambda version, and updating the lambda alias referenced by a gateway stage.

### Domain

AWS gateway infrastructure includes support for automatically
managing a [gateway domain]() with [mappings]() for one or more
API's.  For example, one api, `api1`, might be accessed via
https://my.domain/api1, while `api2` is at https://my.domain/api2.
It's also possible to self-manage multiple api's behind
a [custom cloudfront domain](https://aws.amazon.com/premiumsupport/knowledge-center/api-gateway-cloudfront-distribution/).


### Development process

For a code change:
 
* update `code/`
* update the stack - this deploys the new `code/`
* test the `beta.` stage
* update the `gateway_prod` lambda alias to manage the prod-stage deployment

For api changes:

* update the openapi definition
* update the stack - this updates the rest api, and deploys new code
* publish a new api deployment, and link the new api deployment to the beta stage
* test the `beta.` stage
* the new api deployment to the prod stage


## Dev environment

* aws sam cli [install](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install-linux.html)

## Dev-Test-Deploy process

Issues:

* develop lambda
* api gateway - dev environments, etc
* configuration injection
* test lambda
* publish lambda
* api gateway - API stages, versioning
* CICD - lambda layers, etc
* monitoring

### Ideas:

* lambda == deployment, layer == code - lambda is associated with an API (gateway) or generic handler (ex: slack message), etc

* CICD == test and publish new layers
* gitops/operator == associate layer versions with lambda deployments?

To [SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) or not to SAM?  For local testing ...

Publishing lambda versions ...

Lambda layers ...

Lambda [execution role](https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html) - what the lambda can do

Lambda [resource based policy](https://docs.aws.amazon.com/lambda/latest/dg/access-control-resource-based.html) - allow AWS services to invoke the lambda ...
API Gateway is given invoke permission [directly](https://stackoverflow.com/questions/39905255/how-can-i-grant-permission-to-api-gateway-to-invoke-lambda-functions-through-clo)


Monitoring:
* concurrency
* concurrency alerts
* cloudwatch logs
* X-Ray

## Processes

* new rest api and deployments when openapi changes
* beta and prod deployments
* beta and prod stages
* lambda, version, and `gateway_prod` alias
* prod stage variable references `gateway_prod` alias, beta stage references the lambda

Whatever frickjack.  Cloudformation stack.

* update the lambda to test new code in the beta stage
* create a version, and update the alias to deploy code to the prod stage
* update openapi.yaml to modify the api
* create a new deployment, and assign to the beta and/or prod stage to deploy api changes

### Mismatch between Cloudformation and gateway models.

* code upload
* openapi.yaml integration
* variable substition
* new deployments, lambda versions, publishing

Want declarative infrastructure where the infrastructure declaration is
dynamic based on a constrained configuration.

Our solution - extend cloudformation templates with [nunjucks](https://mozilla.github.io/nunjucks), and introduce our own [little stack](../../doc/stack.md) CLI wrapper.

[AWS CloudFormer](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-using-cloudformer.html).  Rather than have a template and a config - have a template, a config, and a script.

### Deploy new code

bla

### Update the API

bla

## Multi-tenant

A cell is a container for tenants

## Gateway configuration

* openapi
* domain mapping and stage name: https://api.frickjack.com/core/v1/hello
