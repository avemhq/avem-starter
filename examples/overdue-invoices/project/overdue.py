#!/usr/bin/env python3
"""Prepare the Monday list of overdue invoices and German reminder drafts.

Fictitious example project. Reads a CSV export of open items, applies the
rules in .claude/rules/reminders.md (from expertise/reminder-rules.md) and
writes report.md plus one draft per reminder into <out>/<today>/.
It never sends anything and never changes the input file.

Usage: python3 overdue.py --csv data/invoices.csv --today 2026-10-19 --out out
"""
import argparse
import csv
import re
import sys
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path

SMALL_AMOUNT = Decimal("50.00")
FIRST_REMINDER_DAYS = 10
SECOND_REMINDER_DAYS = 20
PERSON_DAYS = 35
SIGNATURE = "Mara Keller, Buchhaltung"
REQUIRED = ["invoice_id", "customer", "email", "amount_chf", "due_date",
            "paid", "complaint_open", "payment_plan"]


@dataclass
class Invoice:
    invoice_id: str
    customer: str
    email: str
    amount: Decimal
    due: date
    paid: bool
    complaint_open: bool
    payment_plan: bool


def parse_bool(value, field, row_no):
    v = (value or "").strip().lower()
    if v in ("yes", "ja", "true", "1"):
        return True
    if v in ("no", "nein", "false", "0"):
        return False
    raise ValueError(f"row {row_no}: {field} must be yes or no, got {value!r}")


SAFE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")


def read_invoices(path):
    # utf-8-sig: exports from Excel often start with a byte-order mark.
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, restkey="_extra")
        names = [(n or "").strip() for n in (reader.fieldnames or [])]
        dupes = sorted({n for n in names if n and names.count(n) > 1})
        if dupes:
            # DictReader keeps only the last of two equal columns, so a
            # complaint in the first "disputed" column would be lost.
            raise ValueError(f"duplicate columns: {', '.join(dupes)}")
        missing = [c for c in REQUIRED if c not in (reader.fieldnames or [])]
        if missing:
            raise ValueError(f"missing columns: {', '.join(missing)}")
        invoices = []
        seen = set()
        try:
            rows = list(enumerate(reader, start=2))
        except csv.Error as e:
            raise ValueError(f"the file is not a readable CSV: {e}")
        for row_no, row in rows:
            if row.get("_extra"):
                raise ValueError(f"row {row_no}: more fields than columns")
            empty = [c for c in REQUIRED if c != "email" and not (row.get(c) or "").strip()]
            if empty:
                raise ValueError(f"row {row_no}: empty field(s): {', '.join(empty)}")
            iid = row["invoice_id"].strip()
            if not SAFE_ID.fullmatch(iid):
                raise ValueError(f"row {row_no}: invoice_id may only contain letters, digits, . _ -")
            # casefold: R-1 and r-1 would be the same draft file on macOS.
            if iid.casefold() in seen:
                raise ValueError(f"row {row_no}: invoice_id {iid} appears twice")
            seen.add(iid.casefold())
            try:
                amount = Decimal(row["amount_chf"].strip())
            except InvalidOperation:
                raise ValueError(f"row {row_no}: amount_chf is not a number")
            if not amount.is_finite():
                raise ValueError(f"row {row_no}: amount_chf is not a number")
            try:
                due = date.fromisoformat(row["due_date"].strip())
            except ValueError:
                raise ValueError(f"row {row_no}: due_date must be YYYY-MM-DD")
            invoices.append(Invoice(
                invoice_id=iid,
                customer=row["customer"].strip(),
                email=(row.get("email") or "").strip(),
                amount=amount,
                due=due,
                paid=parse_bool(row["paid"], "paid", row_no),
                complaint_open=parse_bool(row["complaint_open"], "complaint_open", row_no),
                payment_plan=parse_bool(row["payment_plan"], "payment_plan", row_no),
            ))
        return invoices


def decide(inv, today):
    """Return (decision, reason). Order follows .claude/rules/reminders.md."""
    days = (today - inv.due).days
    if inv.paid:
        return "ignore", "paid"
    if inv.amount <= 0:
        return "person", "zero or negative amount (credit note?), unclear"
    if inv.amount < SMALL_AMOUNT:
        return "hold", "under CHF 50, wait until year end"
    if inv.payment_plan:
        return "person", "payment plan, no reminder"
    if inv.complaint_open:
        return "person", "open complaint, ask the colleague handling it"
    if days >= PERSON_DAYS:
        return "person", f"{days} days overdue, managing director calls"
    if days >= FIRST_REMINDER_DAYS and "@" not in inv.email:
        return "person", f"{days} days overdue, but no email address"
    if days >= SECOND_REMINDER_DAYS:
        return "reminder-2", f"{days} days overdue"
    if days >= FIRST_REMINDER_DAYS:
        return "reminder-1", f"{days} days overdue"
    return "ignore", f"{days} days overdue, not yet due for a reminder"


