---
paths:
  - "overdue.py"
  - "test_overdue.py"
  - "data/**"
---

# Reminder rules (from Mara's page, expertise/reminder-rules.md)

Fictitious example: the expertise step turned into a rule Claude loads
whenever it works on the reminder code.

| Case | Decision |
|---|---|
| paid | ignore |
| amount zero or negative (credit note?) | `person`: unclear |
| amount under CHF 50.00 | `hold`: wait until year end |
| payment plan | `person`: never a draft |
| open complaint | `person`: ask the colleague handling it, never a draft |
| 35 days or more past due | `person`: managing director calls |
| 10 days or more, but no email address | `person`: nobody to write to |
| 20 to 34 days | `reminder-2`: polite but clear, pay within 10 days |
| 10 to 19 days | `reminder-1`: friendly, "perhaps overlooked" |
| under 10 days | ignore |

Order matters: paid, amount, payment plan, complaint, then days. A customer
with an open complaint is never reminded, however late the invoice.

Every run writes into a new folder named after the day; an existing folder
is refused, so last week's drafts never sit next to this week's list.
Input that does not fit (empty fields, a non-number amount, an unsafe or
duplicate invoice number) stops the run with a readable message.

Drafts: German, formal "Sie", invoice number, amount, due date, signed
"Mara Keller, Buchhaltung". Never fees, interest, debt collection or legal
steps. When a case is unclear, it goes to a person.
