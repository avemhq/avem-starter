# CLAUDE.md (example project: overdue invoices)

Fictitious example: the starter's `CLAUDE.md` filled in for one client
project.

## Project

- What this is: prepares the Monday list of overdue invoices and German
  reminder drafts for Beispiel Services GmbH (fictitious). Never sends.
- Stack: Python 3 standard library only, no network.
- Run: `python3 overdue.py --csv data/invoices.csv --today 2026-10-19 --out out`
- Test: `python3 -m unittest -v`
- Owner who decides scope and releases: head of accounting (Mara).

## How to work here

1. The rules come from `expertise/reminder-rules.md` (Mara's own words). A
   rule changes there first, with her, then in `.claude/rules/reminders.md`,
   then in a test, then in the code.
2. Every rule has a test, including the day boundaries.
3. Measure before you claim: run the tests and show the last line.
4. Run `/pre-merge-review` before asking for a merge.

## Hard rules

- **Never send.** The tool writes text files. Mara sends.
- **No draft for an open complaint or a payment plan**, ever. Those cases go
  on the list for a person.
- **No fees, no legal steps** in any draft.
- **Real customer data stays out of the repository.** `data/invoices.csv` is
  an invented sample; real exports live outside the repo.

## Where things live

- Mara's rules: `../expertise/reminder-rules.md`
- The agent's rule: `.claude/rules/reminders.md`
- Decisions and open questions: `../02-assessment.md`
