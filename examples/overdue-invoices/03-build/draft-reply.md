# A customer replies: output of `/draft-external-message`

> Run on 20.10.2026. The customer answered the second reminder: «Wir haben
> diese Rechnung nie erhalten und auch keine erste Erinnerung.» Mara asked
> for a reply. Below is the skill's output, unchanged except for one dash in
> the subject line replaced by a colon (house style). In the demo repository
> used for this run, the rules page sat in a different folder than
> `CLAUDE.md` points to, which is why the skill says it could not check it.
> Note what it leaves out (any claim about a first reminder nobody recorded)
> and what it hands back to Mara (the deadline, and the escalation the tool
> would otherwise trigger on 29.10.).

I couldn't check the main sources: `../expertise/reminder-rules.md` and `../02-assessment.md` are not in this checkout. I worked from your brief, the agent's rule file and the sample CSV.

```
Reader decides:  whether to pay CHF 640.00 now without further discussion, and
                 whether they feel accused or treated fairly.
Helps:           sending the invoice right away without argument; one clear
                 amount and deadline; asking whether we have the right invoice
                 address (this explains the problem without blaming anyone).
Hurts:           saying anything about a first reminder (not recorded, so any
                 claim could be wrong); "you must have missed it" or spam-folder
                 hints (sounds like blame); an apology (admits a fault we don't
                 know we made); keeping the old 10-day deadline from the second
                 reminder without saying so.
Left out:        the first reminder (unknown either way); the second reminder's
                 deadline; any mention of escalation, fees or legal steps (hard
                 rule); a spam-folder sentence (nothing is lost without it).
Sources:         your brief; .claude/rules/reminders.md (formal Sie, invoice no.,
                 amount, due date, signature "Mara Keller, Buchhaltung", no fees);
                 data/invoices.csv line 3 (invented sample, not real data).
                 NOT checked: ../expertise/reminder-rules.md and
                 ../02-assessment.md (missing from this checkout), the
                 accounting software.
Claims:          Invoice 2026-0398, CHF 640.00, due 24.09.2026, address
                   info@atelier-beispiel.example: [from your brief; matches
                   sample CSV, not rechecked against accounting software]
                 Sent 25.08.2026 by email to that address: [from your brief,
                   per accounting software, not rechecked], written as
                   "laut unserer Buchhaltung"
                 New payment deadline: [not decided, placeholder for Mara]
```

---

**Betreff:** Rechnung 2026-0398 : erneute Zustellung

Guten Tag

Vielen Dank für Ihre Nachricht. Gerne senden wir Ihnen die Rechnung 2026-0398 im Anhang nochmals zu.

Laut unserer Buchhaltung ging die Rechnung am 25.08.2026 per E-Mail an info@atelier-beispiel.example. Ist das die richtige Adresse für Ihre Rechnungen, oder sollen wir künftig eine andere verwenden?

Wir bitten Sie, den Betrag von CHF 640.00 bis **[Datum]** auf unser Konto zu überweisen. Die Zahlungsangaben finden Sie auf der Rechnung.

Bei Fragen erreichen Sie mich gerne unter dieser Adresse.

Freundliche Grüsse

Mara Keller
Buchhaltung
Beispiel Services GmbH

---

**What Mara should check before sending:**

1. **Attach the invoice PDF.** The email says it's attached.
2. **Choose the deadline in `[Datum]`.** The draft says nothing about the second reminder's 10-day deadline, so the new date replaces it. Since they say they never got the invoice, I'd suggest giving them a full new payment term from the day she sends it. That's her decision.
3. **Check the facts in the accounting software:** the send date 25.08.2026, the address, and that the payment details on the PDF are correct.
4. **Prevent an escalation.** On 29.10.2026 the invoice reaches 35 days past due. On the next Monday run, the tool will then put it on the list for a call from the managing director. The CSV has no field for "invoice resent, new deadline". So Mara needs to handle this by hand on the 02.11. list, or tell the managing director about the resend. Otherwise a goodwill reply is followed by an escalation call. If this case comes up more often, it would be a new rule. Per CLAUDE.md, that starts on her rules page first.

I haven't sent, scheduled or queued anything. Mara sends it.
