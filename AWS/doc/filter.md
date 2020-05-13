# TL;DR

filter nunjucks templates with variables

## Use

### little filter $variablesInlineOrFile

Filter the nunjucks template read from stdin with 
the given variables.

Ex:
```
$ little filter '{ "eventName": "hello" }' < template.json
```
