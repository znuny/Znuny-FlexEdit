# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::State;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::DateTime',
    'Kernel::System::State',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::State - Inline editing of the ticket state.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<State>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'State';
}

=head2 GetOrder()

Returns 50.

    my $Order = $FieldObject->GetOrder();

After Queue (10), Type (20), Service (30) and SLA (40), and before Lock (70).
Closing a ticket unlocks it, unless Lock is part of the same save. Lock runs
next, so an explicit lock in that save is stored after the unlock and wins.
The full list and the reason for every number are documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 50;
}

=head2 GetValueKey()

Returns the ticket attribute C<StateID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'StateID';
}

=head2 GetPossibleValues()

Returns the states the agent may set, filtered by ACLs.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketStateList( %{ $Param{Common} } );
}

=head2 IsUnchanged()

Returns true when the state id is unchanged. A ticket that is already pending
is treated as changed, because the pending date may differ while the state stays.

    my $Unchanged = $FieldObject->IsUnchanged(
        Ticket => \%Ticket,
        Value  => 4,
    );

=cut

sub IsUnchanged {
    my ( $Self, %Param ) = @_;

    # A pending state is kept, as its pending date might have changed.
    return 0 if ( $Param{Ticket}->{StateType} // '' ) =~ m{^pending}i;

    return ( $Param{Ticket}->{StateID} // '' ) eq ( $Param{Value} // '' ) ? 1 : 0;
}

=head2 GetValidationError()

Returns an error when the new state is a pending state and the pending date is missing or not in the future.

    my $Error = $FieldObject->GetValidationError(
        Value  => 6,
        Year   => 2026,
        Month  => 10,
        Day    => 19,
        Hour   => 12,
        Minute => 0,
    );

=cut

sub GetValidationError {
    my ( $Self, %Param ) = @_;

    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    my %State = $StateObject->StateGet(
        ID => $Param{Value},
    );
    return if ( $State{TypeName} // '' ) !~ m{^pending}i;
    return if $Self->_IsPendingDateValid(%Param);

    return Translatable('Please enter a valid pending date in the future.');
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the state. For a pending state it also stores the pending time.
Closing a locked ticket unlocks it, unless Lock is part of the same save.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 2,
        Ticket   => \%Ticket,
        Changes  => {},
        Year     => 2026,
        Month    => 10,
        Day      => 19,
        Hour     => 12,
        Minute   => 0,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = %{ $Param{Ticket} };
    my %State  = $StateObject->StateGet(
        ID => $Param{Value},
    );
    my $StateType = $State{TypeName} // '';

    my $Success = 1;
    if ( $Param{Value} ne $Ticket{StateID} ) {
        $Success = $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $Param{Value},
            UserID   => $Param{UserID},
        );
    }
    return if !$Success;

    if ( $StateType =~ m{^pending}i ) {
        return $TicketObject->TicketPendingTimeSet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
            Year     => $Param{Year},
            Month    => $Param{Month},
            Day      => $Param{Day},
            Hour     => $Param{Hour},
            Minute   => $Param{Minute},
        );
    }

    # Unlock on close (same as the classic screens), unless the lock is part of the change set.
    if ( $StateType =~ m{^close}i && $Ticket{Lock} eq 'lock' && !exists $Param{Changes}->{Lock} ) {
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    }

    return 1;
}

=head2 _IsPendingDateValid()

Returns true if year, month, day, hour and minute are set and the resulting time is in the future.

    my $Valid = $FieldObject->_IsPendingDateValid(
        Year   => 2026,
        Month  => 10,
        Day    => 19,
        Hour   => 12,
        Minute => 0,
    );

=cut

sub _IsPendingDateValid {
    my ( $Self, %Param ) = @_;

    for my $Key (qw(Year Month Day Hour Minute)) {
        return if !defined $Param{$Key} || $Param{$Key} eq '';
    }

    my $PendingDateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            Year   => $Param{Year},
            Month  => $Param{Month},
            Day    => $Param{Day},
            Hour   => $Param{Hour},
            Minute => $Param{Minute},
            Second => 0,
        },
    );
    my $CurrentDateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');

    return if !$PendingDateTimeObject;
    return if $PendingDateTimeObject < $CurrentDateTimeObject;

    return 1;
}

1;
