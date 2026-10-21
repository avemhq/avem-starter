# 03 Build: what happened, in order

> Fictitious client, real runs. Every review and the customer reply below
> are unedited outputs of Claude Code 2.1.304 from 20.10.2026 (only local
> file paths removed). The code is in [project/](project/).

## 1. Rules before code

Mara's page ([expertise/reminder-rules.md](expertise/reminder-rules.md))
became the agent's rule
([project/.claude/rules/reminders.md](project/.claude/rules/reminders.md)),
which Claude loads whenever it touches the reminder code. Every rule got a
test, including the day boundaries 9/10, 19/20 and 34/35.

## 2. First version

`overdue.py` reads the export, decides per invoice, writes `report.md` and
one German draft per reminder, and sends nothing. 9 tests passed.

## 3. Review 1: «ready after fixes»

[review-1.md](03-build/review-1.md). The reviewer runs in its own subagent
without a shell and without the conversation that wrote the code. Its most
important finding (high): a draft from last week stays in the output folder.
If that customer has since opened a complaint, Mara might send a reminder the
rules forbid. Further findings: unreadable input crashed with a traceback,
an invoice number could write outside the folder, unclear cases got a
decision instead of going to a person, and several checks had no test.

## 4. Fixes, then review 2: «ready after fixes»

Every run now writes into its own dated folder and refuses an existing one;
a test runs twice and changes a customer to «complaint» in between. Bad
input stops with a readable message; unclear cases go to a person. 17 tests.

[review-2.md](03-build/review-2.md) found what was left, among them two
things only Mara can decide: should a small invoice with a complaint go to a
person instead of waiting, and does she agree with the two rules the tool
added for unclear cases? Those went to her page as open questions, not into
the code. The rest was fixed; 20 tests.

## 5. Sample run

[sample-output/report.md](03-build/sample-output/report.md) and
[two drafts](03-build/sample-output/drafts/), from the invented export in
[project/data/invoices.csv](project/data/invoices.csv) on 19.10.2026:
three cases for a person (35 days, payment plan, open complaint), one second
reminder, one first reminder, one small invoice on hold, one not yet due.

## 6. A customer answers

[draft-reply.md](03-build/draft-reply.md): the customer says they never got
the invoice. The drafting skill writes the reply with its analysis block,
leaves out any claim about a first reminder nobody recorded, and hands two
things back to Mara: the new payment date, and the escalation the tool
would trigger on 29.10. for an invoice she just resent.

## Still open

- Mara's three questions on her rules page.
- Review 2 finding 6: a run that fails halfway leaves a half-written folder,
  which the next run refuses. Visible, not silent; fix planned.
- Acceptance criterion 3 (same decisions as Mara's last manual Monday) needs
  her real list.
