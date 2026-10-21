# Functionality

Agents can edit the following ticket attributes directly in the **Ticket Information** widget of the ticket zoom screen, without opening a popup:

* Type
* State (including the pending date for pending states)
* Lock
* Priority
* Queue
* Service
* Service Level Agreement
* Owner
* Responsible

Editable values are marked with a faint dotted underline (stronger on hover and keyboard focus). Hovering an editable row shows a rounded border. Click the value (or press *Enter*) to replace it by a selection. Queue and Service stay a tree, without the tree-view icon beside the field. Click the label to copy the value. The value text can be selected and copied. Rows that cannot be edited have no border and do not open an editor. Several attributes can be changed one after another; nothing is saved yet:

* A changed field shows a dot after its label and an accent-colored border on the selection. The widget frame stays unchanged.
* Two icon buttons in the widget header (discard, save) appear to the left of the collapse arrow. They stay visible when the widget is collapsed. There is no change counter.
* The reset icon (or *Esc*) reverts a single attribute.
* The browser warns before leaving the page with unsaved changes.

Age, creation time and creator are shown at the top, followed by all editable attributes (including owner and responsible), so that they are next to each other.

After saving, only the changed rows are refreshed (for example State and "Pending till", or Service and SLA).

## ACLs

Possible values and the editability are determined by ACLs for the frontend action **AgentTicketFlexEdit**:

* ACLs restricted to other actions (e.g. `AgentTicketNote`) are not applied.
* ACLs without an action restriction (e.g. only by queue) are applied.
* An ACL with `PossibleNot => { Action => ['AgentTicketFlexEdit'] }` disables inline editing for the matching tickets.

Unsaved changes are taken into account like form values in the classic screens: ACL `Properties` match the unsaved values, `PropertiesDatabase` match the stored ticket. When an attribute is changed, the options of all other open selections are reloaded (e.g. the SLAs of a newly selected service, owners of a newly selected queue). A selected value that is no longer possible is adjusted and briefly highlighted.

On saving, all changes are validated on the server first. If one of them is not possible, nothing is saved and the affected attributes are marked. Otherwise the changes are applied in dependency order (queue, type, service, SLA, state, priority, lock, owner, responsible). After saving, the editability of all rows is evaluated again.

## Behavior

* Types, services, SLAs and responsibles are only available if `Ticket::Type`, `Ticket::Service` and `Ticket::Responsible` are enabled.
* Services are offered based on the ticket's customer user; SLAs based on the selected service.
* Changing the service removes an SLA that is not valid for the new service (unless a new SLA is saved at the same time). Without a service only the empty SLA can be selected.
* Locking a ticket makes the agent its owner, unless a new owner is saved at the same time. Only the owner can unlock a ticket.
* Closing a ticket unlocks it.
* The default pending time is taken from `Ticket::Frontend::PendingDiffTime`.
* If the agent loses access to the ticket (e.g. after moving it), the agent is redirected to the overview.

## Configuration

| Setting | Default | Description |
|---|---|---|
| `Ticket::Frontend::AgentTicketFlexEdit###Enabled` | 1 | Enables the feature globally. |
| `Ticket::Frontend::AgentTicketFlexEdit###Fields` | all enabled | Attributes that can be edited inline. |
| `Ticket::Frontend::AgentTicketFlexEdit###Permission` | priority, move_into, lock, owner, responsible, rw | Ticket permission needed per attribute. |
| `Ticket::Frontend::AgentTicketFlexEdit###StateType` | open, closed, pending reminder, pending auto | State types that can be selected. |
| `PreferencesGroups###FlexEdit` | Yes | Agents can disable inline editing in their preferences (Miscellaneous). |
| `Ticket::Frontend::AgentTicketZoom###Widgets###0100-TicketInformation` | `TicketInformationFlexEdit` | Replaces the ticket information widget module. Location stays `Sidebar`. |

## Limitations

* The article list, the history and the ticket menu are not refreshed after an inline change.
* Changing owner or responsible does not create a note.
* `RequiredLock` of the classic screens is not applied.
* The layout of the ticket information widget (order of the attributes) is changed also if inline editing is disabled.
* The package replaces the ticket information widget via `Ticket::Frontend::AgentTicketZoom###Widgets###0100-TicketInformation` with `TicketInformationFlexEdit`. A later package that sets the same widget key replaces this module.
