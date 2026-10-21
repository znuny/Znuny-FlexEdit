# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Queue;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Queue - Inline editing of the ticket queue.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Queue>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Queue';
}

=head2 GetOrder()

Returns 10.

    my $Order = $FieldObject->GetOrder();

Queue is first. It depends on no other FlexEdit field. Type, Service, SLA,
Owner and Responsible are stored against the queue, so the new QueueID must
already be on the ticket when they run. The full list and the reason for
every number are documented in L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 10;
}

=head2 GetValueKey()

Returns the ticket attribute C<QueueID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'QueueID';
}

=head2 GetPossibleValues()

Returns the queues the agent may move the ticket into, filtered by ACLs.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketMoveList(
        %{ $Param{Common} },
        Type => 'move_into',
    );
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Moves the ticket into the selected queue.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 2,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketQueueSet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        QueueID  => $Param{Value},
    );
}

1;
