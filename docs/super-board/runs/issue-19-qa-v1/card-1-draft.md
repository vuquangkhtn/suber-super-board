# Card 1 draft (walkthrough artifact — shown in-chat after the route confirmation; never filed)

## Problem

Release notes are written by hand on the GitHub Release page, so they are inconsistent and
slow to produce after each tag.

## Context

- **Where:** GitHub Release page, per `v*` tag
	- a. Teammates read the release notes to know what shipped
	- b. Today each note is written by hand from memory
	- c. Input that should feed them (merged PR titles since the last tag) is never used

## Fix

A small generator that collects merged PR titles since the last `v*` tag and drafts a
categorized release body (feature / fix / chore groups, emoji headers) for the Release page.

## Acceptance Criteria

- [ ] Running the generator after a tag produces a body listing every PR merged since the previous `v*` tag
- [ ] The body groups entries by conventional-commit type with one emoji header per group
- [ ] PRs already included in a previous release body are excluded

## Risk

🟢 **Low** · read-only script over git + PR data; nothing ships automatically.

## Blocked by

- None.
