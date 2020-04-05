# TL;DR

Setup cognito identity provider for applications

## Notes

* the SSL certificate must be in us-east-1 region: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-add-custom-domain.html

* after deploying the stack, you must manually add the DNS alias

## Resources

* Google Idp: https://developers.google.com/identity/protocols/OpenIDConnect
* Cloudformation cognito integration: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cognito-userpoolidentityprovider.html#cfn-cognito-userpoolidentityprovider-attributemapping
