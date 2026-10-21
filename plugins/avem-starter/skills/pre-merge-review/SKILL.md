---
name: pre-merge-review
description: Cold review of the current branch against main before a push or merge. Checks that every claim in the commits is backed by the diff, that tests ran on this exact state, that guards were tested against a known violation, and that no secret is in the diff. Use before "push", "merge", "ready for review", or when asked to review a branch.
allowed-tools: Bash(git status *) Bash(git log *) Bash(git diff *)
context: fork
agent: reviewer
background: false
---

# Pre-merge review

Review the change as if someone else wrote it. The goal is a short list of
real findings, each with evidence, and a clear verdict.

This skill runs in the `reviewer` subagent (`context: fork`): a fresh context
without the conversation that wrote the code, with Read, Grep and Glob only.
The reviewer has no shell, so Claude Code collects the git data below before
the review starts and hands it over as text. The base branch is `main`; for
another base, change it in the four commands below.

## The change

Branch and working tree:
!`git status --short --branch`

Commits on this branch, with their full messages (test output the author put
there counts as a claim to check, not as proof):
!`git log --format='%h %s%n%n%b' main..HEAD`

Files changed:
!`git diff --stat main...HEAD`

Full diff (if it is long, Claude Code hands over a file path instead; read
that file with the Read tool):

```!
git diff main...HEAD
```

## 1. List the claims

Read the commit messages above and the PR text, if the task contains one.
List every claim they make ("fixes X", "adds tests for Y", "no behaviour
change").

## 2. Check each claim against the diff

For every claim, find the lines that make it true. A claim without lines is
a finding. "CI is green" proves that some state was green, not that this
change is in it: check which commit the test run used.

## 3. Checklist

Go through each point. Write "ok", "finding" or "not applicable", with the
file and line for each finding.

1. **Tests ran on this exact state.** Which command, which commit, what output?
   If that is not in the task, say "not checked".
2. **Error paths.** What happens on a timeout, an empty result, a 401, a 403,
   a 429, a partial write? Is the failure visible, or does it look like success?
3. **Read-back.** Where the code writes something (database, file, external
   API), does it confirm the result before reporting success?
4. **Guards and validations.** Every new check has a test that makes it fire
   and a test that makes it pass. A check that was never seen failing is
   unproven.
5. **Secrets and personal data.** Look in the diff for keys, tokens,
   passwords, email addresses, phone numbers and real customer names. Name
   the file, line and kind of value, never the value itself.
6. **Docs and comments.** Every sentence that says "the script does X" is
   true in the code of this diff, or marked as planned.
7. **Scope.** Changes outside the stated purpose are named, not hidden.
8. **Reversibility.** Migrations, deletions and config changes have a way back.

## 4. Report

```
Verdict: ready | ready after fixes | not ready
Findings (most severe first):
1. [high|medium|low] file:line: what is wrong, how it fails, suggested fix
Claims checked: N, unsupported: M
Not checked: what you could not verify and why
```

Do not fix anything in this skill. Report first; the author decides.
