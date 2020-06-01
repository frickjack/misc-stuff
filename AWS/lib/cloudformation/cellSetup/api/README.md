# TL;DR

Cloudformation template deploys a stack with resources for
a generic application:

* cognito identity provider - `auth.domain`
* Cloudfront distribution with S3 bucket for webapp files - `apps.domain`
* API gateway configured as an OAUTH client with cognito - `api.domain`

## Overview

Note: the iamSetup account-level stack deploys an [ApiGatewayAccount](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-account.html) resource to give `apigateway` access to `cloudwatch logs`.  You'll need to create that resource yourself or add it to this template if you do not deploy the iamSetups stack.

 First deployed api gets an endpoint of form: https://{api-id}.execute-api.{region}.amazonaws.com

 ### Gateway Concepts

* a lambda function
* the API itself specified with `openapi.yaml` to proxy the lambda
* a deployment of the API - immutable
* a beta stage that directly references the lamda function
* a prod stage that references a `gateway_prod` lambda alias

 It's a little confusing.  When we update an API, we must 
 create a new deployment, then point a stage at that deployment.

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


## Mapping

* API + lambda -> deployment
* deployment mapped to stage
* different stages for different api versions
* custom domain
* multiple domain mappings 

## Tests

Note - custom domain maps to subpath /core/:

* https://apiclient.frickjack.com/authn/hello

The `sampleStackParams.json` is used by the stack filter test
suite (`little testsuite --filter testStackFilter`), and illustrates how to configure a stack.

## TODO

* CORS
* Cookie domain
* Lambda alias per stage
* Deployment tool

## Resources

* https://gist.github.com/singledigit/2c4d7232fa96d9e98a3de89cf6ebe7a5
* https://raw.githubusercontent.com/mbradburn/cognito-sample/master/template.yaml
* https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-authorizer.html
* https://blog.jayway.com/2016/08/17/introduction-to-cloudformation-for-api-gateway/
* https://blog.jayway.com/2016/09/18/introduction-swagger-cloudformation-api-gateway/
* https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions-integration-requestParameters.html
* https://stackoverflow.com/questions/36096603/in-aws-api-gateway-how-do-i-include-a-stage-parameter-as-part-of-the-event-vari
* https://stackoverflow.com/questions/36181805/how-to-get-the-name-of-the-stage-in-an-aws-lambda-function-linked-to-api-gateway