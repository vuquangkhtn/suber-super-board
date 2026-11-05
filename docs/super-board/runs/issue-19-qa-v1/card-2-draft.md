# Card 2 draft (walkthrough artifact — shown in-chat after the route confirmation; never filed)

## Problem

The generated release body has no single command, so every release repeats the invocation
by hand.

## Context

- **Where:** the repo root, after tagging a release
	- a. Card 1's generator produces the categorized body
	- b. Nothing wraps it into the one command the user asked for
	- c. Without the wrapper each release needs the raw script invocation

## Fix

A `/release-notes` command that runs the card-1 generator and prints the draft body ready to
paste into the GitHub Release page.

## Acceptance Criteria

- [ ] The command prints the generated body to stdout with no flags needed after a tag
- [ ] With no tag found it prints a clear error, not a partial body

## Risk

🟢 **Low** · thin wrapper over the card-1 output; no new surface.

## Blocked by

- #9001 — needs the generator's body format (walkthrough fake id; card 1 was never filed).
