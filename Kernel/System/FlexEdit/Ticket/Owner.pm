# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Owner;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base::User);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Owner - Inline editing of the ticket owner.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Owner>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Owner';
}

=head2 GetOrder()

Returns 80.

    my $Order = $FieldObject->GetOrder();

After Lock (70). Lock may have set the owner to the current agent. This write
replaces that owner when the agent picked one. The owner list depends on the
queue group, and Queue (10) is already stored. The full list and the reason
for every number are documented in L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 80;
}

=head2 GetValueKey()

Returns the ticket attribute C<OwnerID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'OwnerID';
}

=head2 GetPossibleValues()

Returns the agents who may become owner of the effective queue, filtered by ACLs.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    return $Self->_GetUserList(
        %{ $Param{Common} },
        Field   => $Self->GetName(),
        QueueID => $Param{Value}->{Queue},
    );
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the owner.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 1,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketOwnerSet(
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        NewUserID => $Param{Value},
    );
}

1;
