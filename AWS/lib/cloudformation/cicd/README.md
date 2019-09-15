# TL;DR

Templates for CICD stacks (codebuild, pipeline, ...)


## Overview

* setup github access token (see https://docs.aws.amazon.com/codebuild/latest/userguide/sample-access-tokens.html).  Save the token in AWS secrets manager as a secret string with form:

```
{ "token": "the-token-value" }
```

## Resources

* https://docs.aws.amazon.com/codebuild/latest/userguide/sample-access-tokens.html
* https://docs.aws.amazon.com/en_pv/codebuild/latest/userguide/sample-github-pull-request.html
* https://aws.amazon.com/blogs/security/how-to-create-and-retrieve-secrets-managed-in-aws-secrets-manager-using-aws-cloudformation-template/

