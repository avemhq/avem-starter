# 04 Übergabe

> Erfundenes Beispiel. Das bekommt das Team am Ende des Projekts.

## Für Mara: der Montagsablauf (Schulungsblatt)

1. Die offenen Posten wie bisher als CSV aus der Buchhaltungssoftware
   exportieren.
2. Starten: `python3 overdue.py --csv <export.csv> --today <montag> --out <ordner>`
3. `<ordner>/<montag>/report.md` öffnen. Zuoberst stehen die Fälle für
   einen Menschen.
4. Jeden Entwurf in `drafts/` lesen, anpassen und aus dem eigenen Postfach
   versenden.
5. Meldet das Werkzeug, der Ordner bestehe schon: Es lief am selben Tag
   zweimal. Den alten Ordner verschieben oder löschen, dann erneut starten.

Das Werkzeug versendet nichts. Im Export wird nichts verändert.

## Eine Regel ändern

1. Die Änderung auf der eigenen Seite (`expertise/reminder-rules.md`) in
   eigenen Worten festhalten.
2. Wer das Werkzeug betreut, macht daraus die Regeldatei, einen Test und
   dann den Code und lässt die Prüfung laufen, bevor die Änderung genutzt
   wird.

## Dokumentation

- [01-task.md](01-task.md): die Aufgabe, wie Mara sie beschrieben hat
- [02-assessment.de.md](02-assessment.de.md): was das Werkzeug tut und was
  nicht, Abnahmekriterien
- [03-build.md](03-build.md): wie es gebaut und geprüft wurde (englisch)
- [project/CLAUDE.md](project/CLAUDE.md): die Arbeitsregeln für Claude in
  diesem Projekt

## Rückbau

Den Ordner `project/` löschen. Das Werkzeug schreibt nur in den genannten
Ausgabeordner; sonst gibt es nichts zu entfernen, kein Konto, keine
Verbindung.

## Nach vier Wochen

Vergleichen: Zeit am Montag, versendete Mahnungen, Mahnungen, die nicht
hätten rausgehen dürfen. Diese Zahl entscheidet, ob eine Regel angepasst
wird.
