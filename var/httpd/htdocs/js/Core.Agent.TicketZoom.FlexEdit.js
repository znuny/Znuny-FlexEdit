// --
// Copyright (C) 2012 Znuny GmbH, https://znuny.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.TicketZoom = Core.Agent.TicketZoom || {};

/**
 * @namespace Core.Agent.TicketZoom.FlexEdit
 * @memberof Core.Agent.TicketZoom
 * @author Znuny GmbH
 * @description
 *      Inline editing of ticket attributes in the ticket information widget.
 *      Changes of several attributes are collected and saved together.
 */
Core.Agent.TicketZoom.FlexEdit = (function (TargetNS) {

    // Pending (not yet saved) changes: Field => Value.
    var Pending = {},

        // True if the pending date of the state editor was changed.
        PendingDateChanged = false,

        // IDs of pending states (from the last state options request).
        PendingStateIDs = [];

    /**
     * @private
     * @name GetWidget
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {jQueryObject} The ticket information widget.
     * @description
     *      Returns the ticket information widget which supports inline editing.
     */
    function GetWidget() {
        return $('.FlexEditWidget').first();
    }

    /**
     * @private
     * @name GetSidebar
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {jQueryObject} The sidebar widget around the ticket information.
     * @description
     *      Returns the sidebar widget which holds the header actions.
     */
    function GetSidebar() {
        return GetWidget().closest('.FlexEditSidebarWidget');
    }

    /**
     * @private
     * @name GetRow
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {jQueryObject} The row of the given field.
     * @param {String} Field - Name of the field.
     * @description
     *      Returns the row element of a field.
     */
    function GetRow(Field) {
        return GetWidget().find('[data-flexedit-row="' + Field + '"]').first();
    }

    /**
     * @private
     * @name GetEditor
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {jQueryObject} The open editor of the given field.
     * @param {String} Field - Name of the field.
     * @description
     *      Returns the editor of a field (empty if not open).
     */
    function GetEditor(Field) {
        return GetRow(Field).find('.FlexEditEditor');
    }

    /**
     * @private
     * @name OriginalValue
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {String} The saved value of a field.
     * @param {String} Field - Name of the field.
     * @description
     *      Returns the currently saved value of a field.
     */
    function OriginalValue(Field) {
        return String(GetRow(Field).find('[data-flexedit-field]').attr('data-flexedit-value') || '');
    }

    /**
     * @private
     * @name OpenFields
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {Array} Names of the fields with an open editor.
     * @description
     *      Returns the fields with an open editor.
     */
    function OpenFields() {
        return GetWidget().find('.FlexEditEditor').map(function () {
            return $(this).attr('data-flexedit-editor');
        }).get();
    }

    /**
     * @private
     * @name UpdateDirty
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Updates the highlighting of the widget and the action bar.
     */
    function UpdateDirty() {
        var Count = Object.keys(Pending).length,
            $Widget = GetWidget();

        GetSidebar().toggleClass('FlexEditDirty', Count > 0);
        GetSidebar().find('.FlexEditHeaderActions').toggleClass('Hidden', Count === 0);

        $Widget.find('[data-flexedit-row]').each(function () {
            var $Row = $(this),
                Field = $Row.attr('data-flexedit-row'),
                Changed = Object.prototype.hasOwnProperty.call(Pending, Field),
                $Label = $Row.children('label').first(),
                $Hint = $Label.children('.FlexEditChangedHint'),
                HintID;

            $Row.toggleClass('FlexEditChanged', Changed);

            if (!Changed) {
                $Hint.remove();
                $Label.removeAttr('aria-describedby');
                return;
            }

            HintID = 'FlexEditChangedHint_' + Field;
            if (!$Hint.length) {
                $Hint = $('<span />')
                    .addClass('FlexEditChangedHint InvisibleText')
                    .attr('id', HintID)
                    .text(Core.Language.Translate('(changed)'));
                $Label.append($Hint);
            }
            $Label.attr('aria-describedby', HintID);
        });
    }

    /**
     * @private
     * @name ShowCopied
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Tells the agent that a value was copied to the clipboard.
     */
    function ShowCopied() {
        var Message = Core.Language.Translate('Copied to clipboard!');

        Core.UI.ShowNotification(Message, 'Success', '', function () {
            window.setTimeout(function () {
                Core.UI.HideNotification(Message, 'Success');
            }, 1500);
        }, 'FlexEditCopy', 'fa-clipboard');
    }

    /**
     * @private
     * @name CopyText
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Text - Text to copy.
     * @description
     *      Copies text to the clipboard.
     */
    function CopyText(Text) {
        if (!Text) {
            return;
        }

        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(Text).then(ShowCopied).catch(function () {
                CopyTextFallback(Text);
            });
            return;
        }

        CopyTextFallback(Text);
    }

    /**
     * @private
     * @name CopyTextFallback
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Text - Text to copy.
     * @description
     *      Copies text when the clipboard API is not available.
     */
    function CopyTextFallback(Text) {
        var TextArea = document.createElement('textarea'),
            Copied = false;

        TextArea.value = Text;
        TextArea.setAttribute('readonly', 'readonly');
        TextArea.style.position = 'fixed';
        TextArea.style.left = '-9999px';
        document.body.appendChild(TextArea);
        TextArea.select();
        Copied = document.execCommand('copy');
        document.body.removeChild(TextArea);

        if (Copied) {
            ShowCopied();
        }
    }

    /**
     * @private
     * @name MarkCopyLabels
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {jQueryObject} $Root - Element that contains the labels.
     * @description
     *      Marks labels so a click copies the value. Existing titles stay.
     */
    function MarkCopyLabels($Root) {
        $Root.find('label').each(function () {
            if ($(this).closest('.FlexEditEditor').length || $(this).attr('title')) {
                return;
            }
            $(this).attr('title', Core.Language.Translate('Copy'));
        });
    }

    /**
     * @private
     * @name HasSelection
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {Boolean} True if the agent has selected text.
     * @description
     *      True when the agent is selecting text, so a click must not steal it.
     */
    function HasSelection() {
        var Selection = window.getSelection ? window.getSelection() : null;

        return !!(Selection && String(Selection).length);
    }

    /**
     * @private
     * @name WidenDropdown
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Gives the open selection list at least the width of its field.
     */
    function WidenDropdown() {
        function Apply() {
            var $Search = GetWidget().find('.FlexEditInput .InputField_Search[aria-expanded="true"]').last(),
                $Input,
                $List = $('body > .InputField_ListContainer:visible').last(),
                Width;

            if (!$Search.length) {
                $Search = GetWidget().find('.FlexEditInput .InputField_Search:focus').last();
            }

            $Input = $Search.closest('.InputField_InputContainer');

            if (!$Input.length || !$List.length) {
                return;
            }

            Width = $Input.outerWidth();
            $List.addClass('FlexEditList');
            if (Width > 0) {
                $List.css('min-width', Width + 'px');
                $List.find('.InputField_TreeContainer').css('min-width', '100%');
            }
        }

        // The list fades in and jsTree measures itself after focus.
        window.setTimeout(Apply, 0);
        window.setTimeout(Apply, 300);
    }

    /**
     * @private
     * @name SetPending
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Name of the field.
     * @param {String} Value - New value.
     * @description
     *      Stores (or removes) a pending change.
     */
    function SetPending(Field, Value) {
        var IsChange = String(Value) !== OriginalValue(Field);

        if (Field === 'State' && PendingDateChanged && $.inArray(String(Value), PendingStateIDs) > -1) {
            IsChange = true;
        }

        if (IsChange) {
            Pending[Field] = String(Value);
        }
        else {
            delete Pending[Field];
        }

        UpdateDirty();
    }

    /**
     * @private
     * @name TogglePendingDate
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {jQueryObject} $Editor - Editor of the state field.
     * @description
     *      Shows the pending date selection if a pending state is selected.
     */
    function TogglePendingDate($Editor) {
        var Value = String($Editor.find('[name="FlexEditValue"]').val());

        $Editor.find('.FlexEditPending').toggleClass('Hidden', $.inArray(Value, PendingStateIDs) === -1);
    }

    /**
     * @private
     * @name PendingDateValues
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @returns {Object} The selected pending date values.
     * @description
     *      Returns the values of the pending date selection (if visible).
     */
    function PendingDateValues() {
        var $Editor = GetEditor('State'),
            Values = {};

        if (!$Editor.length || $Editor.find('.FlexEditPending').hasClass('Hidden')) {
            return Values;
        }

        $.each(['Year', 'Month', 'Day', 'Hour', 'Minute'], function (Index, Key) {
            Values['FlexEditPending' + Key] = $Editor.find('[name="FlexEditPending' + Key + '"]').val();
        });

        return Values;
    }

    /**
     * @private
     * @name ShowErrors
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {Object} Errors - Field => error message.
     * @description
     *      Shows an alert with the errors and marks the affected rows.
     */
    function ShowErrors(Errors) {
        var Lines = [];

        $.each(Errors || {}, function (Field, Message) {
            var $Row = GetRow(Field),
                Label = $.trim($Row.find('label').first().text()).replace(/:.*$/, '');

            $Row.addClass('FlexEditError');
            Lines.push((Label ? Label + ': ' : '') + Message);
        });

        if (!Lines.length) {
            return;
        }

        Core.UI.Dialog.ShowAlert(
            Core.Language.Translate('Error'),
            Core.Language.Translate('The following changes could not be saved:') + '<br/>' +
                $.map(Lines, function (Line) {
                    return Core.App.EscapeHTML(Line);
                }).join('<br/>')
        );
    }

    /**
     * @private
     * @name ShowResponseError
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {Object} Response - AJAX response.
     * @description
     *      Shows the error of a failed request.
     */
    function ShowResponseError(Response) {
        Core.UI.Dialog.ShowAlert(
            Core.Language.Translate('Error'),
            Core.App.EscapeHTML((Response && Response.Error) || Core.Language.Translate('An error occurred'))
        );
    }

    /**
     * @private
     * @name RemoveEditor
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Name of the field.
     * @description
     *      Removes the editor of a field and shows the saved value again.
     */
    function RemoveEditor(Field) {
        var $Row = GetRow(Field);

        $Row.find('.FlexEditEditor').remove();
        $Row.removeClass('FlexEditEditing FlexEditError');

        if ($Row.hasClass('FlexEditableRow')) {
            $Row.attr({
                tabindex: '0',
                role: 'button'
            });
        }
    }

    /**
     * @private
     * @name InsertEditor
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Name of the field.
     * @param {Object} Response - Response of the options request.
     * @description
     *      Inserts (or replaces) the editor of a field.
     */
    function InsertEditor(Field, Response) {
        var $Row = GetRow(Field),
            $Editor,
            DateValues = {};

        // Keep the pending date when the state editor is refreshed.
        if (Field === 'State') {
            DateValues = PendingDateValues();
            PendingStateIDs = $.map(Response.PendingStateIDs || [], function (StateID) {
                return String(StateID);
            });
        }

        $Row.find('.FlexEditEditor').remove();
        $Row.addClass('FlexEditEditing').removeAttr('tabindex').removeAttr('role').append(Response.HTML);
        $Editor = $Row.find('.FlexEditEditor');

        if ($Editor.find('.FlexEditPending').length) {
            $.each(DateValues, function (Name, Value) {
                $Editor.find('[name="' + Name + '"]').val(Value);
            });

            Core.UI.Datepicker.Init({
                Day: $('#FlexEditPendingDay'),
                Month: $('#FlexEditPendingMonth'),
                Year: $('#FlexEditPendingYear'),
                Hour: $('#FlexEditPendingHour'),
                Minute: $('#FlexEditPendingMinute'),
                VacationDays: Response.VacationDays,
                DateInFuture: true,
                WeekDayStart: Response.WeekDayStart
            });
            TogglePendingDate($Editor);
        }

        Core.UI.InputFields.Activate($Editor);
    }

    /**
     * @private
     * @name LoadOptions
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Name of the field.
     * @param {Function} Callback - Called with the response.
     * @description
     *      Loads the ACL filtered options of a field, taking pending changes into account.
     */
    function LoadOptions(Field, Callback) {
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), {
            Action: 'AgentTicketFlexEdit',
            Subaction: 'Options',
            TicketID: GetWidget().attr('data-flexedit-ticketid'),
            Field: Field,
            Pending: JSON.stringify(Pending)
        }, Callback);
    }

    /**
     * @private
     * @name RefreshEditors
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} ChangedField - Field that was changed (not refreshed).
     * @description
     *      Reloads the options of all other open editors, because ACLs and
     *      dependent lists (e.g. SLA, owner) can depend on the changed value.
     *      A pending value that is not possible anymore is adjusted.
     */
    function RefreshEditors(ChangedField) {
        $.each(OpenFields(), function (Index, Field) {
            if (Field === ChangedField) {
                return;
            }

            LoadOptions(Field, function (Response) {
                var NewValue;

                if (!Response || !Response.Success || !GetEditor(Field).length) {
                    return;
                }

                InsertEditor(Field, Response);

                NewValue = String(GetEditor(Field).find('[name="FlexEditValue"]').val() || '');
                if (Object.prototype.hasOwnProperty.call(Pending, Field) && Pending[Field] !== NewValue) {
                    SetPending(Field, NewValue);
                    GetRow(Field).addClass('FlexEditAdjusted');
                    window.setTimeout(function () {
                        GetRow(Field).removeClass('FlexEditAdjusted');
                    }, 1500);
                }
            });
        });
    }

    /**
     * @private
     * @name RevertField
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Name of the field.
     * @description
     *      Reverts the pending change of a field.
     */
    function RevertField(Field) {
        var WasPending = Object.prototype.hasOwnProperty.call(Pending, Field);

        RemoveEditor(Field);
        delete Pending[Field];
        if (Field === 'State') {
            PendingDateChanged = false;
        }
        UpdateDirty();

        if (WasPending) {
            RefreshEditors(Field);
        }
    }

    /**
     * @private
     * @name CloseUnchangedEditors
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} ExceptField - Field to keep open.
     * @description
     *      Closes all editors without a pending change.
     */
    function CloseUnchangedEditors(ExceptField) {
        $.each(OpenFields(), function (Index, Field) {
            if (Field !== ExceptField && !Object.prototype.hasOwnProperty.call(Pending, Field)) {
                RemoveEditor(Field);
            }
        });
    }

    /**
     * @private
     * @name OpenEditor
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} Field - Field to edit.
     * @description
     *      Loads the ACL filtered options and shows the inline editor.
     */
    function OpenEditor(Field) {
        CloseUnchangedEditors(Field);

        if (GetEditor(Field).length) {
            GetEditor(Field).find('[name="FlexEditValue"]').focus();
            return;
        }

        LoadOptions(Field, function (Response) {
            if (!Response || !Response.Success) {
                ShowResponseError(Response);
                return;
            }

            InsertEditor(Field, Response);
            GetEditor(Field).find('[name="FlexEditValue"]').focus();
            WidenDropdown();
        });
    }

    /**
     * @private
     * @name RememberRows
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {jQueryObject} $Rows - Rows as rendered by the server.
     * @description
     *      Stores the server side HTML of the rows, so later changes can be detected
     *      independently from client side DOM modifications.
     */
    function RememberRows($Rows) {
        $Rows.each(function () {
            $(this).data('FlexEditHTML', $(this).prop('outerHTML'));
        });
    }

    /**
     * @private
     * @name UpdateRows
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @param {String} WidgetHTML - Freshly rendered ticket information widget.
     * @param {Array} Applied - Fields that were changed.
     * @description
     *      Replaces only the rows that changed (the saved ones and e.g. dependent
     *      fields or fields whose editability changed because of ACLs).
     */
    function UpdateRows(WidgetHTML, Applied) {
        var $NewWidget = $('<div>').html(WidgetHTML),
            $Widget = GetWidget();

        $NewWidget.find('[data-flexedit-row]').each(function () {
            var $NewRow = $(this),
                Field = $NewRow.attr('data-flexedit-row'),
                $OldRow = $Widget.find('[data-flexedit-row="' + Field + '"]').first(),
                NewHTML = $NewRow.prop('outerHTML');

            if (!$OldRow.length) {
                return;
            }

            if ($.inArray(Field, Applied || []) === -1 && $OldRow.data('FlexEditHTML') === NewHTML) {
                RemoveEditor(Field);
                return;
            }

            $OldRow.replaceWith($NewRow);
            $NewRow.data('FlexEditHTML', NewHTML);
            $NewRow.addClass('FlexEditUpdated');
            MarkCopyLabels($NewRow);
            window.setTimeout(function () {
                $NewRow.removeClass('FlexEditUpdated');
            }, 1500);
        });
    }

    /**
     * @private
     * @name SaveAll
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Saves all pending changes at once.
     */
    function SaveAll() {
        var $Widget = GetWidget(),
            Data = $.extend({
                Action: 'AgentTicketFlexEdit',
                Subaction: 'Save',
                TicketID: $Widget.attr('data-flexedit-ticketid'),
                Changes: JSON.stringify(Pending)
            }, Object.prototype.hasOwnProperty.call(Pending, 'State') ? PendingDateValues() : {});

        if (!Object.keys(Pending).length) {
            return;
        }

        GetSidebar().find('.FlexEditSaveAll').prop('disabled', true);
        $Widget.find('.FlexEditError').removeClass('FlexEditError');

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
            GetSidebar().find('.FlexEditSaveAll').prop('disabled', false);

            if (!Response) {
                ShowResponseError(Response);
                return;
            }

            if (Response.Redirect) {
                Pending = {};
                window.location.href = Response.Redirect;
                return;
            }

            // Validation failed, nothing was changed: keep the pending changes.
            if (!Response.WidgetHTML) {
                if (Response.Errors) {
                    ShowErrors(Response.Errors);
                }
                else {
                    ShowResponseError(Response);
                }
                return;
            }

            $.each(OpenFields(), function (Index, Field) {
                RemoveEditor(Field);
            });
            Pending = {};
            PendingDateChanged = false;

            UpdateRows(Response.WidgetHTML, Response.Applied);
            UpdateDirty();

            ShowErrors(Response.Errors);
        });
    }

    /**
     * @private
     * @name DiscardAll
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Discards all pending changes.
     */
    function DiscardAll() {
        $.each(OpenFields(), function (Index, Field) {
            RemoveEditor(Field);
        });
        Pending = {};
        PendingDateChanged = false;
        UpdateDirty();
    }

    /**
     * @name Init
     * @memberof Core.Agent.TicketZoom.FlexEdit
     * @function
     * @description
     *      Binds the event handlers (delegated, so replaced rows keep working).
     */
    TargetNS.Init = function () {
        var $Widget = GetWidget();

        if (!$Widget.length) {
            return;
        }

        RememberRows($Widget.find('[data-flexedit-row]'));
        MarkCopyLabels($Widget);

        $Widget.on('click', 'label', function (Event) {
            var $Label = $(this),
                Text;

            if ($Label.closest('.FlexEditEditor').length || HasSelection()) {
                return;
            }

            Text = $.trim($Label.parent().children('.Value').first().text());
            if (!Text) {
                return;
            }

            Event.preventDefault();
            Event.stopPropagation();
            CopyText(Text);
        });

        $Widget.on('click', '.FlexEditableRow', function (Event) {
            var Field;

            if ($(Event.target).closest('.FlexEditEditor, label').length || HasSelection()) {
                return;
            }

            Field = $(this).find('[data-flexedit-field]').first().attr('data-flexedit-field');
            if (!Field) {
                return;
            }

            Event.preventDefault();
            OpenEditor(Field);
        });

        $Widget.on('keydown', '.FlexEditableRow', function (Event) {
            var Field;

            if (Event.which !== 13 && Event.which !== 32) {
                return;
            }

            if ($(Event.target).closest('.FlexEditEditor').length) {
                return;
            }

            Field = $(this).find('[data-flexedit-field]').first().attr('data-flexedit-field');
            if (!Field) {
                return;
            }

            Event.preventDefault();
            OpenEditor(Field);
        });

        $Widget.on('change', '.FlexEditEditor [name="FlexEditValue"]', function () {
            var $Editor = $(this).closest('.FlexEditEditor'),
                Field = $Editor.attr('data-flexedit-editor');

            if (Field === 'State') {
                TogglePendingDate($Editor);
            }

            SetPending(Field, $(this).val());
            RefreshEditors(Field);
        });

        $Widget.on('change', '.FlexEditPendingDate select, .FlexEditPendingDate input', function () {
            PendingDateChanged = true;
            SetPending('State', GetEditor('State').find('[name="FlexEditValue"]').val());
        });

        $Widget.on('click', '.FlexEditUndo', function (Event) {
            Event.preventDefault();
            RevertField($(this).closest('.FlexEditEditor').attr('data-flexedit-editor'));
        });

        $Widget.on('keydown', '.FlexEditEditor', function (Event) {
            if (Event.which === 27) {
                RevertField($(this).attr('data-flexedit-editor'));
            }
        });

        $Widget.on('focus', '.FlexEditInput .InputField_Search', WidenDropdown);

        // Capture phase: the title click toggles the widget and would run first on bubble.
        GetSidebar().get(0).addEventListener('click', function (Event) {
            var $Button = $(Event.target).closest('.FlexEditDiscard, .FlexEditSaveAll');

            if (!$Button.length) {
                return;
            }

            Event.preventDefault();
            Event.stopPropagation();

            if ($Button.hasClass('FlexEditDiscard')) {
                DiscardAll();
                return;
            }

            SaveAll();
        }, true);

        // Warn before leaving the page with unsaved changes.
        $(window).on('beforeunload.FlexEdit', function (Event) {
            if (!Object.keys(Pending).length) {
                return undefined;
            }
            Event.preventDefault();
            Event.originalEvent.returnValue = '';
            return '';
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.TicketZoom.FlexEdit || {}));
