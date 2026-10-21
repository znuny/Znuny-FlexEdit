# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketFlexEdit;

use strict;
use warnings;
use utf8;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');

    my $LanguageObject = $LayoutObject->{LanguageObject};

    if ( !$Self->{TicketID} ) {
        my $Error = $LanguageObject->Translate('Need TicketID!');
        return $Self->_JSONResponse(
            Data => {
                Success => 0,
                Error   => $Error,
            },
        );
    }

    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );
    my %EditableFields = $Access
        ? $FlexEditObject->GetEditableFields(
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
        )
        : ();

    if ( !%EditableFields ) {
        my $Error = $LanguageObject->Translate('You are not allowed to change this field.');
        return $Self->_JSONResponse(
            Data => {
                Success => 0,
                Error   => $Error,
            },
        );
    }

    if ( $Self->{Subaction} eq 'Options' ) {
        return $Self->_Options( EditableFields => \%EditableFields );
    }
    elsif ( $Self->{Subaction} eq 'Save' ) {
        $LayoutObject->ChallengeTokenCheck();
        return $Self->_Save();
    }

    my $Error = $LanguageObject->Translate('Invalid Subaction.');
    return $Self->_JSONResponse(
        Data => {
            Success => 0,
            Error   => $Error,
        },
    );
}

sub _Options {
    my ( $Self, %Param ) = @_;

    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');

    my $Field    = $ParamObject->GetParam( Param => 'Field' ) // '';
    my $ValueKey = $FlexEditObject->GetValueKey(
        Field => $Field,
    );

    if ( !$ValueKey || !$Param{EditableFields}->{$Field} ) {
        my $Error = $LayoutObject->{LanguageObject}->Translate('You are not allowed to change this field.');
        return $Self->_JSONResponse(
            Data => {
                Success => 0,
                Error   => $Error,
            },
        );
    }

    # Pending (not yet saved) changes of all fields.
    my $Pending = $Self->_JSONParam( Param => 'Pending' );

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 0,
        UserID        => $Self->{UserID},
    );

    my $PossibleValues = $FlexEditObject->GetPossibleValues(
        Field     => $Field,
        TicketID  => $Self->{TicketID},
        UserID    => $Self->{UserID},
        Overrides => $Pending,
    ) // {};

    my $SelectedID = exists $Pending->{$Field}
        ? $Pending->{$Field}
        : $Ticket{$ValueKey} // '';

    my %Translation = map { $_ => 1 } qw(Priority State Lock Type);
    my %TreeView    = map { $_ => 1 } qw(Queue Service);

    # The empty value (Service/SLA) is rendered via PossibleNone, otherwise
    # TreeView would treat it as a tree node.
    my %SelectionData = %{$PossibleValues};
    my $PossibleNone  = exists $SelectionData{''} ? 1 : 0;
    delete $SelectionData{''};

    my $SelectionHTML = $LayoutObject->BuildSelection(
        Data         => \%SelectionData,
        Name         => 'FlexEditValue',
        ID           => 'FlexEditValue_' . $Field,
        SelectedID   => $SelectedID,
        Translation  => $Translation{$Field}                          ? 1            : 0,
        TreeView     => $TreeView{$Field}                             ? 1            : 0,
        Sort         => ( $Field eq 'Priority' || $Field eq 'State' ) ? 'NumericKey' : 'AlphanumericValue',
        Class        => 'Modernize FlexEditSelection',
        PossibleNone => $PossibleNone,
    );

    my %Data = (
        Field     => $Field,
        Selection => $SelectionHTML,
    );

    my @PendingStateIDs;
    my $VacationDays;
    my $WeekDayStart;

    if ( $Field eq 'State' ) {
        STATEID:
        for my $StateID ( sort keys %{$PossibleValues} ) {
            my %State = $StateObject->StateGet(
                ID => $StateID,
            );
            next STATEID if ( $State{TypeName} // '' ) !~ m{^pending}i;
            push @PendingStateIDs, $StateID;
        }

        if (@PendingStateIDs) {
            my $Calendar = $TicketObject->TicketCalendarGet(%Ticket);

            # Preselect the current pending time, if the ticket is pending.
            my $DiffTime = $ConfigObject->Get('Ticket::Frontend::PendingDiffTime') || 0;
            if ( $Ticket{UntilTime} && $Ticket{UntilTime} > 0 ) {
                $DiffTime = $Ticket{UntilTime};
            }

            $Data{DateString} = $LayoutObject->BuildDateSelection(
                Prefix               => 'FlexEditPending',
                Format               => 'DateInputFormatLong',
                YearPeriodPast       => 0,
                YearPeriodFuture     => 5,
                DiffTime             => $DiffTime,
                Validate             => 1,
                ValidateDateInFuture => 1,
                Calendar             => $Calendar,
            );
            $VacationDays = $LayoutObject->DatepickerGetVacationDays(
                Calendar => $Calendar,
            );

            # First day of the week (same logic as BuildDateSelection).
            $WeekDayStart = $ConfigObject->Get('CalendarWeekDayStart');
            if ( $Calendar && $ConfigObject->Get( 'TimeZone::Calendar' . $Calendar . 'Name' ) ) {
                $WeekDayStart = $ConfigObject->Get( 'CalendarWeekDayStart::Calendar' . $Calendar );
            }
            $WeekDayStart //= 1;

            $LayoutObject->Block(
                Name => 'Pending',
                Data => \%Data,
            );
        }
    }

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'AgentTicketFlexEdit',
        Data         => \%Data,
    );

    return $Self->_JSONResponse(
        Data => {
            Success         => 1,
            Field           => $Field,
            HTML            => $HTML,
            Values          => [ map {"$_"} sort keys %{$PossibleValues} ],
            PendingStateIDs => \@PendingStateIDs,
            VacationDays    => $VacationDays,
            WeekDayStart    => $WeekDayStart,
        },
    );
}

