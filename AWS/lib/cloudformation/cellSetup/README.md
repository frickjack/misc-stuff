# TL;DR

Cloudformation template deploys a stack with resources for
a generic application:

* cognito identity provider - `auth.domain`
* Cloudfront distribution with S3 bucket for webapp files - `apps.domain`
* API gateway configured as an OAUTH client with cognito - `api.domain`

## Resources

* https://gist.github.com/singledigit/2c4d7232fa96d9e98a3de89cf6ebe7a5
* https://raw.githubusercontent.com/mbradburn/cognito-sample/master/template.yaml
* https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apigateway-authorizer.html