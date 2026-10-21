# Review 2, unedited output of `/pre-merge-review`

> Run on 20.10.2026 after the commit `fix: review findings 1 to 4 and 8`.
> Only the closing list of local file paths was removed. The reviewer now
> saw the full commit messages, including the test line the author wrote,
> and still marks the test run as a claim it could not check itself.

**Verdict: ready after fixes.** Nothing gets sent and the main rules hold. Finding 1 conflicts with a hard rule in CLAUDE.md, and finding 2 can silently lose a draft on this Mac.

Findings (most severe first):

1. **[medium] `overdue.py:105`, `test_overdue.py:47`, `.claude/rules/reminders.md:26`.** The amount check comes before the complaint and payment-plan checks.
   - **How it fails:** an invoice under CHF 50 with an open complaint or a payment plan gets `hold`, not `person`. CLAUDE.md says "No draft for an open complaint or a payment plan, ever. Those cases go on the list for a person." `test_rule_order` locks in the `hold` result. No draft is produced, but nobody is asked about the complaint, which goes against Mara's rule 5.
   - **Fix:** ask Mara. If she agrees, move the payment-plan and complaint checks before the amount check, and update the rule file and the test.

2. **[medium] `overdue.py:72`, `overdue.py:166`.** The duplicate check is case-sensitive, but the default macOS file system (APFS) is not.
   - **How it fails:** on this Mac, `R-1` and `r-1` both pass the check, but write to the same draft file. The second draft silently overwrites the first, while `report.md` still lists both as reminders.
   - **Fix:** check duplicates with `iid.casefold()`, and add a test with two ids that differ only in case.

3. **[medium] `.claude/rules/reminders.md:16,21` and `overdue.py:103-104, 113-114`.** Two new decision rules were written into the agent's rule file and the code, but not into `expertise/reminder-rules.md`: "zero or negative amount → person" and "no email address → person".
   - **How it fails:** CLAUDE.md says a rule changes in Mara's page first, with her. Rule 9 ("when I am unsure, I ask") supports both rules, but she has not seen them.
   - **Fix:** add both to the open questions in `expertise/reminder-rules.md` for Mara to confirm.

4. **[low] `overdue.py:63` (csv.Error branch) and `overdue.py:70` (the `".." in iid` part).** Two guards never fire in any test.
   - The one test with an unsafe id, `../x`, is already rejected by the pattern, so the `..` check is never reached. It is also redundant, because `/` is not allowed anyway.
   - No test feeds a broken CSV, so the commit's claim "CSV errors ... stop the run with a readable message" is unproven.
   - **Fix:** add a test that triggers a `csv.Error` (for example a field over the size limit), and either remove the `..` check or add an id like `a..b` that only it rejects.

5. **[low] `overdue.py:124-129`, `chf()`.** Negative amounts with exactly three digits are formatted wrong: `chf(Decimal("-120"))` gives `CHF -'120.00`. Since this branch sends negative amounts to `person`, they now show on the list in this form.
   - **Fix:** remove the sign before grouping the digits and add it back after; add a test for it.

6. **[low] `overdue.py:159-178`.** If a write fails partway through the run, there is no clean recovery.
   - **How it fails:** the folder for the day is created before any file is written. If writing fails (disk full, permissions), the folder is left with only some drafts and no `report.md`, and the next run refuses it. The error does show (exit code 2), but nothing checks that the files were written before printing the counts.
   - **Fix:** write into a temporary folder next to the target and rename it when done, or delete the folder on error.

7. **[low] `overdue.py:54`.** The file is opened as `utf-8`, not `utf-8-sig`.
   - **How it fails:** an export from Excel often starts with a byte-order mark (BOM). The tool then stops with "missing columns: invoice_id", which is confusing. Rows with too many fields are silently accepted.
   - **Fix:** open with `utf-8-sig`, and reject rows that have extra fields.

8. **[low] around `overdue.py:174-176`.** Customer names go into the markdown table unescaped. A `|` or a line break in a name shifts the columns of the list Mara reads.
   - **Fix:** replace `|` with `\|` and line breaks with spaces.

9. **[low] Scope: `.claude/skills/pre-merge-review/SKILL.md`.** The fix commit changes the review skill itself, and the commit message does not mention it. The change makes the review see more (full commit messages), not less. It should still be named or moved to its own commit.

Claims checked: 9, unsupported: 2

| # | Claim | Result |
|---|---|---|
| 1 | Each run writes to `out/<day>/` and an existing folder is refused | supported (`overdue.py:157-160`, test) |
| 2 | Empty fields, NaN, unsafe or duplicate invoice numbers stop the run with a message | supported by tests |
| 3 | CSV errors stop the run with a message | unsupported: no test makes it fire (finding 4) |
| 4 | Zero or negative amounts and missing emails go to a person | supported in code and tests, but not agreed with Mara (finding 3) |
| 5 | `draft()` refuses other decisions | supported (`overdue.py:151`, test) |
| 6 | Finding 7 is recorded as a question for Mara | supported (`expertise/reminder-rules.md:26-33`) |
| 7 | Sends nothing, input left untouched | supported (no network code; there is a test for this) |
| 8 | Writes `report.md` and one draft per reminder | supported |
| 9 | "Ran 17 tests ... OK" | unsupported here: the test file does contain 17 tests, but I could not run them |

Checklist:

1. **Tests ran on this exact state:** not checked (no shell).
2. **Error paths:** finding (6, 7). Otherwise errors are visible and give exit code 2.
3. **Read-back:** finding (6).
4. **Guards and validations:** finding (4). The others have tests that make them fire and pass.
5. **Secrets and personal data:** ok. The diff has test email addresses on the reserved `example.com` domain, invented customer names in `test_overdue.py`, and the name Mara Keller in `overdue.py:24`, which CLAUDE.md says is fictitious. `out/` is in `.gitignore`.
6. **Docs and comments:** finding (1, 3). The rule file's "Order matters" line matches the code, but it conflicts with CLAUDE.md.
7. **Scope:** finding (9).
8. **Reversibility:** ok. No deletions or migrations; runs never overwrite earlier output.

Not checked:
- The test run (no shell). The "17 tests OK" comes from the author's commit message, and I can't tell which commit it ran on.
- Earlier review findings 5 and 6. The commit fixes 1-4 and 8 and records 7 as a question, but says nothing about 5 and 6, and I don't have that earlier review.
- The case-insensitivity in finding 2 assumes the default APFS setting; I could not check this machine's file system.
- `data/invoices.csv`, which is not part of this diff.

