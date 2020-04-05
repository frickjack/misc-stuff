# TL;DR

CICD is awesome.  It automates the tasks we want to perform whenever we push code to our repository:

* test linting
* audit third party dependencies for security
* compile the code
* run unit tests
* publish artifacts

There are a lot of great options for implementing CICD too.  On-prem systems like [Jenkins](https://jenkins.io) and [Team City](https://www.jetbrains.com/teamcity/), and SAAS systems like [Travis](https://travis-ci.com/), [CircleCI](https://circleci.com/), and [Github Actions](https://github.com/features/actions).  For my personal projects I wanted a SAAS solution that triggers on github PR's and integrates with AWS, so I setup a [CodeBuild](https://aws.amazon.com/codebuild/) process that I'm pretty happy with.


## Codebuild Setup

Setting up codebuild is straight forward if you're comfortable with cloudformation.

* save credentials
* setup IAM roles for codebuild
* setup a build for each github repository
* add a build conifiguration to each github repository

### save credentials

Codebuild can access credentials in AWS secrets manager for interacting with non-AWS systems like github and npm.org.
The [misc-stuff](https://github.com/frickjack/misc-stuff) github repo has helpers for common operations tasks like managing secrets.

```
git clone https://github.com/frickjack/misc-stuff.git
export LITTLE_HOME="$(pwd)/misc-stuff"
alias little="bash '$(pwd)/misc-stuff/AWS/little.sh'"

little help secret
little secret create the/secret/key "$(cat secretValue.json)"
```

### codebuild IAM setup

Codebuild needs IAM credentials to allocate build resources.  [This](https://github.com/frickjack/misc-stuff/blob/master/AWS/lib/cloudformation/cicd/cicdIam.json) cloudformation template sets up a standard role that we'll pass to our builds:

```
{
    "AWSTemplateFormatVersion": "2010-09-09",
    "Parameters": {
      "GithubToken": {
        "Type": "String",
        "Description": "arn of secretsmanager secret for access token",
        "ConstraintDescription": "secret arn",
        "AllowedPattern": "arn:.+"
      }
    },
    "Resources": {
      "CodeBuildRole": {
        "Type": "AWS::IAM::Role",
        "Properties": {
          "RoleName" : "littleCodeBuild",
          "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [{
              "Effect": "Allow",
              "Principal": { "Service": ["codebuild.amazonaws.com"] },
              "Action": ["sts:AssumeRole"]
            }]
          },
          "Policies": [{
            "PolicyName": "CodebuildPolicy",
            "PolicyDocument": {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Sid": "CloudWatchLogsPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "CodeCommitPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "codecommit:GitPull"
                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "S3Policy",
                  "Effect": "Allow",
                  "Action": [
                    "s3:GetObject",
                    "s3:GetObjectVersion",
                    "s3:PutObject",
                    "s3:GetBucketAcl",
                    "s3:GetBucketLocation"
                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "SsmPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "ssm:GetParameters",
                    "secretsmanager:Get*"
                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "ECRPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage",
                    "ecr:GetAuthorizationToken"

                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "CFPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "cloudformation:ValidateTemplate"
                  ],
                  "Resource": [
                    "*"
                  ]
                },
                {
                  "Sid": "LambdaLayerPolicy",
                  "Effect": "Allow",
                  "Action": [
                    "lambda:PublishLayerVersion",
                    "lambda:Get*",
                    "lambda:List*",
                    "lambda:DeleteLayerVersion",
                    "iam:List*"
                  ],
                  "Resource": [
                    "*"
                  ]
                }
              ]
            }
          }
        ]}
      },
      "GithubCreds": {
        "Type" : "AWS::CodeBuild::SourceCredential",
        "Properties" : {
            "AuthType" : "PERSONAL_ACCESS_TOKEN",
            "ServerType" : "GITHUB",
            "Token": { "Fn::Join" : [ "", [ "{{resolve:secretsmanager:", { "Ref": "GithubToken" }, ":SecretString:token}}" ]] }
          }
      }
    },

    "Outputs": {
    }
}
```

We can use the `little` tool mentioned earlier to deploy the stack:

```
little stack create "$LITTLE_HOME/AWS/db/cloudformation/YourAccount/cell0/cicd/cicdIam/stackParams.json"
```

### register a new build

[This](https://github.com/frickjack/misc-stuff/blob/master/AWS/lib/cloudformation/cicd/nodeBuild.json) cloudformation template registers a new build that runs for pull requests and tag events on a github repository. 
In addition to the primary repo the build also pulls in a secondary support repository that hosts our automation scripts.

```
{
    "AWSTemplateFormatVersion": "2010-09-09",
    "Parameters": {
      "ProjectName": {
        "Type": "String",
        "Description": "name of the build project - also tag",
        "ConstraintDescription": "should usually be the domain of the github repository"
      },
      "ServiceRole": {
        "Type": "String",
        "Description": "arn of IAM role for codebuild to assume",
        "ConstraintDescription": "IAM role arn",
        "AllowedPattern": "arn:.+"
      },
      "GithubRepo": {
        "Type": "String",
        "Description": "url of github source repo",
        "ConstraintDescription": "https://github.com/ repo url",
        "AllowedPattern": "https://github.com/.+"
      },
      "SupportRepo": {
        "Type": "String",
        "Description": "url of github secondary repo - default https://github.com/frickjack/misc-stuff.git",
        "Default": "https://github.com/frickjack/misc-stuff.git",
        "ConstraintDescription": "https://github.com/ repo url",
        "AllowedPattern": "https://github.com/.+"
      }
    },
    
    "Resources": {
        "CodeBuild": {
            "Type" : "AWS::CodeBuild::Project",
            "Properties" : {
                "Artifacts" : {
                  "Type": "NO_ARTIFACTS"
                },
                "BadgeEnabled" : true,
                "Description" : "build and test little-elements typescript project",
                "Environment" : {
                  "ComputeType" : "BUILD_GENERAL1_SMALL",
                  "EnvironmentVariables" : [ 
                    {
                      "Name" : "LITTLE_EXAMPLE",
                      "Type" : "PLAINTEXT",
                      "Value" : "ignore"
                    }
                   ],
                  "Image" : "aws/codebuild/standard:2.0",
                  "Type" : "LINUX_CONTAINER"
                },
                "Name" : { "Ref": "ProjectName" },
                "QueuedTimeoutInMinutes" : 30,
                "SecondaryArtifacts" : [],
                "ServiceRole" : { "Ref": "ServiceRole" },
                "Source" : {
                  "Type": "GITHUB",
                  "Location": { "Ref" : "GithubRepo" },
                  "GitCloneDepth": 2,
                  "ReportBuildStatus": true
                },
                "SecondarySources": [
                  {
                    "Type": "GITHUB",
                    "Location": { "Ref" : "SupportRepo" },
                    "GitCloneDepth": 1,
                    "SourceIdentifier": "HELPERS"
                  }
                ],
                "Tags": [
                    {
                        "Key": "org",
                        "Value": "applications"
                    },
                    {
                        "Key": "project",
                        "Value": { "Ref": "ProjectName" }
                    },
                    {
                        "Key": "stack",
                        "Value": "cell0"
                    },
                    {
                        "Key": "stage",
                        "Value": "dev"
                    },
                    {
                      "Key": "role",
                      "Value": "codebuild"
                    }
                ],
                "TimeoutInMinutes" : 10,
                "Triggers" : {
                  "FilterGroups" : [ 
                    [
                      {
                        "ExcludeMatchedPattern" : false,
                        "Pattern" : "PULL_REQUEST_CREATED, PULL_REQUEST_UPDATED, PULL_REQUEST_REOPENED, PULL_REQUEST_MERGED",
                        "Type" : "EVENT"
                      }
                    ],
                    [
                        {
                          "ExcludeMatchedPattern" : false,
                          "Pattern" : "PUSH",
                          "Type" : "EVENT"
                        },
                        {
                          "ExcludeMatchedPattern" : false,
                          "Pattern" : "^refs/tags/.*",
                          "Type" : "HEAD_REF"
                        }
                    ]
                   ],
                  "Webhook" : true
                }
            }
        }
    },

    "Outputs": {
    }
}
```

We can use the `little` tool mentioned earlier to deploy the stack:

```
little stack create "$LITTLE_HOME/AWS/db/cloudformation/YourAccount/cell0/cicd/nodeBuild/little-elements/stackParams.json"
```

### configure the repository

Codebuild expects a `buildspec.yaml` file in the
code repository to contain the commands for a build.
[This build file](https://github.com/frickjack/little-elements/blob/master/buildspec.yml) runs a [typescript](https://www.typescriptlang.org/) compile, unit tests, dependency security audit, and linting check.  If the build trigger is a tagging event, then the build goes on to publish the build's assets as a lambda layer and https://npm.org package.

```
# see https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-codebuild-devicefarm.html
version: 0.2

env:
  variables:
    LITTLE_INTERACTIVE: "false"
  parameter-store:
    NPM_TOKEN: "/aws/reference/secretsmanager/applications/cicd/cell0/dev/npmjs-token"
phases:
  install:
    runtime-versions:
      nodejs: 10
    commands:
      - echo "Entered the install phase - jq already installed ..."
      #- apt-get update -y
      #- apt-get install -y jq
  pre_build:
    commands:
      - echo "HOME is $HOME, CODEBUILD_SRC_DIR is $CODEBUILD_SRC_DIR, CODEBUILD_SRC_DIR_HELPERS is $CODEBUILD_SRC_DIR_HELPERS, pwd is $(pwd)"
      - echo "//registry.npmjs.org/:_authToken=$(echo "$NPM_TOKEN" | jq -e -r .token)" > "$HOME/.npmrc"
      - mkdir -p "$HOME/.aws"; /bin/echo -e "[default]\nregion = us-east-2\noutput = json\ncredential_source = Ec2InstanceMetadata\n" | tee "$HOME/.aws/config"
      - npm ci
      - pip install yq --upgrade
  build:
    commands:
      - npm run build
      - npm run lint
      - npm audit --audit-level=high
      - npm run test
  post_build:
    commands:
      - echo "CODEBUILD_WEBHOOK_TRIGGER == $CODEBUILD_WEBHOOK_TRIGGER"
      # checkout a branch, so lambda publish goes there
      - git checkout -b "cicd-$CODEBUILD_WEBHOOK_TRIGGER"
      - BUILD_TYPE="$(echo $CODEBUILD_WEBHOOK_TRIGGER | awk -F / '{ print $1 }')"
      - echo "BUILD_TYPE is $BUILD_TYPE"
      # publish lambda layers for pr's and tags
      - if test "$BUILD_TYPE" = pr || test "$BUILD_TYPE" = tag; then bash "$CODEBUILD_SRC_DIR_HELPERS/AWS/little.sh" lambda update "$CODEBUILD_SRC_DIR"; fi
      # publish on tag events - see https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html
      - if test "$BUILD_TYPE" = tag; then npm publish . --tag cicd; fi
```