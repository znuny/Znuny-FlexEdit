# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {},
);

# Enable the optional ticket features, so all fields can be tested.
for my $Feature (qw(Ticket::Type Ticket::Service Ticket::Responsible)) {
    $HelperObject->ConfigSettingChange(
        Valid => 1,
        Key   => $Feature,
        Value => 1,
    );
}
$HelperObject->ConfigSettingChange(
    Valid => 1,
    Key   => 'Ticket::Service::Default::UnknownCustomer',
    Value => 0,
);

my ( $UserLogin, $UserID ) = $HelperObject->TestUserCreate(
    Groups => [ 'admin', 'users' ],
);

my $TicketID = $TicketObject->TicketCreate(
    Title        => 'FlexEdit test ticket',
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'open',
    CustomerNo   => '123465',
    CustomerUser => 'customer@example.com',
    OwnerID      => $UserID,
    UserID       => 1,
);
$Self->True( $TicketID, 'Ticket created.' );

# Global and user switch.
$Self->True( $FlexEditObject->IsActive( UserID => $UserID ), 'Active by default.' );

my %Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->True( $Editable{Priority}, 'Priority is editable.' );
$Self->True( $Editable{Queue},    'Queue is editable.' );

$UserObject->SetPreferences(
    Key    => 'UserFlexEditEnabled',
    Value  => 0,
    UserID => $UserID,
);
$Self->False( $FlexEditObject->IsActive( UserID => $UserID ), 'Disabled by user preference.' );
%Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->Is( scalar keys %Editable, 0, 'Nothing editable if disabled by user preference.' );

$UserObject->SetPreferences(
    Key    => 'UserFlexEditEnabled',
    Value  => 1,
    UserID => $UserID,
);

my %Fields = %{ $ConfigObject->Get('Ticket::Frontend::AgentTicketFlexEdit')->{Fields} };
$HelperObject->ConfigSettingChange(
    Key   => 'Ticket::Frontend::AgentTicketFlexEdit###Enabled',
    Value => 0,
);
$Self->False( $FlexEditObject->IsActive( UserID => $UserID ), 'Disabled globally.' );
$HelperObject->ConfigSettingChange(
    Key   => 'Ticket::Frontend::AgentTicketFlexEdit###Enabled',
    Value => 1,
);

# Field list.
$HelperObject->ConfigSettingChange(
    Key   => 'Ticket::Frontend::AgentTicketFlexEdit###Fields',
    Value => { %Fields, Priority => 0 },
);
%Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->False( $Editable{Priority}, 'Priority not editable if disabled in field list.' );
$HelperObject->ConfigSettingChange(
    Key   => 'Ticket::Frontend::AgentTicketFlexEdit###Fields',
    Value => \%Fields,
);

# ACLs: action filter AgentTicketNote must not match, queue filter must match.
my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
my $PriorityID     = $PriorityObject->PriorityLookup( Priority => '5 very high' );

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {
        'FlexEdit-Test-Note' => {
            Properties => {
                Frontend => { Action => ['AgentTicketNote'] },
            },
            PossibleNot => {
                Ticket => { Priority => ['1 very low'] },
            },
        },
        'FlexEdit-Test-Queue' => {
            Properties => {
                Queue => { Name => ['Raw'] },
            },
            PossibleNot => {
                Ticket => { Priority => ['5 very high'] },
            },
        },
    },
);

my $Values = $FlexEditObject->GetPossibleValues(
    Field    => 'Priority',
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->True( ( grep { $_ eq '1 very low' } values %{$Values} ) ? 1 : 0, 'ACL for AgentTicketNote is ignored.' );
$Self->False( $Values->{$PriorityID}, 'ACL without action filter (queue) is applied.' );

my $Result = $FlexEditObject->SetField(
    Field    => 'Priority',
    Value    => $PriorityID,
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Value forbidden by ACL is rejected.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Priority',
    Value    => 4,
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Allowed value is set.' . ( $Result->{Error} ? " ($Result->{Error})" : '' ) );
my %Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->Is( $Ticket{PriorityID}, 4, 'Priority updated.' );

# ACL denying the whole action.
$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {
        'FlexEdit-Test-Action' => {
            Properties => {
                Queue => { Name => ['Raw'] },
            },
            PossibleNot => {
                Action => ['AgentTicketFlexEdit'],
            },
        },
    },
);
%Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->Is( scalar keys %Editable, 0, 'Nothing editable if ACL denies AgentTicketFlexEdit.' );

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {},
);

