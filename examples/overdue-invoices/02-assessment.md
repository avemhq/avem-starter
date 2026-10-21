# 02 Assessment: whether and how much AI can take on

> Fictitious example. In a real project this page is agreed with the client
> before anything is built; the price is part of the offer, not of this page.

## What the agent takes on

- Read the weekly export of open items (CSV).
- Apply Mara's rules: which invoice gets a first or second reminder, which
  goes to the managing director, which is left alone and why.
- Write the Monday list and one German reminder draft per invoice, as text
  files in a folder. Nothing is sent.

## What stays with people

- Mara reads the list, adjusts and sends the emails herself.
- Every case with an open complaint, a payment plan or 35 days and more is
  listed for a person, never drafted.
- Fees and legal steps: managing director only.

## Scope

- Input: the CSV export the accounting software already produces.
- Output: `report.md` and one draft per reminder.
- Not in scope: connecting to the mail system, changing data in the
  accounting software, other languages.

## Acceptance criteria

1. Every rule on Mara's page has at least one test that shows it working,
   including the day boundaries (9 and 10, 19 and 20, 34 and 35 days).
2. No draft is ever written for a customer with an open complaint or a
   payment plan.
3. A run on last Monday's export gives the same decisions Mara made by hand.
4. Running the tool sends nothing and changes no input file.
5. Mara can run it herself after a 30-minute introduction.

## What this saves, roughly

From about 3 hours on Mondays to about 30 minutes of reading and sending
[estimate, to be measured after four weeks].
