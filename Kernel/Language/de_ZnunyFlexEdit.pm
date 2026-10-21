# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_ZnunyFlexEdit;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    # Perl module
    $Self->{Translation}->{'Need Field, TicketID and UserID!'}      = 'Field, TicketID und UserID werden benötigt!';
    $Self->{Translation}->{'Need TicketID and a valid Field!'}      = 'TicketID und ein gültiges Feld werden benötigt!';
    $Self->{Translation}->{'You are not allowed to change this field.'} = 'Sie dürfen dieses Feld nicht ändern.';
    $Self->{Translation}->{'The selected value is not possible.'}   = 'Der ausgewählte Wert ist nicht möglich.';
    $Self->{Translation}->{'The field could not be updated.'}       = 'Das Feld konnte nicht aktualisiert werden.';
    $Self->{Translation}->{'Please enter a valid pending date in the future.'}
        = 'Bitte geben Sie ein gültiges Datum in der Zukunft für "Warten bis" an.';
    $Self->{Translation}->{'Invalid Subaction.'} = 'Ungültige Subaction.';

    # SysConfig
    $Self->{Translation}->{'Inline Editing'} = 'Inline-Bearbeitung';
    $Self->{Translation}->{'Inline editing'} = 'Inline-Bearbeitung';
    $Self->{Translation}->{'Inline editing of ticket attributes.'} = 'Inline-Bearbeitung von Ticket-Attributen.';
    $Self->{Translation}->{'Edit ticket attributes directly in the ticket information widget of the ticket zoom screen.'}
        = 'Ticket-Attribute direkt im Widget "Ticket-Information" der Ticket-Zoom-Ansicht bearbeiten.';
    $Self->{Translation}->{'Enables inline editing of ticket attributes in the ticket information widget of the ticket zoom screen. Agents can disable it in their personal preferences.'}
        = 'Aktiviert die Inline-Bearbeitung von Ticket-Attributen im Widget "Ticket-Information" der Ticket-Zoom-Ansicht. Agenten können sie in ihren persönlichen Einstellungen deaktivieren.';
    $Self->{Translation}->{'Defines which ticket attributes can be edited inline in the ticket information widget (0 = disabled, 1 = enabled).'}
        = 'Legt fest, welche Ticket-Attribute im Widget "Ticket-Information" inline bearbeitet werden können (0 = deaktiviert, 1 = aktiviert).';
    $Self->{Translation}->{'Defines the ticket permission an agent needs to edit an attribute inline.'}
        = 'Legt die Ticket-Berechtigung fest, die ein Agent zur Inline-Bearbeitung eines Attributs benötigt.';
    $Self->{Translation}->{'Defines the state types that can be selected when editing the state inline.'}
        = 'Legt die Status-Typen fest, die bei der Inline-Bearbeitung des Status auswählbar sind.';
    $Self->{Translation}->{'Gives agents the possibility to disable inline editing of ticket attributes in the ticket zoom screen.'}
        = 'Ermöglicht Agenten, die Inline-Bearbeitung von Ticket-Attributen in der Ticket-Zoom-Ansicht zu deaktivieren.';
    $Self->{Translation}->{'Frontend module registration for the inline editing of ticket attributes in the agent interface.'}
        = 'Frontend-Modul-Registrierung für die Inline-Bearbeitung von Ticket-Attributen im Agenten-Interface.';
    $Self->{Translation}->{'Loader module registration for the inline editing of ticket attributes in the ticket zoom screen.'}
        = 'Loader-Modul-Registrierung für die Inline-Bearbeitung von Ticket-Attributen in der Ticket-Zoom-Ansicht.';

    # Templates
    $Self->{Translation}->{'Unsaved changes'}  = 'Ungespeicherte Änderungen';
    $Self->{Translation}->{'Save changes'}     = 'Änderungen speichern';
    $Self->{Translation}->{'Discard changes'}  = 'Änderungen verwerfen';
    $Self->{Translation}->{'Discard'}          = 'Verwerfen';
    $Self->{Translation}->{'Reset field'}      = 'Feld zurücksetzen';
    $Self->{Translation}->{'Undo change'}      = 'Änderung zurücknehmen';
    $Self->{Translation}->{'(changed)'}        = '(geändert)';
    $Self->{Translation}->{'Copy'}             = 'Kopieren';
    $Self->{Translation}->{'Copied to clipboard!'} = 'In die Zwischenablage kopiert!';
    $Self->{Translation}->{'Need TicketID!'}   = 'TicketID wird benötigt!';
    $Self->{Translation}->{'Need TicketID and UserID!'} = 'TicketID und UserID werden benötigt!';

    # JavaScript
    $Self->{Translation}->{'The following changes could not be saved:'}
        = 'Die folgenden Änderungen konnten nicht gespeichert werden:';

    $Self->{JavaScriptStrings} //= [];
    push @{ $Self->{JavaScriptStrings} }, (
        'The following changes could not be saved:',
        '(changed)',
        'Copy',
        'Copied to clipboard!',
    );

    return 1;
}

1;
