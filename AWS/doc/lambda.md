# TL;DR

gitops aware heper for interacting with AWS lambda

## Use

### drun

Launch the `node12.x` lambda runtime [docker image](https://github.com/lambci/docker-lambda) in the current directory, and run the specified handler with the given event.

Ex:
```
$ little lambda drun lambda.lambdaHandler '{ "eventName": "hello" }'
```

Note: this command requires a `./package.json` file to exist.

### bundle [folderPath=.]

Package the contents of the given directory into a `bundle.zip` file under the folder.
This command erases an existing `bundle.zip`.

```
$ little lambda bundle ./code/
```

Note: this command requires a `./package.json` file to exist.

### s3_folder [folderPath=.]

Get the S3 folder (key prefix) to which `lambda upload` will post the bundle for the given code folder.

```
little s3_path ./code/
```

Note: this command requires a `./package.json` file to exist.

### upload

* identify the working directory's git branch and package name
* bundle the current directory (see [above](###bundle))
* upload the `bundle.zip` to the
region's cloudformation bucket with key `lambda/dev/${packageName}/${gitBranch}/bundle.zip`

```
$ little lambda upload
```

Note: this command requires a `./package.json` file to exist.

### update

[Upload](###upload) the current folder, and create a new lambda layer version for layer `${packageName}-${branchName}`, and delete previous versions.