# Pending state needs a date in the future.
my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
my $PendingStateID = $StateObject->StateLookup( State => 'pending reminder' );
$Result = $FlexEditObject->SetField(
    Field    => 'State',
    Value    => $PendingStateID,
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Pending state without date is rejected.' );

my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
$DateTimeObject->Add( Days => 2 );
my $DateTime = $DateTimeObject->Get();

$Result = $FlexEditObject->SetField(
    Field    => 'State',
    Value    => $PendingStateID,
    TicketID => $TicketID,
    UserID   => $UserID,
    Year     => $DateTime->{Year},
    Month    => $DateTime->{Month},
    Day      => $DateTime->{Day},
    Hour     => $DateTime->{Hour},
    Minute   => $DateTime->{Minute},
);
$Self->True( $Result->{Success}, 'Pending state with date is set.' );
%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->Is( $Ticket{State}, 'pending reminder', 'State updated.' );
$Self->True( $Ticket{UntilTime} > 0, 'Pending time set.' );

# Lock makes the agent owner.
$Result = $FlexEditObject->SetField(
    Field    => 'Lock',
    Value    => 'lock',
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Ticket locked.' );

# Invalid value.
$Result = $FlexEditObject->SetField(
    Field    => 'Queue',
    Value    => 999999,
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Unknown queue is rejected.' );

#
# Optional ticket features: field list follows the core switches.
#
my @FieldList = $FlexEditObject->ListFields();
for my $Field (qw(Type Service SLA Responsible)) {
    $Self->True(
        ( grep { $_ eq $Field } @FieldList ) ? 1 : 0,
        "ListFields contains $Field if the feature is enabled."
    );
}

for my $Feature (qw(Ticket::Type Ticket::Service Ticket::Responsible)) {
    $HelperObject->ConfigSettingChange(
        Valid => 1,
        Key   => $Feature,
        Value => 0,
    );
}
my %FieldListDisabled = map { $_ => 1 } $FlexEditObject->ListFields();
for my $Field (qw(Type Service SLA Responsible)) {
    $Self->False(
        $FieldListDisabled{$Field} ? 1 : 0,
        "ListFields does not contain $Field if the feature is disabled."
    );
}
for my $Feature (qw(Ticket::Type Ticket::Service Ticket::Responsible)) {
    $HelperObject->ConfigSettingChange(
        Valid => 1,
        Key   => $Feature,
        Value => 1,
    );
}

#
# Test data for Type, Service, SLA and Responsible.
#
my $TypeObject         = $Kernel::OM->Get('Kernel::System::Type');
my $ServiceObject      = $Kernel::OM->Get('Kernel::System::Service');
my $SLAObject          = $Kernel::OM->Get('Kernel::System::SLA');
my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

my $RandomID = $HelperObject->GetRandomID();

my %TypeIDs;
for my $TypeName (qw(Incident Request Forbidden)) {
    $TypeIDs{$TypeName} = $TypeObject->TypeAdd(
        Name    => "FlexEdit-$TypeName-$RandomID",
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True( $TypeIDs{$TypeName}, "Type $TypeName created." );
}

my $CustomerUserLogin = $HelperObject->TestCustomerUserCreate();
$Self->True( $CustomerUserLogin, 'Customer user created.' );

my %ServiceIDs;
for my $ServiceName (qw(Hardware Software NotAssigned)) {
    $ServiceIDs{$ServiceName} = $ServiceObject->ServiceAdd(
        Name    => "FlexEdit-$ServiceName-$RandomID",
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True( $ServiceIDs{$ServiceName}, "Service $ServiceName created." );
}

# Only Hardware and Software are available for the customer user.
for my $ServiceName (qw(Hardware Software)) {
    $ServiceObject->CustomerUserServiceMemberAdd(
        CustomerUserLogin => $CustomerUserLogin,
        ServiceID         => $ServiceIDs{$ServiceName},
        Active            => 1,
        UserID            => 1,
    );
}

my %SLAIDs;
for my $ServiceName (qw(Hardware Software)) {
    $SLAIDs{$ServiceName} = $SLAObject->SLAAdd(
        ServiceIDs => [ $ServiceIDs{$ServiceName} ],
        Name       => "FlexEdit-SLA-$ServiceName-$RandomID",
        ValidID    => 1,
        UserID     => 1,
    );
    $Self->True( $SLAIDs{$ServiceName}, "SLA for $ServiceName created." );
}

my ( $ResponsibleLogin, $ResponsibleID ) = $HelperObject->TestUserCreate(
    Groups => ['users'],
);
my ( $ForbiddenLogin, $ForbiddenID ) = $HelperObject->TestUserCreate(
    Groups => ['users'],
);

my $TicketID2 = $TicketObject->TicketCreate(
    Title         => 'FlexEdit test ticket 2',
    Queue         => 'Raw',
    Lock          => 'unlock',
    Priority      => '3 normal',
    State         => 'open',
    TypeID        => $TypeIDs{Incident},
    CustomerNo    => 'FlexEdit',
    CustomerUser  => $CustomerUserLogin,
    OwnerID       => $UserID,
    ResponsibleID => $UserID,
    UserID        => 1,
);
$Self->True( $TicketID2, 'Ticket 2 created.' );

%Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
);
for my $Field (qw(Type Service Responsible)) {
    $Self->True( $Editable{$Field}, "$Field is editable." );
}
$Self->True( $Editable{SLA}, 'SLA is editable (together with a service).' );

$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'SLA',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->IsDeeply( [ sort keys %{$Values} ], [''], 'Without a service only the empty SLA is possible.' );

# A pending (not yet saved) service is used for the SLA list.
$Values = $FlexEditObject->GetPossibleValues(
    Field     => 'SLA',
    TicketID  => $TicketID2,
    UserID    => $UserID,
    Overrides => { Service => $ServiceIDs{Software} },
);
$Self->True( $Values->{ $SLAIDs{Software} }, 'SLA of the pending service is possible.' );
$Self->False( $Values->{ $SLAIDs{Hardware} }, 'SLA of another service is not possible for the pending service.' );

#
# Type
#
$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {
        'FlexEdit-Test-Type' => {
            Properties => {
                Queue => { Name => ['Raw'] },
            },
            PossibleNot => {
                Ticket => { Type => ["FlexEdit-Forbidden-$RandomID"] },
            },
        },
    },
);

$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'Type',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Values->{ $TypeIDs{Request} }, 'Type Request is possible.' );
$Self->False( $Values->{ $TypeIDs{Forbidden} }, 'Type Forbidden is removed by ACL.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Type',
    Value    => $TypeIDs{Forbidden},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Type forbidden by ACL is rejected.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Type',
    Value    => $TypeIDs{Request},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Type Request is set.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{TypeID}, $TypeIDs{Request}, 'Type updated.' );

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {},
);

#
# Service and SLA
#
$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'Service',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Values->{ $ServiceIDs{Hardware} }, 'Service Hardware is possible.' );
$Self->True( $Values->{ $ServiceIDs{Software} }, 'Service Software is possible.' );
$Self->False( $Values->{ $ServiceIDs{NotAssigned} }, 'Service not assigned to the customer user is not possible.' );
$Self->True( exists $Values->{''} ? 1 : 0, 'Empty service is possible.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Service',
    Value    => $ServiceIDs{NotAssigned},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Service not assigned to the customer user is rejected.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Service',
    Value    => $ServiceIDs{Hardware},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Service Hardware is set.' );

%Editable = $FlexEditObject->GetEditableFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Editable{SLA}, 'SLA is editable with a service.' );

