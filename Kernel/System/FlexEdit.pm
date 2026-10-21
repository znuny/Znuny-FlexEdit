# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FlexEdit;

use strict;
use warnings;
use utf8;

use Kernel::Language              qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::FlexEdit - Inline editing of ticket attributes in AgentTicketZoom.

=head1 DESCRIPTION

Determines which ticket attributes an agent may edit inline, which values are possible
(ACLs are evaluated for frontend action C<AgentTicketFlexEdit>) and applies changes.

Pending (not yet saved) changes of other fields can be passed as C<Overrides>. They are
used like form values in the classic screens: ACL C<Properties> match them, C<PropertiesDatabase>
still match the stored ticket.

Each attribute is a module under C<Kernel::System::FlexEdit::Ticket>. Adding a field is a new
module in that directory. C<Base.pm> and modules under C<Base/> are parent classes and are
not loaded as fields. Apply order is C<GetOrder()>.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Action} = 'AgentTicketFlexEdit';

    my $Home = $ConfigObject->Get('Home');

    # Standard modules, then Custom so an override with the same field name wins.
    # Base.pm and modules under Base/ are parent classes and not fields.
    # Apply order is GetOrder(). DirectoryRead is not recursive, so Base/ is skipped.
    my @Directories = (
        "$Home/Kernel/System/FlexEdit/Ticket",
        "$Home/Custom/Kernel/System/FlexEdit/Ticket",
    );

    DIRECTORY:
    for my $Directory (@Directories) {
        next DIRECTORY if !-d $Directory;

        my @Files = $MainObject->DirectoryRead(
            Directory => $Directory,
            Filter    => '*.pm',
            Silent    => 1,
        );

        FILE:
        for my $File (@Files) {
            next FILE if $File =~ m{/Base\.pm\z}xms;

            my ($RelativePath) = $File =~ m{(Kernel/System/FlexEdit/Ticket/[^/]+)\.pm\z}xms;
            next FILE if !$RelativePath;

            my $Module = $RelativePath;
            $Module =~ s{/}{::}gx;

            my $FieldObject = $Kernel::OM->Create($Module);
            next FILE if !$FieldObject;

            my $Name = $FieldObject->GetName();
            next FILE if !$Name;

            $Self->{Field}->{$Name} = $FieldObject;
        }
    }

    return $Self;
}

=head2 GetValueKey()

Returns the ticket attribute that holds the current value of a field.
Returns an empty string for an unknown field.

    my $ValueKey = $FlexEditObject->GetValueKey(
        Field => 'Priority',
    );

=cut

sub GetValueKey {
    my ( $Self, %Param ) = @_;

    my $FieldObject = $Self->_GetField(
        Name => $Param{Field},
    );
    return '' if !$FieldObject;

    return $FieldObject->GetValueKey();
}

=head2 IsActive()

Returns true if the feature is enabled globally and not disabled by the given agent.

    my $IsActive = $FlexEditObject->IsActive(
        UserID => 123,
    );

=cut

sub IsActive {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    return 0 if !$Param{UserID};

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}") // {};
    return 0 if !$Config->{Enabled};

    my %Preferences = $UserObject->GetPreferences(
        UserID => $Param{UserID},
    );

    # A missing preference means "enabled" (feature is on by default).
    return 0 if defined $Preferences{UserFlexEditEnabled} && !$Preferences{UserFlexEditEnabled};

    return 1;
}

=head2 ListFields()

Returns the list of fields that are enabled via SysConfig (and whose underlying
ticket feature is active), in apply order.

    my @Fields = $FlexEditObject->ListFields();

=cut

sub ListFields {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}") // {};
    my $Fields = $Config->{Fields}                                       // {};

    my @FieldList;
    FIELD:
    for my $FieldObject ( $Self->_GetFieldObjects() ) {
        my $Name = $FieldObject->GetName();
        next FIELD if !$Fields->{$Name};
        next FIELD if !$FieldObject->IsFeatureEnabled();

        push @FieldList, $Name;
    }

    return @FieldList;
}

=head2 GetEditableFields()

Returns the fields the agent may edit inline for the given ticket.
Takes into account the global/user switch, the field list, ACLs on action
C<AgentTicketFlexEdit> and the ticket permission configured per field.

    my %EditableFields = $FlexEditObject->GetEditableFields(
        TicketID => 123,
        UserID   => 123,
    );

Returns:

    %EditableFields = (
        Priority => 1,
        Queue    => 1,
        # ...
    );

=cut

