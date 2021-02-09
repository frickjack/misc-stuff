# TL;DR

Develop `s3web` command for publishing web content to an S3 bucket: `little s3web localFolder s3://destination`

## Acceptance Tests

* `Scenario("publish web folder")`
    - Given a local source folder with html and other content
    - when `little s3web publish localFolder s3://destiation`
    - html files are gzipped, and annotated with headers content-encoding gzip, mime-type, cache for one hour - ex: `gzip -c file.txt | aws s3 cp - s3://my_bucket/file.txt.gz`
    - css, js, svg, map, json, md files are gzipped, and annotated with content-encoding, mime-type, and cache for 30 days
    - png, jpg, wepb files are not gzipped, and annotated with mime-type and cache for 30 days

## SLO and SLI

NA

## Notes for Reviewer

Pending

## Sub-tasks

NA

## UX Wireframe

NA

## API design

Modify the behavior of existing `little` CLI options:
* `little stack create [--execute]`
* `little stack update [--execute]`

## Overall effort estimate

1 person days


