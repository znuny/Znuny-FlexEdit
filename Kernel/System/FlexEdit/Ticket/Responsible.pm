# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Responsible;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base::User);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Responsible - Inline editing of the ticket responsible.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Responsible>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Responsible';
}

=head2 GetOrder()

Returns 90.

    my $Order = $FieldObject->GetOrder();

Last. The responsible list depends on the queue, which is already stored at
10. There is no write dependency on Owner (80). It stays last so a new field
can take a free number in front of it. The full list and the reason for every
number are documented in L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 90;
}

=head2 GetValueKey()

Returns the ticket attribute C<ResponsibleID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'ResponsibleID';
}

=head2 IsFeatureEnabled()

Returns true when the responsible feature is enabled in SysConfig.

    my $Enabled = $FieldObject->IsFeatureEnabled();

=cut

sub IsFeatureEnabled {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return $ConfigObject->Get('Ticket::Responsible') ? 1 : 0;
}

=head2 GetPossibleValues()

Returns the agents who may become responsible of the effective queue, filtered by ACLs.

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

Stores the responsible.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 1,
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketResponsibleSet(
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        NewUserID => $Param{Value},
    );
}

1;
