# TL;DR

gitops aware heper for interacting with AWS lambda

## Use

### drun

Launch the `node10.x` lambda runtime [docker image](https://github.com/lambci/docker-lambda) in the current directory, and run the specified handler with the given event.

Ex:
```
$ arun lambda drun lambda.lambdaHandler '{ "eventName": "hello" }'
```

Note: this command requires a `./package.json` file to exist.

### bundle

Package the contents of the current directory into a `bundle.zip` file.
This command will erase an existing `bundle.zip`.

```
$ arun lambda package
```

Note: this command requires a `./package.json` file to exist.

### upload

* identify the working directory's git branch and package name
* bundle the current directory (see [above](###bundle))
* upload the `bundle.zip` to the
region's cloudformation bucket with key `lambda/dev/${packageName}/${gitBranch}/bundle.zip`

```
$ arun lambda upload
```

Note: this command requires a `./package.json` file to exist.

### update

[Upload](###upload) the current folder, and create a new lambda layer version for layer `${packageName}-${branchName}`, and delete previous versions.

