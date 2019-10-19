# TL;DR

Helper for rendering markdown to html - to simplify publishing my bLog.

## Use

The `arun markdown` command just calls through to the [marked](https://marked.js.org/#/README.md#README.md) markdown renderer.

Ex:
```
$ echo '# hello' | arun markdown
<h1 id="hello">hello</h1>
```

```
$ arun markdown ./README.md 
<h1 id="tldr">TL;DR</h1>
<p>Scratch repository for miscelaneous </p>
```
