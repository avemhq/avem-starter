# Vor der Einführung: Daten, Kosten, offene Fragen

Zwei Seiten für die Geschäftsleitung. Fakten tragen Quelle und Datum, alles
andere ist als Schätzung gekennzeichnet. Nichts hier ist eine Rechtsberatung.

## Wohin die Daten gehen

- Claude Code läuft auf dem Rechner der Entwicklerin. Für eine Antwort
  schickt es die Eingaben und die gelesenen Dateiteile verschlüsselt (TLS
  1.2 oder neuer) an den Modellanbieter
  ([Data usage](https://code.claude.com/docs/en/data-usage), gelesen
  20.10.2026).
- **Training:** Unter kommerziellen Bedingungen (Team, Enterprise, API)
  trainiert Anthropic keine Modelle mit Code oder Eingaben aus Claude Code,
  ausser der Kunde willigt ein. Die Privatpläne (Free, Pro, Max) haben dafür
  eine Einstellung. Für Firmenarbeit einen kommerziellen Plan nutzen
  (gleiche Quelle).
- **Aufbewahrung:** Kommerzielle Konten standardmässig 30 Tage; keine
  Aufbewahrung (Zero Data Retention) gibt es für geeignete
  Enterprise-Konten. Lokal speichert Claude Code die Sitzungsverläufe im
  Klartext unter `~/.claude/projects/`, standardmässig 30 Tage
  (`cleanupPeriodDays`) (gleiche Quelle).
- **Telemetrie:** Nutzungsdaten ohne Code, Eingaben oder Dateipfade;
  abschaltbar mit `DISABLE_TELEMETRY=1` oder
  `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (gleiche Quelle).
- **Alternativen:** Dieselben Modelle über Amazon Bedrock oder Google Cloud
  laufen in dieser Cloud, Fehlerberichte, Telemetrie und `/feedback` sind
  dort standardmässig aus. Bei Microsoft Foundry hängt es von der
  Bereitstellung ab: auf Azure bleiben Eingaben und Antworten in Azure,
  Nutzungs-Metadaten und von Anthropics Sicherheitssystemen markierte
  Inhalte gehen trotzdem an Anthropic; auf Anthropic laufen die Anfragen
  über Anthropics Infrastruktur. Sitzungsumfragen und die
  WebFetch-Domainprüfung laufen bei jedem Anbieter (gleiche Quelle).

Was der Starter dazu beiträgt: Die üblichen Wege, Geheimnis-Dateien zu
lesen, bleiben gesperrt (`protect-secrets`, Sperrregeln, Sandbox),
`GITHUB_TOKEN` und `NPM_TOKEN` fehlen in Befehlen in der Sandbox (eigene
Token-Namen ergänzen), und die üblichen Befehle für Versand,
Veröffentlichung und Deployment sind gesperrt (`block-external-send`).
Vollständig ist nichts davon: siehe [threat-model.md](threat-model.md).

## Was es pro Person kostet

Aus [claude.com/pricing](https://claude.com/pricing), gelesen 20.10.2026,
in US-Dollar, ohne Steuern:

| Plan | Preis | Hinweis |
|---|---|---|
| Team, Standardplatz | 20 pro Platz und Monat (jährlich), 25 (monatlich) | mit Claude Code |
| Team, Premiumplatz | 100 pro Platz und Monat (jährlich), 125 (monatlich) | fünfmal so viel Nutzung wie ein Standardplatz |
| Enterprise, Selbstbedienung | 20 pro Platz und Monat (jährlich), mindestens 20 Plätze | Nutzung zusätzlich, nach Modell und Aufgabe |

Rechenbeispiel für 10 Personen, jährlich bezahlt: 8 Standardplätze und 2
Premiumplätze für die zwei intensivsten Nutzer kosten 8 × 20 + 2 × 100 = 360
Dollar im Monat, 4'320 im Jahr. Ob Standardplätze für tägliche
Programmierarbeit reichen, ist eine Schätzung, die im ersten Monat zu messen
ist, keine Tatsache.

## Offene Fragen an Ihre Datenschutzverantwortliche (Schweiz, revDSG)

Fragen, keine Antworten:

1. Enthalten Code oder Eingaben Personendaten von Kunden oder Mitarbeitenden?
   Dann braucht die Bekanntgabe an den Anbieter im Ausland eine Grundlage;
   welche gilt?
2. Liegt für den gewählten Plan der Auftragsbearbeitungsvertrag des Anbieters
   vor, und wer unterzeichnet ihn?
3. Müssen Mitarbeitende informiert werden, dass ein KI-Werkzeug ihre
   Arbeitsdateien liest, und ist die lokale Speicherung der Verläufe während
   30 Tagen in Ordnung?
4. Welche Repositories sind von der KI-Nutzung ganz ausgenommen?
5. Braucht ein Projekt keine Aufbewahrung beim Anbieter oder einen
   Cloud-Anbieter in einer bestimmten Region?

## Was eine Einführung an Zeit kostet

Einrichtung auf einem Rechner rund 30 Minuten mit dem Starter; ein Team von
10 Personen rund einen halben Tag samt verwalteten Einstellungen und
Checkliste ([Team rollout](team-rollout.md)) [Schätzung].
