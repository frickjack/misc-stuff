# TL;DR

helper for publishing web content to an s3 bucket

## Use

### publish

```
little s3web publish localFolder s3Path [--dryrun]
```

* Given a local source folder with html and other content
* when `little s3web publish localFolder s3://destiation`
* html files are gzipped, and annotated with headers content-encoding gzip, mime-type, cache for one hour - ex: `gzip -c file.txt | aws s3 cp - s3://my_bucket/file.txt.gz`
* css, js, svg, map, json, md files are gzipped, and annotated with content-encoding, mime-type, and cache for 1000 hours
* png, jpg, wepb files are not gzipped, and annotated with mime-type and cache for 1000 hours

Ex:
```
$ little s3web publish ./dist/ s3://web-bucket/
```
