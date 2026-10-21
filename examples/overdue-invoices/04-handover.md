# 04 Hand-over

> Fictitious example. What the team receives at the end of the project.

## For Mara: the Monday routine (training sheet)

1. Export the open items from the accounting software as CSV, as before.
2. Run: `python3 overdue.py --csv <export.csv> --today <monday> --out <folder>`
3. Open `<folder>/<monday>/report.md`. Top of the list: cases for a person.
4. Read each draft in `drafts/`, adjust, send from your own mailbox.
5. If the tool says the folder already exists: you ran it twice the same
   day. Move or delete the old folder, then run again.

Nothing is sent by the tool. Nothing in the export is changed.

## Changing a rule

1. Write the change on your page (`expertise/reminder-rules.md`) in your
   words.
2. Whoever maintains the tool turns it into the rule file, a test, then the
   code, and runs the review before the change is used.

## Documentation

- [01-task.md](01-task.md): the task as you described it
- [02-assessment.md](02-assessment.md): what the tool does and does not do,
  acceptance criteria
- [03-build.md](03-build.md): how it was built and reviewed
- [project/CLAUDE.md](project/CLAUDE.md): the working rules for Claude in
  this project

## Undo

Delete the `project/` folder. The tool writes only into the output folder
you name; there is nothing else to remove, no account, no connection.

## After four weeks

Compare: time spent on Mondays, reminders sent, reminders that should not
have gone out. That number decides whether the rules need a change.
