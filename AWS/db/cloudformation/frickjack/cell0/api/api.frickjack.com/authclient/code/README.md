# TL;DR

[Lambda deployment package](https://docs.aws.amazon.com/lambda/latest/dg/nodejs-create-deployment-pkg.html) for `cellSetup/` stacks.


## Cloudformation Integration

Use the `little` helper to upload new code to S3:
```
little lambda upload ./code/
```

Set the `LambdaBucket` and `LambdaKey` parameters in `stackParams.json` to update the lambda.
