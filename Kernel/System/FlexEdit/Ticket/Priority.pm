# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Priority;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Priority - Inline editing of the ticket priority.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Priority>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Priority';
}

=head2 GetOrder()

Returns 60.

    my $Order = $FieldObject->GetOrder();

No FlexEdit field depends on the priority, and the priority depends on none
of them. It stays between State (50) and Lock (70), which is the previous
apply order. The full list and the reason for every number are documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 60;
}

=head2 GetValueKey()

Returns the ticket attribute C<PriorityID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'PriorityID';
}

=head2 GetPossibleValues()

Returns the priorities the agent may set, filtered by ACLs.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketPriorityList( %{ $Param{Common} } );
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the priority.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 3,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketPrioritySet(
        TicketID   => $Param{TicketID},
        UserID     => $Param{UserID},
        PriorityID => $Param{Value},
    );
}

1;
