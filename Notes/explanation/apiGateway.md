# TL;DR

Our application platform begins with this foundation: 
* a [cognito](https://aws.amazon.com/cognito/) [user pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html) that manages client authentication as an [identity provider](https://en.wikipedia.org/wiki/Identity_provider)
* an [api gateway](https://aws.amazon.com/api-gateway/) that mediates client access to our API
* an [S3 bucket]() behind a [cloudformation CDN]() that efficienly serves static assets (fonts, images, javascript, css, html, ...) to clients

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

## Multi-tenant

A cell is a container for tenants

## Gateway configuration

* openapi
* domain mapping and stage name: https://api.frickjack.com/core/v1/hello
