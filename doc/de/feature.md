# Funktionalität

Agenten können die folgenden Ticket-Attribute direkt im Widget **Ticket-Information** der Ticket-Zoom-Ansicht bearbeiten, ohne ein Popup zu öffnen:

* Typ
* Status (inklusive "Warten bis" bei Warte-Status)
* Sperre
* Priorität
* Queue
* Service
* Service-Level-Vereinbarung (SLA)
* Besitzer
* Verantwortlicher

Bearbeitbare Werte sind durch eine dezente gepunktete Unterstreichung gekennzeichnet (beim Überfahren und bei Tastaturfokus deutlicher). Beim Überfahren einer bearbeitbaren Zeile erscheint ein abgerundeter Rahmen. Ein Klick auf den Wert (oder *Enter*) ersetzt ihn durch eine Auswahl. Queue und Service bleiben ein Baum, ohne das Tree-View-Icon neben dem Feld. Ein Klick auf die Bezeichnung kopiert den Wert. Der Wertetext kann markiert und kopiert werden. Zeilen, die nicht bearbeitet werden können, haben keinen Rahmen und öffnen keinen Editor. Mehrere Attribute können nacheinander geändert werden, gespeichert wird noch nichts:

* Ein geändertes Feld zeigt einen Punkt hinter der Bezeichnung und einen Rahmen in der Akzentfarbe an der Auswahl. Der Widget-Rahmen bleibt unverändert.
* Zwei Icon-Buttons im Widget-Kopf (verwerfen, speichern) erscheinen links vom Einklapp-Pfeil. Sie bleiben sichtbar, wenn das Widget eingeklappt ist. Es gibt keinen Zähler.
* Das Zurücksetzen-Symbol (oder *Esc*) nimmt die Änderung eines Attributs zurück.
* Der Browser warnt vor dem Verlassen der Seite mit ungespeicherten Änderungen.

Alter, Erstellzeit und Ersteller werden oben angezeigt, danach folgen alle bearbeitbaren Attribute (inklusive Besitzer und Verantwortlicher), damit sie direkt beieinander stehen.

Nach dem Speichern werden nur die geänderten Zeilen aktualisiert (z. B. Status und "Warten bis" oder Service und SLA).

## ACLs

Die möglichen Werte und die Bearbeitbarkeit werden über ACLs für die Frontend-Aktion **AgentTicketFlexEdit** bestimmt:

* ACLs, die auf andere Aktionen eingeschränkt sind (z. B. `AgentTicketNote`), greifen nicht.
* ACLs ohne Einschränkung auf eine Aktion (z. B. nur nach Queue) greifen.
* Eine ACL mit `PossibleNot => { Action => ['AgentTicketFlexEdit'] }` deaktiviert die Inline-Bearbeitung für die passenden Tickets.

Ungespeicherte Änderungen werden wie Formularwerte der klassischen Masken berücksichtigt: ACL-`Properties` prüfen die ungespeicherten Werte, `PropertiesDatabase` das gespeicherte Ticket. Wird ein Attribut geändert, werden die Optionen aller anderen geöffneten Auswahlen neu geladen (z. B. die SLAs eines neu gewählten Services, die Besitzer einer neu gewählten Queue). Ein gewählter Wert, der nicht mehr möglich ist, wird angepasst und kurz hervorgehoben.

Beim Speichern werden zuerst alle Änderungen serverseitig geprüft. Ist eine davon nicht möglich, wird nichts gespeichert und die betroffenen Attribute werden markiert. Andernfalls werden die Änderungen in Abhängigkeitsreihenfolge gespeichert (Queue, Typ, Service, SLA, Status, Priorität, Sperre, Besitzer, Verantwortlicher). Danach wird die Bearbeitbarkeit aller Zeilen neu ermittelt.

## Verhalten

* Typen, Services, SLAs und Verantwortliche stehen nur zur Verfügung, wenn `Ticket::Type`, `Ticket::Service` und `Ticket::Responsible` aktiviert sind.
* Services werden anhand des Kundenbenutzers des Tickets angeboten, SLAs anhand des gewählten Services.
* Beim Wechsel des Services wird ein SLA entfernt, das für den neuen Service nicht gültig ist (außer es wird gleichzeitig ein neues SLA gespeichert). Ohne Service kann nur das leere SLA gewählt werden.
* Beim Sperren wird der Agent Besitzer des Tickets, außer es wird gleichzeitig ein neuer Besitzer gespeichert. Nur der Besitzer kann ein Ticket entsperren.
* Beim Schließen wird das Ticket entsperrt.
* Die Standard-Wartezeit kommt aus `Ticket::Frontend::PendingDiffTime`.
* Verliert der Agent den Zugriff auf das Ticket (z. B. nach dem Verschieben), wird er zur Übersicht weitergeleitet.

## Konfiguration

| Einstellung | Standard | Beschreibung |
|---|---|---|
| `Ticket::Frontend::AgentTicketFlexEdit###Enabled` | 1 | Aktiviert die Funktion global. |
| `Ticket::Frontend::AgentTicketFlexEdit###Fields` | alle aktiv | Attribute, die inline bearbeitet werden können. |
| `Ticket::Frontend::AgentTicketFlexEdit###Permission` | priority, move_into, lock, owner, responsible, rw | Benötigte Ticket-Berechtigung je Attribut. |
| `Ticket::Frontend::AgentTicketFlexEdit###StateType` | open, closed, pending reminder, pending auto | Auswählbare Status-Typen. |
| `PreferencesGroups###FlexEdit` | Ja | Agenten können die Inline-Bearbeitung in ihren Einstellungen (Verschiedenes) deaktivieren. |
| `Ticket::Frontend::AgentTicketZoom###Widgets###0100-TicketInformation` | `TicketInformationFlexEdit` | Ersetzt das Modul des Widgets Ticket-Information. Ort bleibt `Sidebar`. |

## Einschränkungen

* Artikelliste, Historie und Ticket-Menü werden nach einer Inline-Änderung nicht aktualisiert.
* Beim Ändern von Besitzer oder Verantwortlichem wird keine Notiz erstellt.
* `RequiredLock` der klassischen Masken wird nicht angewendet.
* Die Anordnung der Attribute im Widget Ticket-Information ist auch bei deaktivierter Inline-Bearbeitung geändert.
* Das Paket ersetzt das Widget Ticket-Information über `Ticket::Frontend::AgentTicketZoom###Widgets###0100-TicketInformation` durch `TicketInformationFlexEdit`. Ein späteres Paket, das denselben Widget-Schlüssel setzt, ersetzt dieses Modul.