def chf(amount):
    sign = "-" if amount < 0 else ""
    whole, _, cents = f"{abs(amount):.2f}".partition(".")
    groups = []
    while len(whole) > 3:
        groups.insert(0, whole[-3:])
        whole = whole[:-3]
    groups.insert(0, whole)
    return f"CHF {sign}{chr(39).join(groups)}.{cents}"


def cell(text):
    """Keep the report table intact: no | and no line breaks in a cell."""
    return " ".join(str(text).split()).replace("|", "\\|")


def draft(inv, decision):
    due = inv.due.strftime("%d.%m.%Y")
    if decision == "reminder-1":
        subject = f"Zahlungserinnerung Rechnung {inv.invoice_id}"
        body = (f"Guten Tag\n\nUnsere Rechnung {inv.invoice_id} über {chf(inv.amount)}, "
                f"fällig am {due}, ist bei uns noch offen. Vielleicht ist sie untergegangen. "
                f"Wir danken Ihnen für die Begleichung in den nächsten Tagen.\n\n"
                f"Falls Sie bereits bezahlt haben, betrachten Sie diese Nachricht bitte als "
                f"gegenstandslos.\n\nFreundliche Grüsse\n{SIGNATURE}\n")
    elif decision == "reminder-2":
        subject = f"Zweite Zahlungserinnerung Rechnung {inv.invoice_id}"
        body = (f"Guten Tag\n\nUnsere Rechnung {inv.invoice_id} über {chf(inv.amount)}, "
                f"fällig am {due}, ist trotz unserer Erinnerung noch offen. Wir bitten Sie, "
                f"den Betrag innert 10 Tagen zu überweisen. Sollte mit der Rechnung etwas "
                f"nicht stimmen, melden Sie sich bitte bei uns.\n\n"
                f"Freundliche Grüsse\n{SIGNATURE}\n")
    else:
        raise ValueError(f"no draft for decision {decision}")
    return f"An: {inv.email}\nBetreff: {subject}\n\n{body}"


def run(csv_path, today, out_dir):
    """Write into <out_dir>/<today>/. Refuses to reuse a folder, so a draft
    from an earlier run can never sit next to this week's list."""
    invoices = read_invoices(csv_path)
    out = Path(out_dir) / today.isoformat()
    if out.exists():
        raise ValueError(f"{out} already exists; move or delete it before a new run")
    drafts_dir = out / "drafts"
    drafts_dir.mkdir(parents=True)
    rows = []
    for inv in invoices:
        decision, reason = decide(inv, today)
        if decision.startswith("reminder"):
            (drafts_dir / f"{inv.invoice_id}.txt").write_text(draft(inv, decision), encoding="utf-8")
        rows.append((inv, decision, reason))
    lines = [f"# Overdue invoices, {today.isoformat()}", "",
             "Nothing has been sent. Read the drafts in drafts/, adjust, send yourself.", "",
             "| Invoice | Customer | Amount | Due | Decision | Why |",
             "|---|---|---|---|---|---|"]
    order = {"person": 0, "reminder-2": 1, "reminder-1": 2, "hold": 3, "ignore": 4}
    for inv, decision, reason in sorted(rows, key=lambda r: (order[r[1]], r[0].due)):
        if decision == "ignore" and reason == "paid":
            continue
        lines.append(f"| {inv.invoice_id} | {cell(inv.customer)} | {chf(inv.amount)} | "
                     f"{inv.due.isoformat()} | {decision} | {reason} |")
    (out / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return rows


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--csv", required=True)
    p.add_argument("--today", required=True, help="YYYY-MM-DD, the Monday of the run")
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    try:
        today = date.fromisoformat(a.today)
        rows = run(a.csv, today, a.out)
    except (OSError, ValueError) as e:
        print(f"overdue: {e}", file=sys.stderr)
        return 2
    counts = {}
    for _, decision, _ in rows:
        counts[decision] = counts.get(decision, 0) + 1
    print(" ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
