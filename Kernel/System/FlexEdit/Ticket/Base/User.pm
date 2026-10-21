# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit::Ticket::Base::User;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::FlexEdit::Ticket::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Group',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::FlexEdit::Ticket::Base::User - Shared behavior for owner and responsible fields.

=head1 DESCRIPTION

Parent of the Owner and Responsible field modules. Supplies the agent list
those fields show, filtered by queue group permission and ACLs. All other
defaults come from L<Kernel::System::FlexEdit::Ticket::Base>.

This module is not a field. C<Kernel::System::FlexEdit> only loads C<*.pm>
files directly in C<Kernel/System/FlexEdit/Ticket>.

=head1 INTERNAL INTERFACE

=head2 _GetUserList()

Returns possible owners or responsibles (see AgentTicketActionCommon), filtered by ACLs.

    my %Users = $FieldObject->_GetUserList(
        TicketID => 123,
        UserID   => 123,
        Field    => 'Owner',
        QueueID  => 1,
    );

=cut

sub _GetUserList {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    my $PermissionType = $Param{Field} eq 'Owner' ? 'owner'    : 'responsible';
    my $ReturnSubType  = $Param{Field} eq 'Owner' ? 'NewOwner' : 'NewResponsible';

    my %AllUsers = $UserObject->UserList(
        Type  => 'Short',
        Valid => 1,
    );

    my %ShownUsers;
    if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ShownUsers = %AllUsers;
    }
    else {
        my $GroupID = $QueueObject->GetQueueGroupID(
            QueueID => $Param{QueueID},
        );
        my %MemberList = $GroupObject->PermissionGroupGet(
            GroupID => $GroupID,
            Type    => $PermissionType,
        );
        USERID:
        for my $UserID ( sort keys %MemberList ) {
            next USERID if !$AllUsers{$UserID};
            $ShownUsers{$UserID} = $AllUsers{$UserID};
        }
    }

    my %ACLParam = %Param;
    delete @ACLParam{qw(Field)};

    my $ACL = $TicketObject->TicketAcl(
        %ACLParam,
        ReturnType    => 'Ticket',
        ReturnSubType => $ReturnSubType,
        Data          => \%ShownUsers,
    );
    if ($ACL) {
        %ShownUsers = $TicketObject->TicketAclData();
    }

    my %FullNames = $UserObject->UserList(
        Type  => 'Long',
        Valid => 1,
    );
    @ShownUsers{ keys %ShownUsers } = @FullNames{ keys %ShownUsers };

    return %ShownUsers;
}

1;
