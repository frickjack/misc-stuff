# TL;DR

Helper for rendering markdown to html - to simplify publishing my bLog.

## Use

The `little markdown` command just calls through to the [marked](https://marked.js.org/#/README.md#README.md) markdown renderer.

Ex:
```
$ echo '# hello' | little markdown
<h1 id="hello">hello</h1>
```

```
$ little markdown ./README.md 
<h1 id="tldr">TL;DR</h1>
<p>Scratch repository for miscelaneous </p>
```
