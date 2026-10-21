# Review 1, unedited output of `/pre-merge-review`

> Run on 20.10.2026 with Claude Code 2.1.304 on the branch with commit
> `feat: Monday list and reminder drafts` (see [03-build.md](../03-build.md)).
> Only local file paths were removed. The reviewer had Read, Grep and Glob
> and no shell; the commit list it saw showed subject lines only, which is
> why it marks the test run as "not checked". The skill now passes the full
> commit messages.

Verdict: ready after fixes

The decision logic matches `.claude/rules/reminders.md` and the 9/10, 19/20 and 34/35 day boundaries are tested. One problem can still put a draft in front of Mara for a customer with an open complaint or a payment plan, which breaks a hard rule. There are also several gaps in input handling and in the tests.

**Findings (most severe first):**

1. **[high] overdue.py:131 and 135-136: old drafts survive later runs.** `drafts_dir.mkdir(..., exist_ok=True)` reuses the output folder and never removes old files.
   - How it fails: last week invoice X got a first reminder and `out/drafts/X.txt` was written. This week X has an open complaint or a payment plan, so it is classed `person`, but `X.txt` is still in the folder. `report.md` then tells Mara "Read the drafts in drafts/", so she may send it. The same happens to drafts for invoices that have since been paid.
   - Fix: at the start of `run`, empty the drafts folder or refuse to run if it is not empty. Better still, write each run into a new dated folder. Add a test that runs twice and changes one invoice to complaint in between.

2. **[medium] overdue.py:58, 62, 66-73: some bad input crashes with a raw traceback.** A short CSV row sets the missing fields to `None`, so `.strip()` raises `AttributeError`. `main` (line 161) only catches `OSError` and `ValueError`.
   - The amount `NaN` gets past line 58. The comparison on line 83 then raises `decimal.InvalidOperation`, which is not a `ValueError`, so it also crashes.
   - A malformed CSV raises `csv.Error`, which is not caught either.
   - Fix: check that every required field is present and not empty, reject amounts that are not finite, and catch `csv.Error`. Mara is meant to run this herself (acceptance criterion 5), so she needs a readable error message.

3. **[medium] overdue.py:136: the invoice ID goes straight into a file name.**
   - An ID containing `/` or `..` writes outside `drafts/` or fails.
   - Two rows with the same ID: the second draft silently overwrites the first.
   - Fix: allow only safe characters in the ID, and send duplicate IDs to `person` (or reject them).

4. **[medium] overdue.py:83-95: unclear cases get a decision instead of going to a person.** The rule says "When a case is unclear, it goes to a person", but:
   - An empty `email` still gets a draft that starts `An: ` with no address (line 124).
   - Negative amounts, such as credit notes, are labelled `hold` with the reason "under CHF 50".
   - Fix: send these cases to `person` and add a test for each.

5. **[medium] test_overdue.py: several new checks were never tested firing.**
   - The missing-columns check (overdue.py:52-54).
   - The invalid yes/no check in `parse_bool` (overdue.py:46).
   - The bad `due_date` check (overdue.py:63-64).
   - A bad `--today` and exit code 2 in `main` (overdue.py:159-163).
   - At run level, no draft for a payment plan (acceptance criterion 2). Only the complaint case is checked, in `test_drafts_only_for_reminders_and_input_untouched`.
   - The rule order in two cases: a small amount with a complaint should give `hold`, and paid with a complaint should give `ignore`.
   - Fix: add one failing case and one passing case for each.

6. **[low] test_overdue.py:1: the claim "one or more [tests] per rule" is only partly true.**
   - Draft rules that are not tested: German, formal "Sie", invoice number, amount, due date, the signature, and "pay within 10 days" in the second reminder.
   - The report itself is not tested: that paid invoices are left out, the sort order, and the "Nothing has been sent" line.
   - The list of banned words (test_overdue.py:72) leaves out common terms such as "anwalt", "gericht", "verzug" and "mahnspesen".

7. **[low] overdue.py:119-121: the second reminder says "trotz unserer Erinnerung" ("despite our earlier reminder").** On the first run, or when nobody sent a first reminder, an invoice that is already 20-34 days overdue gets this text, and the claim in it is false. This is a question for Mara, to be recorded in `expertise/reminder-rules.md` before any code change.

8. **[low] overdue.py:117: any decision other than `reminder-1` gets the second-reminder text.** It is only called correctly today. Fix: use `elif decision == "reminder-2"` and raise an error for anything else.

9. **[low] overdue.py:133-148: no read-back, and a failed run leaves half its output behind.** Drafts are written before `report.md`, so a crash part-way leaves drafts with no report or an old one. Nothing checks the written files before `main` prints the counts. Fix: write into a temporary folder and rename it at the end, or at least write the report first.

**Checklist:**

1. Tests ran on this exact state: not checked. No test command, commit or output was handed over.
2. Error paths: finding (2, 9).
3. Read-back: finding (9).
4. Guards and validations: finding (5).
5. Secrets and personal data: ok.
   - The test emails use `example.com`, and the sample CSV uses `.example` domains with invented company names.
   - `overdue.py:23` contains a staff member's name in the signature, which the rules ask for.
   - No keys or tokens anywhere in the diff.
6. Docs and comments: ok for the module docstring ("never sends", "never changes the input file", which is tested) and the `decide` docstring (the order matches the rules). The test file's "one or more per rule" is finding 6.
7. Scope: ok. Only `overdue.py` and `test_overdue.py` are added, with no network and no mail connection.
8. Reversibility: ok. Both files are new and there are no migrations or config changes. The only lasting effect is overwriting the output folder (finding 1).

**Claims checked: 5, unsupported: 1**
- Supported: the commit message (Monday list plus drafts from the export), "never sends", "never changes the input file", and "order follows .claude/rules/reminders.md".
- Unsupported: "one or more [tests] per rule", which is only partly true (finding 6).

**Not checked:**
- Whether the tests pass on commit 52d3acb: there is no shell and no test output was provided.
- Acceptance criterion 3 (same decisions as Mara made by hand last Monday): her hand-made list is not in the repository.
- The actual output of a run on `data/invoices.csv`: I could not run it.
