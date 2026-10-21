# Ihr Fachwissen, Ihre KI-Agenten.

Bringen Sie mir die Aufgabe, die Ihr Team jede Woche Stunden kostet: Wir
prüfen gemeinsam, ob und wie weit KI sie übernehmen kann, ich baue die
vereinbarte Lösung mit Claude Code und übergebe sie Ihrem Team, mit
Dokumentation und Schulung.

*Technische Referenz auf Englisch: [README.md](README.md).*

## Das Problem

Ein KI-Agent wie Claude Code arbeitet schnell, liest Dateien und führt
Befehle aus. Wer ihn im Team einsetzt, will drei Dinge sicher wissen:
Geheimnisse bleiben geheim, nichts geht ohne Menschen nach aussen, und die
Schutzregeln laufen wirklich, auch nach einem Update.

## So arbeitet Avem

1. **Sie bringen die Aufgabe**, die Ihr Team jede Woche Stunden kostet.
2. **Wir prüfen gemeinsam**, ob und wie weit KI sie übernehmen kann und was
   bei Ihren Leuten bleibt.
3. **Festpreis** für den vereinbarten Umfang.
4. **Ich baue** die Lösung mit Claude Code, auf einer Grundlage wie dieser.
5. **Übergabe** an Ihr Team, mit Dokumentation und Schulung.

Ein ganzer Auftrag von der Aufgabe bis zur Übergabe, mit erfundenem Kunden
und echten Läufen: [Beispiel Mahnwesen](examples/overdue-invoices/)
([Prüfung](examples/overdue-invoices/02-assessment.de.md),
[Übergabe](examples/overdue-invoices/04-handover.de.md)).

## Was Sie bekommen

- **Drei Wachen vor jedem Befehl:** keine Geheimnisse auf dem Bildschirm,
  kein Überschreiben der Git-Geschichte, kein Versand, keine Veröffentlichung
  und kein Deployment durch den Agenten.
- **Sicher bei Defekt:** Eine Wache, die nicht starten kann, abstürzt, zu
  lange braucht oder ihre Eingabe nicht lesen kann, hält den Befehl an,
  statt ihn durchzulassen.

  ![Der Agent will npm publish ausführen, die Wache hält ihn an](docs/images/blocked-send.svg)

- **Ein Selbsttest, der rot werden kann:** Er belegt, dass jede Wache
  eingetragen ist, sperrt, was sie sperren soll, und durchlässt, was harmlos
  ist. Und er belegt an absichtlich kaputten Einstellungen, dass er selbst
  einen Fehler bemerkt.

  ![Eine Zeile in den Einstellungen fehlt, der Selbsttest wird rot](docs/images/selftest-red.svg)

- **Eine Prüfung ohne Schreibrechte:** Vor dem Zusammenführen prüft ein
  eigener Agent ohne Shell und ohne Schreibwerkzeuge die Änderung, die er
  nicht selbst geschrieben hat.
- **Entwürfe für Kundennachrichten:** Jede Nachricht nach aussen beginnt mit
  einer Analyse und wird nie vom Agenten versendet.
- **Für das ganze Team:** verwaltete Einstellungen, die niemand lokal
  abschaltet ([team-rollout.md](docs/team-rollout.md)), dazu Daten, Kosten
  und offene Fragen für die Geschäftsleitung
  ([before-you-roll-out.de.md](docs/before-you-roll-out.de.md)).

## Grenzen

Die Wachen prüfen den Text eines Befehls. Sie halten die üblichen Formen
auf, sind aber keine Sicherheitsgrenze: Ein Programm, das eine Datei selbst
öffnet, sehen sie nicht. Die eigentliche Wand ist die Sandbox des
Betriebssystems (macOS, Linux und WSL2; unter Windows ohne WSL2 gibt es
keine). Welche Risiken abgedeckt sind und welche nicht:
[threat-model.md](docs/threat-model.md).

## Kontakt

Avem Investment GmbH, Chur, Schweiz · gebaut von Patric Vogel

- Web: [avemhq.com](https://avemhq.com)
- Adresse: Avem Investment GmbH, La-Nicca-Strasse 10, 7000 Chur, Schweiz

MIT-Lizenz. Avem Investment GmbH.
