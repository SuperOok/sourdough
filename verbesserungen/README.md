# Verbesserungen

Je Problem eine Datei `VB-<nnn>.md`. Eine Verbesserung beschreibt ein Problem
und seine Lösung, nicht eine einzelne Rückmeldung: Mehrere Rückmeldungen können
zu einer Verbesserung gehören.

Die Rückmeldungen selbst liegen nur lokal unter `feedback/` (in `.gitignore`,
weil das Repository öffentlich ist). Hier stehen nur ihre Nummern mit einer
Zeile Zusammenfassung, **keine wörtlichen Zitate und keine Namen**.

Aufbau einer Datei:

- Kopf: `id`, `titel`, `status` (offen | geplant | in Arbeit | umgesetzt |
  verworfen), `erstellt`, `version` (gegen die das Feedback kam).
- `## Problem` – ohne Lösung formuliert.
- `## Rückmeldungen` – FB-Nummern mit je einer Zeile.
- `## Ursache im Code` – wo es entsteht, falls bekannt.
- `## Optionen` – zwei bis drei Wege mit Vor- und Nachteilen.
- `## Entscheidung` – gewählte Option, Begründung, Datum.
- `## Betroffen` bzw. `## Plan` – Dateien, Tests, Doku.
- `## Ergebnis` – Commit oder Branch, ab welcher Version, Rückmeldung an die
  Testenden.

Später lassen sich die Dateien eins zu eins in GitHub-Issues überführen.
