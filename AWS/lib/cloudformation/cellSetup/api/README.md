# TL;DR

Cloudformation template deploys a stack with resources for
a generic application:

* cognito identity provider - `auth.domain`
* Cloudfront distribution with S3 bucket for webapp files - `apps.domain`
* API gateway configured as an OAUTH client with cognito - `api.domain`

## API Stack Overview

An API stack consists of one or more API gateways
deployed under different HTTP paths of a DNS domain
managed by a CDN or load balancer.

### API Overview

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

## This Gateway

* `authclient/` - deploys resources for an OIDC client of a Cognito identity provider for authenticating API users, a production domain (ex - api.frickjack.com) and a beta domain (ex - beta-api.frickjack.com)
* `authz/` - TODO - deploys resources for an access management service, and mappings to the production and beta domains created by the `authclient/` stack


## Development process

The `littleware` tools support deploying a stack
that implements the templates in this folder.

### Code change

For a code change to deploy in the beta stage:
 
* update `code/`
* upload the new code package with `little lambda upload`
* update the `LambdaBucket` and `LambdaKey` parameters in the `stackParams.json` to point at the new code package
* `little stack update ./stackParams.json`

### Publish code to prod

* add a new version to the `.Littleware.Variables.lambdaVersions` - this will deploy a new lambda version with the currently deployed lambda code package
* point `.Littleware.Variables.prodLambdaVersion` at the new version
* `little stack update ./stackParams.json`

### Deploy a new version of the API

* edit the `openapi.yaml` to make the api changes
* deploy the new api to the dummy stage: `little stack update ./stackParams.json`
* add a new deployment to the `.Littleware.Variables.gatewayDeployments` array in `stackParams.json`, and point the beta domain stage at it by setting the `.Littleware.Variables.betaDeployment` (the `prodDeployment` variable updates the prod stage)


## Tests

* https://api.frickjack.com/authn/hello


## Notes

Note: the iamSetup account-level stack deploys an [ApiGatewayAccount](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-account.html) resource to give `apigateway` access to `cloudwatch logs`.  You'll need to create that resource yourself or add it to this template if you do not deploy the iamSetups stack.

## Resources

* https://gist.github.com/singledigit/2c4d7232fa96d9e98a3de89cf6ebe7a5
* https://raw.githubusercontent.com/mbradburn/cognito-sample/master/template.yaml
* https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-authorizer.html
* https://blog.jayway.com/2016/08/17/introduction-to-cloudformation-for-api-gateway/
* https://blog.jayway.com/2016/09/18/introduction-swagger-cloudformation-api-gateway/
* https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions-integration-requestParameters.html
* https://stackoverflow.com/questions/36096603/in-aws-api-gateway-how-do-i-include-a-stage-parameter-as-part-of-the-event-vari
* https://stackoverflow.com/questions/36181805/how-to-get-the-name-of-the-stage-in-an-aws-lambda-function-linked-to-api-gateway