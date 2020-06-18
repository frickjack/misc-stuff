# TL;DR

Cloudformation stack for deploying the [little-authn](https://github.com/frickjack/little-authn) OIDC client to an API gateway domain.


## Cloudformation Integration

### Configuration

The cloudformation template expects the configuration for the `@littleware/little-authn` OIDC variable to be saved as json in an [SSM parameter](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html).
The `little ssm` helper simplifies saving a new parameter, and the [little-authn documentation](https://github.com/frickjack/little-authn/blob/master/Notes/howto/devTest.md#configuration) has details about the expected configuration.

The configuration is passed into the lambda as an environment variable.  The adapter code (in `code/index.js`) has some simple logic for changing the configuration depending on which stage (as detected by the function version) is executing.  If a completely
separate configuration becomes necessary in the furture, then 
the stack template can be generalized to deploy separate lambdas with separate configurations for each stage.

### Update lambda for beta stage

The `./code/` folder has the [lambda deployment package](https://docs.aws.amazon.com/lambda/latest/dg/nodejs-create-deployment-pkg.html)  adapter that integrates the `@littleware/little-authn` node module with AWS lambda and API gateway.  The `beta` stage executes the `$LATEST` lambda code, and the `prod` stage executes the code version referenced by the `gateway_prod` lambda alias.

Use the `little` helper to upload new code to S3:
```
little lambda upload ./code/
```
, then set the `LambdaBucket` and `LambdaKey` parameters in `stackParams.json` to update the lambda.  Use the `little stack update` helper to deploy the changes to the stack.

```
little stack update ./stackParams.json
```

Use `little stack events` to verify that the stack updated successfully.

```
little stack events ./stackParams.json
```

### Publish new version of lambda for prod stage

Add a new version to the `.Littleware.Variables.lambdaVersions` in `stackParams.json`, and set the `.Littleware.Variables.prodLambdaVersion` variable to the version that the prod alias should reference.

### Smoke Test

The `smokeTest.sh` scripts walks through a simple interactive OIDC flow to verify the basic functionality of the beta stage.  Set the `LITTLE_AUTHN_BASE` environment variable to test a different domain.

```
LITTLE_AUTHN_BASE=https://api.frickjack.com/authn bash ./smokeTest.sh
```
