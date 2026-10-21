# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Service;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base::Service);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Service - Inline editing of the ticket service.

=head1 PUBLIC INTERFACE

=head2 GetName()

Returns the field name C<Service>.

    my $Name = $FieldObject->GetName();

=cut

sub GetName {
    return 'Service';
}

=head2 GetOrder()

Returns 30.

    my $Order = $FieldObject->GetOrder();

After Queue (10), because a service belongs to a queue and the service write
uses the QueueID of the fresh ticket. Before SLA (40). A new service drops
an SLA that does not belong to it, unless the same save also sets an SLA.
The full list and the reason for every number are documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

=cut

sub GetOrder {
    return 30;
}

=head2 GetValueKey()

Returns the ticket attribute C<ServiceID>.

    my $ValueKey = $FieldObject->GetValueKey();

=cut

sub GetValueKey {
    return 'ServiceID';
}

=head2 IsFeatureEnabled()

Returns true when services are enabled in SysConfig.

    my $Enabled = $FieldObject->IsFeatureEnabled();

=cut

sub IsFeatureEnabled {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return $ConfigObject->Get('Ticket::Service') ? 1 : 0;
}

=head2 GetPossibleValues()

Returns the services for the effective queue and customer user, plus an empty value.
The list is filtered by ACLs.

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
    my $CustomerUserID = $Self->_GetServiceCustomerUserID(
        Ticket => $Param{Ticket},
    );
    if ($CustomerUserID) {
        %Values = $TicketObject->TicketServiceList(
            %{ $Param{Common} },
            QueueID        => $Param{Value}->{Queue},
            CustomerUserID => $CustomerUserID,
        );
    }
    $Values{''} = '-';

    return %Values;
}

=head1 INTERNAL INTERFACE

=head2 _SetValue()

Stores the service. Removes the current SLA when it is no longer valid for the
new service, unless the same save also sets an SLA.

    my $Success = $FieldObject->_SetValue(
        TicketID => 123,
        UserID   => 123,
        Value    => 4,
        Ticket   => \%Ticket,
        Changes  => {},
        Action   => 'AgentTicketFlexEdit',
    );

=cut

sub _SetValue {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket         = %{ $Param{Ticket} };
    my $CustomerUserID = $Self->_GetServiceCustomerUserID(
        Ticket => \%Ticket,
    );

    my $Success = $TicketObject->TicketServiceSet(
        TicketID       => $Param{TicketID},
        UserID         => $Param{UserID},
        ServiceID      => $Param{Value},
        QueueID        => $Ticket{QueueID},
        CustomerUserID => $CustomerUserID,
        Action         => $Param{Action},
    );
    return if !$Success;

    # Remove the SLA if it is not valid for the new service anymore
    # (unless a new SLA is part of the same change set).
    return 1 if !$Ticket{SLAID} || exists $Param{Changes}->{SLA};

    my %SLAs;
    if ( $Param{Value} ) {
        %SLAs = $TicketObject->TicketSLAList(
            TicketID       => $Param{TicketID},
            UserID         => $Param{UserID},
            QueueID        => $Ticket{QueueID},
            ServiceID      => $Param{Value},
            CustomerUserID => $CustomerUserID,
            Action         => $Param{Action},
        );
    }
    if ( !$SLAs{ $Ticket{SLAID} } ) {
        $TicketObject->TicketSLASet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
            SLAID    => '',
        );
    }

    return 1;
}

1;