sub _Save {
    my ( $Self, %Param ) = @_;

    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');

    my $LanguageObject = $LayoutObject->{LanguageObject};

    my $Changes = $Self->_JSONParam( Param => 'Changes' );

    # Pending date (user time zone -> system time zone).
    my %DateParam;
    my $HasDate = 1;
    for my $Key (qw(Year Month Day Hour Minute)) {
        $DateParam{$Key} = $ParamObject->GetParam( Param => 'FlexEditPending' . $Key );
        $HasDate = 0 if !defined $DateParam{$Key} || $DateParam{$Key} eq '';
    }
    if ($HasDate) {
        %DateParam = $LayoutObject->TransformDateSelection(
            %DateParam,
        );
    }
    else {
        %DateParam = ();
    }

    my $Result = $FlexEditObject->SetFields(
        %DateParam,
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
        Changes  => $Changes,
    );

    my %Errors;
    for my $Field ( sort keys %{ $Result->{Errors} // {} } ) {
        $Errors{$Field} = $LanguageObject->Translate( $Result->{Errors}->{$Field} );
    }

    # Nothing was changed (validation failed), keep the pending changes in the browser.
    if ( !@{ $Result->{Applied} // [] } && %Errors ) {
        return $Self->_JSONResponse(
            Data => {
                Success => 0,
                Errors  => \%Errors,
            },
        );
    }

    # The agent might have lost access (e.g. after moving the ticket).
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
        LogNo    => 1,
    );
    if ( !$Access ) {
        my $Redirect = $LayoutObject->{Baselink} . ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' );
        return $Self->_JSONResponse(
            Data => {
                Success  => 1,
                Redirect => $Redirect,
            },
        );
    }

    my $WidgetHTML = $Self->_TicketInformationRender();

    return $Self->_JSONResponse(
        Data => {
            Success    => $Result->{Success},
            Applied    => $Result->{Applied},
            Errors     => \%Errors,
            WidgetHTML => $WidgetHTML,
        },
    );
}

sub _JSONParam {
    my ( $Self, %Param ) = @_;

    my $FlexEditObject = $Kernel::OM->Get('Kernel::System::FlexEdit');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $String = $ParamObject->GetParam( Param => $Param{Param} ) // '';
    return {} if !length $String;

    my $Data = $JSONObject->Decode(
        Data => $String,
    );
    return {} if ref $Data ne 'HASH';

    # Only plain values are allowed.
    my %Clean;
    KEY:
    for my $Key ( sort keys %{$Data} ) {
        next KEY if !$FlexEditObject->GetValueKey(
            Field => $Key,
        );
        next KEY if ref $Data->{$Key};

        $Clean{$Key} = $Data->{$Key} // '';
    }

    return \%Clean;
}

sub _TicketInformationRender {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # Same ACL action data as AgentTicketZoom.
    my $Counter         = 0;
    my %PossibleActions = map { ++$Counter => $_ }
        grep { substr( $_, 0, length 'Agent' ) eq 'Agent' }
        sort keys %{ $ConfigObject->Get('Frontend::Module') // {} };

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => 'AgentTicketZoom',
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = %PossibleActions;
    if ($ACL) {
        %AclAction = $TicketObject->TicketAclActionData();
    }

    my $Module = 'Kernel::Output::HTML::TicketZoom::TicketInformationFlexEdit';
    return '' if !$MainObject->Require($Module);

    my $WidgetObject = $Module->new( %{$Self} );
    if ( !$WidgetObject ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "new() of Widget module $Module not successful!",
        );
        return '';
    }

    my $WidgetOutput = $WidgetObject->Run(
        Ticket    => \%Ticket,
        AclAction => \%AclAction,
        Config    => {},
    );

    return $WidgetOutput->{Output} // '';
}

sub _JSONResponse {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $JSON = $LayoutObject->JSONEncode(
        Data => $Param{Data},
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
