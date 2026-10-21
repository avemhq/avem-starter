# 0001: The reviewer has no shell

Status: accepted, October 2026

## Context

The `pre-merge-review` skill runs in a separate subagent so the review is
cold: it never sees the conversation that wrote the code. A reviewer that
can change what it reviews is not a reviewer.

The first version gave the reviewer Bash behind a hook that allowed only
read-only git commands. Three review rounds by a second model each found a
new way around that list: an option that starts a pager program, an option
that reads a file outside the repository, a format string that calls gpg.
Every fix was a longer list, and every list was incomplete.

## Decision

The reviewer gets Read, Grep and Glob only. Bash, Edit, Write and
NotebookEdit are disallowed in its frontmatter. The git data it needs
(status, commits, changed files, the full diff) is collected by the skill
itself with `!` lines before the subagent starts
([skills: inject dynamic context](https://code.claude.com/docs/en/skills#inject-dynamic-context)).

## Consequences

- The whole class of shell bypasses is gone instead of patched.
- The review only sees committed changes on the branch, not uncommitted
  work.
- The base branch is fixed in the skill (`main`); another base means editing
  three lines.
- The selftest compares the reviewer's frontmatter with its exact text, so a
  change to its description needs the same change in `selftest.sh`.
