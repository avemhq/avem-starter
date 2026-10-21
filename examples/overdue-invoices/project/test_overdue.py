"""Tests for overdue.py: one or more per rule in .claude/rules/reminders.md."""
import csv
import tempfile
import unittest
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

import overdue

TODAY = date(2026, 10, 19)


def inv(days=15, amount="120.00", paid=False, complaint=False, plan=False, iid="R-1"):
    return overdue.Invoice(iid, "Test AG", "test@example.com", Decimal(amount),
                           TODAY - timedelta(days=days), paid, complaint, plan)


class DecideTests(unittest.TestCase):
    def d(self, **kw):
        return overdue.decide(inv(**kw), TODAY)[0]

    def test_paid_is_ignored(self):
        self.assertEqual(self.d(days=60, paid=True), "ignore")

    def test_day_boundaries(self):
        self.assertEqual(self.d(days=9), "ignore")
        self.assertEqual(self.d(days=10), "reminder-1")
        self.assertEqual(self.d(days=19), "reminder-1")
        self.assertEqual(self.d(days=20), "reminder-2")
        self.assertEqual(self.d(days=34), "reminder-2")
        self.assertEqual(self.d(days=35), "person")

    def test_small_amount_waits(self):
        self.assertEqual(self.d(days=40, amount="49.95"), "hold")
        self.assertEqual(self.d(days=15, amount="50.00"), "reminder-1")

    def test_complaint_never_gets_a_reminder(self):
        for days in (10, 20, 35, 90):
            self.assertEqual(self.d(days=days, complaint=True), "person")

    def test_payment_plan_never_gets_a_reminder(self):
        for days in (10, 20, 35):
            self.assertEqual(self.d(days=days, plan=True), "person")

    def test_rule_order(self):
        self.assertEqual(self.d(days=20, amount="30.00", complaint=True), "hold")
        self.assertEqual(self.d(days=20, paid=True, complaint=True), "ignore")

    def test_unclear_cases_go_to_a_person(self):
        self.assertEqual(self.d(days=20, amount="-120.00"), "person")
        self.assertEqual(self.d(days=20, amount="0.00"), "person")
        no_mail = inv(days=20)
        no_mail.email = ""
        self.assertEqual(overdue.decide(no_mail, TODAY)[0], "person")