sub GetEditableFields {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(TicketID UserID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!",
        );
        return;
    }

    return if !$Self->IsActive( UserID => $Param{UserID} );

    my @FieldList = $Self->ListFields();
    return if !@FieldList;

    # ACLs can deny the whole action.
    my %PossibleActions = ( 1 => $Self->{Action} );
    my $ACL             = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Param{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Param{UserID},
    );

    # Only evaluate the ACL result if an ACL matched, otherwise TicketAclActionData()
    # could return data of a previous ACL call.
    if ($ACL) {
        my %AclAction       = $TicketObject->TicketAclActionData();
        my %AclActionLookup = reverse %AclAction;
        return if !$AclActionLookup{ $Self->{Action} };
    }

    my $Config     = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}") // {};
    my $Permission = $Config->{Permission}                                   // {};

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );
    return if !%Ticket;

    my %EditableFields;
    FIELD:
    for my $Field (@FieldList) {
        my $FieldObject = $Self->_GetField(
            Name => $Field,
        );

        my $Access = $TicketObject->TicketPermission(
            Type     => $Permission->{$Field} || 'rw',
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
            LogNo    => 1,
        );
        next FIELD if !$Access;
        next FIELD if !$FieldObject->IsEditable(
            Ticket => \%Ticket,
            UserID => $Param{UserID},
        );

        $EditableFields{$Field} = 1;
    }

    return %EditableFields;
}

=head2 GetPossibleValues()

Returns the possible values for a field, filtered by ACLs for action C<AgentTicketFlexEdit>.
Pending values of other fields can be given as C<Overrides>.

    my $PossibleValues = $FlexEditObject->GetPossibleValues(
        Field     => 'SLA',
        TicketID  => 123,
        UserID    => 123,
        Overrides => {              # optional
            Service => 4,
        },
    );

Returns:

    $PossibleValues = {
        ''  => '-',
        12  => 'Gold',
        # ...
    };

=cut

sub GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(Field TicketID UserID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!",
        );
        return;
    }

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );
    return if !%Ticket;

    my $Overrides = IsHashRefWithData( $Param{Overrides} ) ? $Param{Overrides} : {};
    my %Value     = $Self->_GetEffectiveValues(
        Ticket    => \%Ticket,
        Overrides => $Overrides,
    );

    my %Common = (
        $Self->_GetACLParams( Overrides => $Overrides ),
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Action   => $Self->{Action},
    );

    my $FieldObject = $Self->_GetField(
        Name => $Param{Field},
    );
    if ( !$FieldObject ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unsupported field '$Param{Field}'!",
        );
        return;
    }

    my %Values = $FieldObject->GetPossibleValues(
        Ticket => \%Ticket,
        Value  => \%Value,
        Common => \%Common,
    );

    return \%Values;
}

=head2 SetFields()

Validates and applies several changes at once. All changes are validated first
(each one against the ACLs, taking the other pending changes into account);
nothing is changed if one of them is invalid. Then the changes are applied in
dependency order.

    my $Result = $FlexEditObject->SetFields(
        TicketID => 123,
        UserID   => 123,
        Changes  => {
            Service => 4,
            SLA     => 2,
            State   => 6,
        },

        # needed for pending states only (in system time zone)
        Year     => 2026,
        Month    => 10,
        Day      => 1,
        Hour     => 12,
        Minute   => 0,
    );

Returns:

    $Result = {
        Success => 1,
        Applied => [ 'Service', 'SLA', 'State' ],
        Errors  => {},
    };

    $Result = {
        Success => 0,
        Applied => [],
        Errors  => {
            SLA => 'The selected value is not possible.',
        },
    };

=cut

sub SetFields {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(TicketID UserID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!",
        );
        return {
            Success => 0,
            Applied => [],
            Errors  => { '' => Translatable('Need TicketID and UserID!') },
        };
    }

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );

    # Ignore changes which don't change anything. A pending state is kept, as its
    # pending date might have changed.
    my %Changes = IsHashRefWithData( $Param{Changes} ) ? %{ $Param{Changes} } : ();
    FIELD:
    for my $Field ( sort keys %Changes ) {
        $Changes{$Field} //= '';

        my $FieldObject = $Self->_GetField(
            Name => $Field,
        );
        next FIELD if !$FieldObject;
        next FIELD if !$FieldObject->IsUnchanged(
            Ticket => \%Ticket,
            Value  => $Changes{$Field},
        );

        delete $Changes{$Field};
    }

    if ( !%Changes ) {
        return {
            Success => 1,
            Applied => [],
            Errors  => {},
        };
    }

    my %EditableFields = $Self->GetEditableFields(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # Validate everything before changing anything.
    my %Errors;
    FIELD:
    for my $Field ( sort keys %Changes ) {

        my $FieldObject = $Self->_GetField(
            Name => $Field,
        );
        if ( !$FieldObject || !$EditableFields{$Field} ) {
            $Errors{$Field} = Translatable('You are not allowed to change this field.');
            next FIELD;
        }

        my $PossibleValues = $Self->GetPossibleValues(
            Field     => $Field,
            TicketID  => $Param{TicketID},
            UserID    => $Param{UserID},
            Overrides => \%Changes,
        );
        if ( !IsHashRefWithData($PossibleValues) || !exists $PossibleValues->{ $Changes{$Field} } ) {
            $Errors{$Field} = Translatable('The selected value is not possible.');
            next FIELD;
        }

        my $Error = $FieldObject->GetValidationError(
            Value    => $Changes{$Field},
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
            Year     => $Param{Year},
            Month    => $Param{Month},
            Day      => $Param{Day},
            Hour     => $Param{Hour},
            Minute   => $Param{Minute},
        );
        if ($Error) {
            $Errors{$Field} = $Error;
            next FIELD;
        }
    }

    if (%Errors) {
        return {
            Success => 0,
            Applied => [],
            Errors  => \%Errors,
        };
    }

    # Apply in dependency order.
    my @Applied;
    FIELD:
    for my $FieldObject ( $Self->_GetFieldObjects() ) {
        my $Field = $FieldObject->GetName();
        next FIELD if !exists $Changes{$Field};

        my $Success = $Self->_ApplyField(
            %Param,
            Field   => $Field,
            Value   => $Changes{$Field},
            Changes => \%Changes,
        );

        if ( !$Success ) {
            $Errors{$Field} = Translatable('The field could not be updated.');
            next FIELD;
        }

        push @Applied, $Field;
    }

    return {
        Success => %Errors ? 0 : 1,
        Applied => \@Applied,
        Errors  => \%Errors,
    };
}

