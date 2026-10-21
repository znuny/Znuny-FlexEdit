# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::SLA;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base::Service);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::SLA - Inline editing of the ticket SLA.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<SLA>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'SLA';
}

=head2 GetOrder()

Returns 40.

    my $Order = $FieldObject->GetOrder();

After Service (30) and Queue (10). The SLA write reads ServiceID and QueueID
from the ticket. Written earlier, the SLA would be checked against the old
service, and the service write could remove it afterwards. The full list and
the reason for every number are documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 40;
}

=head2 GetValueKey()

Returns the ticket attribute C<SLAID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'SLAID';
}

=head2 IsFeatureEnabled()

Returns true when services are enabled in SysConfig. The SLA field uses the same switch.

    my $Enabled = $FieldObject->IsFeatureEnabled();

=cut

sub IsFeatureEnabled {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return $ConfigObject->Get('Ticket::Service') ? 1 : 0;
}

=head2 GetPossibleValues()

Returns the SLAs for the effective service and queue, plus an empty value.
The list is filtered by ACLs. Without a service the list is only the empty value.

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Values;
    if ( $Param{Value}->{Service} ) {
        %Values = $TicketObject->TicketSLAList(
            %{ $Param{Common} },
            QueueID        => $Param{Value}->{Queue},
            ServiceID      => $Param{Value}->{Service},
            CustomerUserID => $Self->_GetServiceCustomerUserID(
                Ticket => $Param{Ticket},
            ),
        );
    }
    $Values{''} = '-';

    return %Values;
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the SLA for the service and queue currently stored on the ticket.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 2,
        Ticket   => \%Ticket,
        Action   => 'AgentTicketFlexEdit',
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return $TicketObject->TicketSLASet(
        TicketID       => $Param{TicketID},
        UserID         => $Param{UserID},
        SLAID          => $Param{Value},
        ServiceID      => $Param{Ticket}->{ServiceID},
        QueueID        => $Param{Ticket}->{QueueID},
        CustomerUserID => $Self->_GetServiceCustomerUserID(
            Ticket => $Param{Ticket},
        ),
        Action => $Param{Action},
    );
}

1;