class RunTests(unittest.TestCase):
    def write_csv(self, folder, rows):
        path = Path(folder) / "invoices.csv"
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(overdue.REQUIRED)
            w.writerows(rows)
        return path

    def test_drafts_only_for_reminders_and_input_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            rows = [
                ["R-1", "A AG", "a@example.com", "100.00", "2026-10-05", "no", "no", "no"],
                ["R-2", "B AG", "b@example.com", "100.00", "2026-09-25", "no", "yes", "no"],
                ["R-3", "C AG", "c@example.com", "100.00", "2026-09-25", "no", "no", "no"],
            ]
            src = self.write_csv(tmp, rows)
            before = src.read_bytes()
            overdue.run(src, TODAY, Path(tmp) / "out")
            drafts = sorted(p.name for p in (Path(tmp) / "out" / TODAY.isoformat() / "drafts").iterdir())
            self.assertEqual(drafts, ["R-1.txt", "R-3.txt"])
            self.assertEqual(src.read_bytes(), before)

    def test_no_draft_for_payment_plan_in_a_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = self.write_csv(tmp, [["R-1", "A AG", "a@example.com", "100.00", "2026-09-25", "no", "no", "yes"]])
            overdue.run(src, TODAY, Path(tmp) / "out")
            self.assertEqual(list((Path(tmp) / "out" / TODAY.isoformat() / "drafts").iterdir()), [])

    def test_a_second_run_never_mixes_with_old_drafts(self):
        # Review finding 1: a draft from last week must not sit next to this
        # week's list. The same folder is refused, a new day gets a new one.
        with tempfile.TemporaryDirectory() as tmp:
            src = self.write_csv(tmp, [["R-1", "A AG", "a@example.com", "100.00", "2026-10-05", "no", "no", "no"]])
            overdue.run(src, TODAY, Path(tmp) / "out")
            with self.assertRaises(ValueError):
                overdue.run(src, TODAY, Path(tmp) / "out")
            src = self.write_csv(tmp, [["R-1", "A AG", "a@example.com", "100.00", "2026-10-05", "no", "yes", "no"]])
            nxt = TODAY + timedelta(days=7)
            overdue.run(src, nxt, Path(tmp) / "out")
            self.assertEqual(list((Path(tmp) / "out" / nxt.isoformat() / "drafts").iterdir()), [])

    def test_draft_has_no_fees_or_legal_steps(self):
        for decision in ("reminder-1", "reminder-2"):
            text = overdue.draft(inv(), decision).lower()
            for word in ("gebühr", "zins", "betreibung", "inkasso", "rechtlich"):
                self.assertNotIn(word, text)

    def test_amount_format(self):
        self.assertEqual(overdue.chf(Decimal("1234.5")), "CHF 1'234.50")
        self.assertEqual(overdue.chf(Decimal("-120")), "CHF -120.00")
        self.assertEqual(overdue.chf(Decimal("-1234")), "CHF -1'234.00")

    def test_report_cells_stay_in_their_column(self):
        self.assertEqual(overdue.cell("A | B\nAG"), "A \\| B AG")

    def test_excel_bom_and_extra_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "invoices.csv"
            path.write_text("﻿" + ",".join(overdue.REQUIRED) + "\n"
                            "R-1,A,a@example.com,100,2026-10-05,no,no,no\n", encoding="utf-8")
            self.assertEqual(len(overdue.read_invoices(path)), 1)
            path.write_text(",".join(overdue.REQUIRED) + "\n"
                            "R-1,A,a@example.com,100,2026-10-05,no,no,no,surprise\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                overdue.read_invoices(path)

    def test_broken_csv_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "invoices.csv"
            path.write_text(",".join(overdue.REQUIRED) + "\n"
                            'R-1,"A,a@example.com,100,2026-10-05,no,no,no\n', encoding="utf-8")
            old = csv.field_size_limit(16)
            try:
                with self.assertRaises(ValueError):
                    overdue.read_invoices(path)
            finally:
                csv.field_size_limit(old)

    def test_bad_input_is_reported(self):
        bad_rows = [
            ["R-1", "A", "a@example.com", "x", "2026-10-05", "no", "no", "no"],
            ["R-1", "A", "a@example.com", "NaN", "2026-10-05", "no", "no", "no"],
            ["R-1", "A", "a@example.com", "100", "05.10.2026", "no", "no", "no"],
            ["R-1", "A", "a@example.com", "100", "2026-10-05", "maybe", "no", "no"],
            ["../x", "A", "a@example.com", "100", "2026-10-05", "no", "no", "no"],
            ["R-1", "A", "a@example.com", "100"],
        ]
        for row in bad_rows:
            with tempfile.TemporaryDirectory() as tmp:
                src = self.write_csv(tmp, [row])
                with self.assertRaises(ValueError, msg=str(row)):
                    overdue.read_invoices(src)

    def test_duplicate_ids_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            row = ["R-1", "A", "a@example.com", "100", "2026-10-05", "no", "no", "no"]
            src = self.write_csv(tmp, [row, ["r-1"] + row[1:]])
            with self.assertRaises(ValueError):
                overdue.read_invoices(src)

    def test_missing_column_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "invoices.csv"
            path.write_text("invoice_id,customer\nR-1,A\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                overdue.read_invoices(path)

    def test_duplicate_column_is_refused(self):
        # Two complaint_open columns: the reader would keep only the last one,
        # so an open complaint in the first could be lost.
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "invoices.csv"
            path.write_text(
                "invoice_id,customer,email,amount_chf,due_date,paid,complaint_open,payment_plan,complaint_open\n"
                "R-1,A,a@x.example,10.00,2026-10-01,no,yes,no,no\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate columns: complaint_open"):
                overdue.read_invoices(path)

    def test_main_reports_errors_with_exit_2(self):
        self.assertEqual(overdue.main(["--csv", "/nonexistent.csv", "--today", "2026-10-19", "--out", "x"]), 2)
        self.assertEqual(overdue.main(["--csv", "/nonexistent.csv", "--today", "19.10.2026", "--out", "x"]), 2)

    def test_draft_only_for_reminder_decisions(self):
        with self.assertRaises(ValueError):
            overdue.draft(inv(), "person")


if __name__ == "__main__":
    unittest.main()
