# TL;DR

Cloudformation template deploys a stack with resources for
a generic application:

* cognito identity provider - `auth.domain`
* Cloudfront distribution with S3 bucket for webapp files - `apps.domain`
* API gateway configured as an OAUTH client with cognito - `api.domain`

## Overview

Note: the iamSetup account-level stack deploys an [ApiGatewayAccount](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-account.html) resource to give `apigateway` access to `cloudwatch logs`.  You'll need to create that resource yourself or add it to this template if you do not deploy the iamSetups stack.

 First deployed api gets an endpoint of form: https://{api-id}.execute-api.{region}.amazonaws.com


## Resources

* https://gist.github.com/singledigit/2c4d7232fa96d9e98a3de89cf6ebe7a5
* https://raw.githubusercontent.com/mbradburn/cognito-sample/master/template.yaml
* https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-authorizer.html
* https://blog.jayway.com/2016/08/17/introduction-to-cloudformation-for-api-gateway/
* https://blog.jayway.com/2016/09/18/introduction-swagger-cloudformation-api-gateway/