$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'SLA',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Values->{ $SLAIDs{Hardware} }, 'SLA of service Hardware is possible.' );
$Self->False( $Values->{ $SLAIDs{Software} }, 'SLA of service Software is not possible.' );

$Result = $FlexEditObject->SetField(
    Field    => 'SLA',
    Value    => $SLAIDs{Software},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'SLA of another service is rejected.' );

$Result = $FlexEditObject->SetField(
    Field    => 'SLA',
    Value    => $SLAIDs{Hardware},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'SLA Hardware is set.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{ServiceID}, $ServiceIDs{Hardware}, 'Service updated.' );
$Self->Is( $Ticket{SLAID},     $SLAIDs{Hardware},     'SLA updated.' );

# Changing the service removes the SLA which is not valid anymore.
$Result = $FlexEditObject->SetField(
    Field    => 'Service',
    Value    => $ServiceIDs{Software},
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Service Software is set.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{ServiceID}, $ServiceIDs{Software}, 'Service changed.' );
$Self->False( $Ticket{SLAID}, 'SLA of the previous service removed.' );

# Remove the service.
$Result = $FlexEditObject->SetField(
    Field    => 'Service',
    Value    => '',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Service removed.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->False( $Ticket{ServiceID}, 'Ticket has no service anymore.' );

#
# Responsible
#
$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {
        'FlexEdit-Test-Responsible' => {
            Properties => {
                Queue => { Name => ['Raw'] },
            },
            PossibleNot => {
                Ticket => { NewResponsible => [$ForbiddenLogin] },
            },
        },
    },
);

$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'Responsible',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Values->{$ResponsibleID}, 'Responsible user is possible.' );
$Self->False( $Values->{$ForbiddenID}, 'Responsible user removed by ACL is not possible.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Responsible',
    Value    => $ForbiddenID,
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->False( $Result->{Success}, 'Responsible forbidden by ACL is rejected.' );

$Result = $FlexEditObject->SetField(
    Field    => 'Responsible',
    Value    => $ResponsibleID,
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Result->{Success}, 'Responsible is set.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{ResponsibleID}, $ResponsibleID, 'Responsible updated.' );

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {},
);

#
# Batch changes
#
my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
my $MiscQueueID = $QueueObject->QueueLookup( Queue => 'Misc' );
my $RawQueueID  = $QueueObject->QueueLookup( Queue => 'Raw' );

# Service and SLA of that service in one change set.
$Result = $FlexEditObject->SetFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
    Changes  => {
        Service  => $ServiceIDs{Software},
        SLA      => $SLAIDs{Software},
        Priority => 2,
    },
);
$Self->True( $Result->{Success}, 'Service, SLA and priority set in one change set.' );
$Self->IsDeeply(
    $Result->{Applied},
    [qw(Service SLA Priority)],
    'Changes applied in dependency order.',
);

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{ServiceID},  $ServiceIDs{Software}, 'Batch: service updated.' );
$Self->Is( $Ticket{SLAID},      $SLAIDs{Software},     'Batch: SLA updated.' );
$Self->Is( $Ticket{PriorityID}, 2,                     'Batch: priority updated.' );

