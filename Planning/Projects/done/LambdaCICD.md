# TL;DR

Modify `little stacks` to create change sets

## Acceptance Tests

* by default `little stacks create|update` deletes existing change sets, creates a new change set, and prompts to execute or delete that change set
* `little stacks create|update --execute` executes then deletes the change set without prompting

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


