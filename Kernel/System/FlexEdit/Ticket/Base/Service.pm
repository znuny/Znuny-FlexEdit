# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Base::Service;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::Config',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Base::Service - Shared behavior for service and SLA fields.

=head1 DESCRIPTION

Parent of the Service and SLA field modules. Supplies the customer user ID
those fields pass to service and SLA lookups. All other defaults come from
L<Kernel::System::FlexEdit::Ticket::Base>.

This module is not a field. C<Kernel::System::FlexEdit> only loads C<*.pm>
files directly in C<Kernel/System/FlexEdit/Ticket>.

=head1 INTERNAL INTERFACE

=head2 _GetServiceCustomerUserID()

Returns the customer user ID used to look up services and SLAs (see AgentTicketActionCommon).

    my $CustomerUserID = $FieldObject->_GetServiceCustomerUserID(
        Ticket => \%Ticket,
    );

=cut

sub _GetServiceCustomerUserID {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $CustomerUserID = $Param{Ticket}->{CustomerUserID} // '';
    if ( !$CustomerUserID && $ConfigObject->Get('Ticket::Service::Default::UnknownCustomer') ) {
        $CustomerUserID = '<DEFAULT>';
    }

    return $CustomerUserID;
}

1;
