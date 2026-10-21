# Example: overdue invoices, one task from start to hand-over

> Fictitious client, invented data, real runs of Claude Code (20.10.2026).

**For the managing director, in five lines:**

1. Task: three hours every Monday preparing reminders for overdue invoices.
2. The person who does the work wrote down how she decides; the agent's rules
   and tests come from her page.
3. The tool prepares the list and the drafts. People decide and send.
4. Every change was reviewed by a separate agent that cannot edit or run
   anything; its findings and the fixes are in the open.
5. Hand-over with a one-page training sheet and a way to undo it.

**For developers, the trail:**

| Step | File |
|---|---|
| The task, in the client's words | [01-task.md](01-task.md) |
| The expertise: how the client decides | [expertise/reminder-rules.md](expertise/reminder-rules.md) |
| Whether and how much AI takes on, acceptance criteria | [02-assessment.md](02-assessment.md) ([deutsch](02-assessment.de.md)) |
| The project: `CLAUDE.md`, rule, code, tests, sample data | [project/](project/) |
| Build, two reviews, fixes, sample output, a customer reply | [03-build.md](03-build.md) |
| Hand-over, training sheet, undo | [04-handover.md](04-handover.md) ([deutsch](04-handover.de.md)) |

Run it yourself:

```
cd examples/overdue-invoices/project
python3 -m unittest -v
python3 overdue.py --csv data/invoices.csv --today 2026-10-19 --out /tmp/overdue
```
