# 02 Prüfung: ob und wie weit KI die Aufgabe übernehmen kann

> Erfundenes Beispiel. In einem echten Projekt wird diese Seite mit dem
> Kunden abgestimmt, bevor etwas gebaut wird; der Preis steht in der
> Offerte, nicht auf dieser Seite.

## Was der Agent übernimmt

- Den wöchentlichen Export der offenen Posten (CSV) einlesen.
- Maras Regeln anwenden: welche Rechnung eine erste oder zweite Mahnung
  bekommt, welche an die Geschäftsleitung geht, welche ruhen bleibt und
  warum.
- Die Montagsliste schreiben und je Rechnung einen deutschen Mahnentwurf als
  Textdatei ablegen. Es wird nichts versendet.

## Was bei den Menschen bleibt

- Mara liest die Liste, passt an und versendet die Mails selbst.
- Jeder Fall mit offener Reklamation, Zahlungsplan oder ab 35 Tagen steht
  auf der Liste für einen Menschen und bekommt nie einen Entwurf.
- Gebühren und rechtliche Schritte: nur die Geschäftsleitung.

## Umfang

- Eingang: der CSV-Export, den die Buchhaltungssoftware schon heute liefert.
- Ausgang: `report.md` und je Mahnung ein Entwurf.
- Nicht im Umfang: Anbindung an das Mailsystem, Änderungen in der
  Buchhaltungssoftware, weitere Sprachen.

## Abnahmekriterien

1. Jede Regel auf Maras Seite hat mindestens einen Test, der sie belegt,
   auch an den Tagesgrenzen (9 und 10, 19 und 20, 34 und 35 Tage).
2. Für Kunden mit offener Reklamation oder Zahlungsplan entsteht nie ein
   Entwurf.
3. Ein Lauf auf dem Export vom letzten Montag ergibt dieselben Entscheide,
   die Mara von Hand getroffen hat.
4. Ein Lauf versendet nichts und ändert keine Eingabedatei.
5. Mara kann das Werkzeug nach einer Einführung von 30 Minuten selbst
   starten.

## Was das ungefähr spart

Von rund 3 Stunden am Montag auf rund 30 Minuten Lesen und Versenden
[Schätzung, nach vier Wochen zu messen].
