# TL;DR

The cloudformation templates in this folder define resources for
deploying multiple API's under prod and beta domains.
The API's fit into a larger appliction infrastructure with these components:

* a cognito identity provider - `auth.domain`
* a cloudfront distribution that services static files for webapps from an S3 bucket - `apps.domain`
* API's implemented as lambda functions behind an API gateway - `api.domain`

The templates in this folder manage the infrastructure and deployment for `api.domain`.


## API and Process Overview

This [docmentation](../../../../../Notes/explanation/apiGateway.md) introduces littleware's approach to API gateway.


## Tests

### authclient

The `authclient/smokeTest.sh` runs an interactive test from the underlying `@littleware/little-authn` node module.  The test walks the caller through a simple OIDC flow to verify the basic functionality of an API domain.

```
# Set the `LITTLE_AUTHN_BASE` environment variable to test a different domain.

LITTLE_AUTHN_BASE=https://api.frickjack.com/authn bash ./smokeTest.sh
```


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