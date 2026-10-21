# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Base;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::FlexEdit::Ticket::Base - Shared behavior for inline-editable ticket attributes.

=head1 DESCRIPTION

A field module implements C<GetName()>, C<GetOrder()>, C<GetValueKey()>, C<GetPossibleValues()>
and C<_SetValue()>. This base supplies the defaults: the feature is enabled, every agent who
passes the ticket permission may edit the field, the ACL parameter equals the value key, and
C<SetValue()> does nothing when the ticket already has the given value.

C<GetPossibleValues()> returns a flat list (not a hash reference).

The meaning of every C<GetOrder()> value is documented on L</GetOrder()>.

=head1 PUBLIC INTERFACE

=head2 new()

    my $FieldObject = $Kernel::OM->Create('Kernel::System::FlexEdit::Ticket::Priority');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 GetOrder()

Returns the apply order of this field. Field modules override this method.
C<Kernel::System::FlexEdit> sorts by this number before it lists fields and
before C<SetFields()> writes them. After every write the ticket is read
again, so a later field sees the values stored by the earlier fields.
Numbers go in steps of 10 so a new field can be inserted without renumbering
the others. This base returns an empty list. C<Kernel::System::FlexEdit> loads
every C<*.pm> file directly in C<Kernel/System/FlexEdit/Ticket> except C<Base.pm>.
Modules under C<Base/> are further parent classes and are not loaded as fields.

    my $Order = $FieldObject->GetOrder();

=over

=item 10 Queue

First. Queue depends on no other FlexEdit field. Type, Service, SLA, Owner
and Responsible are stored against the queue, so the new QueueID must already
be on the ticket when they run.

=item 20 Type

Directly after Queue. The possible types depend on the queue. Type changes
no service, SLA, state, lock or owner, so it is written before Service.

=item 30 Service

After Queue, because a service belongs to a queue and the service write uses
the QueueID of the fresh ticket. Before SLA. A new service drops an SLA that
does not belong to it, unless the same save also sets an SLA.

=item 40 SLA

After Service and Queue. The SLA write reads ServiceID and QueueID from the
ticket. Written earlier, the SLA would be checked against the old service,
and the service write could remove it afterwards.

=item 50 State

After Queue, Type, Service and SLA, and before Lock. Closing a ticket
unlocks it, unless Lock is part of the same save. Lock runs next, so an
explicit lock in that save is stored after the unlock and wins.

=item 60 Priority

No FlexEdit field depends on the priority, and the priority depends on none
of them. It stays between State and Lock, which is the previous apply order.

=item 70 Lock

After State and before Owner. State may have unlocked a closed ticket; this
write stores the lock the agent chose. Locking also makes the current agent
the owner, unless Owner is part of the same save. Owner runs next, so the
chosen owner replaces that automatic owner.

=item 80 Owner

After Lock. Lock may have set the owner to the current agent. This write
replaces that owner when the agent picked one. The owner list depends on
the queue group, and Queue is already stored.

=item 90 Responsible

Last. The responsible list depends on the queue, which is already stored.
There is no write dependency on Owner. It stays last so a new field can
take a free number in front of it.

=back

=cut

sub GetOrder {
    return;
}

=head2 IsFeatureEnabled()

Returns true if the ticket feature behind this field is switched on.

    my $Enabled = $FieldObject->IsFeatureEnabled();

=cut

sub IsFeatureEnabled {
    return 1;
}

=head2 IsEditable()

Returns true if this field may be edited for the given ticket.
The ticket permission check stays in C<Kernel::System::FlexEdit>.

    my $Editable = $FieldObject->IsEditable(
        Ticket => \%Ticket,
        UserID => 123,
    );

=cut

sub IsEditable {
    return 1;
}

=head2 GetACLParam()

Returns the ACL form parameter for a pending value of this field.
An empty string means the field has no ACL parameter.

    my $ACLParam = $FieldObject->GetACLParam();

=cut

sub GetACLParam {
    my ($Self) = @_;

    return $Self->GetValueKey();
}

=head2 IsUnchanged()

Returns true if the given value equals the value stored on the ticket.

    my $Unchanged = $FieldObject->IsUnchanged(
        Ticket => \%Ticket,
        Value  => 3,
    );

=cut

sub IsUnchanged {
    my ( $Self, %Param ) = @_;

    my $Key = $Self->GetValueKey();

    return ( $Param{Ticket}->{$Key} // '' ) eq ( $Param{Value} // '' ) ? 1 : 0;
}

=head2 GetValidationError()

Returns a translatable error text when the value cannot be stored, or an empty list.

    my $Error = $FieldObject->GetValidationError(
        Value  => 6,
        UserID => 123,
    );

=cut

sub GetValidationError {
    return;
}

=head2 SetValue()

Stores the value. Skips the write when L</IsUnchanged()> is true.

    my $Success = $FieldObject->SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 3,
        Ticket   => \%Ticket,
    );

=cut

sub SetValue {
    my ( $Self, %Param ) = @_;

    return 1 if $Self->IsUnchanged(
        Ticket => $Param{Ticket},
        Value  => $Param{Value},
    );

    return $Self->_SetValue(%Param);
}

1;
