# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Type;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Type - Inline editing of the ticket type.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Type>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Type';
}

=head2 GetOrder()

Returns 20.

    my $Order = $FieldObject->GetOrder();

Directly after Queue (10). The possible types depend on the queue. Type
changes no service, SLA, state, lock or owner, so it is written before
Service (30). The full list and the reason for every number are documented
in L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 20;
}

=head2 GetValueKey()

Returns the ticket attribute C<TypeID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'TypeID';
}

=head2 IsFeatureEnabled()

Returns true when ticket types are enabled in SysConfig.

    my $Enabled = $FieldObject->IsFeatureEnabled();

=cut

sub IsFeatureEnabled {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return $ConfigObject->Get('Ticket::Type') ? 1 : 0;
}

=head2 GetPossibleValues()

Returns the types valid for the effective queue, filtered by ACLs.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketTypeList(
        %{ $Param{Common} },
        QueueID => $Param{Value}->{Queue},
    );
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the type.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 1,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketTypeSet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        TypeID   => $Param{Value},
    );
}

1;
