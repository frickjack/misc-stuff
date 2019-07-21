# TL;DR

gitops aware heper for interacting with AWS lambda

## Commands

### drun

Launch the `node10.x` lambda runtime [docker image](https://github.com/lambci/docker-lambda) in the current directory, and run the specified handler with the given event.

Ex:
```
$ arun lambda drun lambda.lambdaHandler '{ "eventName": "hello" }'
```

Note: this command requires a `./package.json` file to exist.

### package

Package the contents of the current directory into a `package.zip` file.
This command will erase an existing `package.zip`.

```
$ arun lambda package
```

Note: this command requires a `./package.json` file to exist.

### upload

* identify the working directory's git branch and package name
* ackage the current directory (see [above](###package))
* upload the `package.zip` to the
region's cloudformation bucket with tag `lambda/dev/${packageName}/${gitBranch}/package.zip`
* create the lambda function `/dev/${packageName}/${gitBranch}` if it does not already exist
* update the lambda functions code

```
$ arun lambda upload
```

Note: this command requires a `./package.json` file to exist.

### cleanup

Delete the S3 object and lambda function associated with the given npm package and git branch.

```
$ arun lambda cleanup ${packageName} ${gitBranch}
```