=head2 SetField()

Validates and sets a single field. See L</SetFields()>.

    my $Result = $FlexEditObject->SetField(
        Field    => 'Priority',
        Value    => 4,
        TicketID => 123,
        UserID   => 123,
    );

Returns:

    $Result = {
        Success => 1,
    };

    $Result = {
        Success => 0,
        Error   => 'The selected value is not possible.',
    };

=cut

sub SetField {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{Field} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Field!',
        );
        return {
            Success => 0,
            Error   => Translatable('Need Field, TicketID and UserID!'),
        };
    }

    my $Result = $Self->SetFields(
        %Param,
        Changes => {
            $Param{Field} => $Param{Value},
        },
    );

    my ($Error) = values %{ $Result->{Errors} // {} };

    return {
        Success => $Result->{Success},
        Error   => $Error,
    };
}

=head1 INTERNAL INTERFACE

=head2 _ApplyField()

Applies a single, already validated change.

=cut

sub _ApplyField {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $FieldObject = $Self->_GetField(
        Name => $Param{Field},
    );
    return if !$FieldObject;

    # Always use the current data, earlier changes might have modified the ticket.
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );

    return $FieldObject->SetValue(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Value    => $Param{Value},
        Ticket   => \%Ticket,
        Changes  => $Param{Changes},
        Action   => $Self->{Action},
        Year     => $Param{Year},
        Month    => $Param{Month},
        Day      => $Param{Day},
        Hour     => $Param{Hour},
        Minute   => $Param{Minute},
    );
}

=head2 _GetEffectiveValues()

Returns the values of all fields, taking pending changes into account.

=cut

sub _GetEffectiveValues {
    my ( $Self, %Param ) = @_;

    my %Values;
    for my $FieldObject ( $Self->_GetFieldObjects() ) {
        my $Name = $FieldObject->GetName();
        my $Key  = $FieldObject->GetValueKey();

        $Values{$Name} = exists $Param{Overrides}->{$Name}
            ? $Param{Overrides}->{$Name}
            : $Param{Ticket}->{$Key};
    }

    return %Values;
}

=head2 _GetACLParams()

Maps pending changes to the parameters the ACL engine uses for form values.

=cut

sub _GetACLParams {
    my ( $Self, %Param ) = @_;

    my %ACLParams;
    FIELD:
    for my $Field ( sort keys %{ $Param{Overrides} // {} } ) {
        my $FieldObject = $Self->_GetField(
            Name => $Field,
        );
        next FIELD if !$FieldObject;

        my $ACLParam = $FieldObject->GetACLParam();
        next FIELD if !$ACLParam;

        my $Value = $Param{Overrides}->{$Field};
        next FIELD if !defined $Value || $Value eq '';

        $ACLParams{$ACLParam} = $Value;
    }

    return %ACLParams;
}

=head2 _GetField()

Returns the field module for a name.

=cut

sub _GetField {
    my ( $Self, %Param ) = @_;

    return if !$Param{Name};

    return $Self->{Field}->{ $Param{Name} };
}

=head2 _GetFieldObjects()

Returns the field modules sorted by C<GetOrder()>. That number is the order
C<SetFields()> writes in. The reason for each current value is documented in
L<Kernel::System::FlexEdit::Ticket::Base/GetOrder()>.

    my @FieldObjects = $FlexEditObject->_GetFieldObjects();

=cut

sub _GetFieldObjects {
    my ( $Self, %Param ) = @_;

    my @FieldObjects = sort { $a->GetOrder() <=> $b->GetOrder() } values %{ $Self->{Field} };

    return @FieldObjects;
}

1;