# ACL depending on a pending value (form value): queue Misc forbids priority 5.
$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {
        'FlexEdit-Test-PendingQueue' => {
            Properties => {
                Queue => { Name => ['Misc'] },
            },
            PossibleNot => {
                Ticket => { Priority => ['5 very high'] },
            },
        },
    },
);

$Values = $FlexEditObject->GetPossibleValues(
    Field    => 'Priority',
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True( $Values->{$PriorityID}, 'Priority 5 is possible in the saved queue.' );

$Values = $FlexEditObject->GetPossibleValues(
    Field     => 'Priority',
    TicketID  => $TicketID2,
    UserID    => $UserID,
    Overrides => { Queue => $MiscQueueID },
);
$Self->False( $Values->{$PriorityID}, 'Priority 5 is not possible with the pending queue.' );

$Result = $FlexEditObject->SetFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
    Changes  => {
        Queue    => $MiscQueueID,
        Priority => $PriorityID,
    },
);
$Self->False( $Result->{Success}, 'Change set with a value forbidden by the pending queue is rejected.' );
$Self->True( $Result->{Errors}->{Priority} ? 1 : 0, 'Error is reported for priority.' );
$Self->IsDeeply( $Result->{Applied}, [], 'Nothing applied if validation fails.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{QueueID}, $RawQueueID, 'Queue unchanged after failed validation.' );

$HelperObject->ConfigSettingChange(
    Key   => 'TicketAcl',
    Value => {},
);

# Unchanged values are ignored.
$Result = $FlexEditObject->SetFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
    Changes  => {
        Priority => 2,
    },
);
$Self->True( $Result->{Success}, 'Unchanged value is accepted.' );
$Self->IsDeeply( $Result->{Applied}, [], 'Unchanged value is not applied.' );

# Lock together with a new owner: the new owner wins.
$Result = $FlexEditObject->SetFields(
    TicketID => $TicketID2,
    UserID   => $UserID,
    Changes  => {
        Lock  => 'lock',
        Owner => $ResponsibleID,
    },
);
$Self->True( $Result->{Success}, 'Lock and owner set in one change set.' );

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is( $Ticket{Lock},    'lock',         'Batch: ticket locked.' );
$Self->Is( $Ticket{OwnerID}, $ResponsibleID, 'Batch: owner from change set, not the locking agent.' );

1;
