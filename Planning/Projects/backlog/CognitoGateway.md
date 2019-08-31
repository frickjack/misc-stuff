# TL;DR

Modify `arun stacks` to create change sets

## Acceptance Tests

* by default `arun stacks create|update` deletes existing change sets, creates a new change set, and prompts to execute or delete that change set
* `arun stacks create|update --execute` executes then deletes the change set without prompting

## SLO and SLI

NA

## Notes for Reviewer

Pending

## Sub-tasks

NA

## UX Wireframe

NA

## API design

Modify the behavior of existing `arun` CLI options:
* `arun stack create [--execute]`
* `arun stack update [--execute]`

## Overall effort estimate

1 person days


