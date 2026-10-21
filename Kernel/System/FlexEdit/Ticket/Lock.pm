# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Lock;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Lock - Inline editing of the ticket lock.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Lock>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Lock';
}

=head2 GetOrder()

Returns 70.

    my $Order = $FieldObject->GetOrder();

After State (50) and before Owner (80). State may have unlocked a closed
ticket; this write stores the lock the agent chose. Locking also makes the
current agent the owner, unless Owner is part of the same save. Owner runs
next, so the chosen owner replaces that automatic owner. The full list and
the reason for every number are documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 70;
}

=head2 GetValueKey()

Returns the ticket attribute C<Lock>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'Lock';
}

=head2 GetACLParam()

Returns an empty string. Lock has no ACL form parameter.

    my $ACLParam = $FieldObject->GetACLParam();

=cut

sub GetACLParam {
    return '';
}

=head2 IsEditable()

Returns false when the ticket is locked and the agent is not the owner.
Only the owner may unlock a locked ticket (same as AgentTicketLock).

    my $Editable = $FieldObject->IsEditable(
        Ticket => \%Ticket,
        UserID => 123,
    );

=cut

sub IsEditable {
    my ( $Self, %Param ) = @_;

    # Only the owner may unlock a locked ticket (same as AgentTicketLock).
    return 0 if $Param{Ticket}->{Lock} eq 'lock' && $Param{Ticket}->{OwnerID} != $Param{UserID};

    return 1;
}

=head2 GetPossibleValues()

Returns C<lock> and C<unlock>.

    my %Values = $FieldObject->GetPossibleValues();

=cut

sub GetPossibleValues {
    return (
        lock   => 'lock',
        unlock => 'unlock',
    );
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the lock. Locking makes the current agent the owner, unless Owner is part of the same save.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 'lock',
        Ticket   => \%Ticket,
        Changes  => {},
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = %{ $Param{Ticket} };

    my $Success = $TicketObject->TicketLockSet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Lock     => $Param{Value},
    );
    return if !$Success;

    # Locking makes the agent the owner (same as AgentTicketLock),
    # unless a new owner is part of the same change set.
    if (
        $Param{Value} eq 'lock'
        && $Ticket{OwnerID} != $Param{UserID}
        && !exists $Param{Changes}->{Owner}
        )
    {
        return $TicketObject->TicketOwnerSet(
            TicketID  => $Param{TicketID},
            UserID    => $Param{UserID},
            NewUserID => $Param{UserID},
        );
    }

    return 1;
}

1;
