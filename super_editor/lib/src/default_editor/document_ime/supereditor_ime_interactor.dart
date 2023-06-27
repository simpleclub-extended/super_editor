import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/debug_visualization.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import '../document_hardware_keyboard/document_input_keyboard.dart';
import 'document_delta_editing.dart';
import 'document_ime_communication.dart';
import 'document_ime_interaction_policies.dart';
import 'ime_decoration.dart';
import 'ime_keyboard_control.dart';

/// [SuperEditor] interactor that edits a document based on IME input
/// from the operating system.
// TODO: instead of an IME interactor, try defining more granular interactors, e.g.,
//       TextDeltaInteractor, FloatingCursorInteractor, ScribbleInteractor.
//       The concept of the IME is so broad in functionality that if we mimic that
//       concept, we're going to get stuck piling unrelated behaviors into one place.
//       To make this division of responsibility possible, each of those interactors
//       could receive a proxy TextInputClient, which allows each interactor to say
//       proxyInputClient.addClient(myFocusedClient).
class SuperEditorImeInteractor extends StatefulWidget {
  const SuperEditorImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    this.clearSelectionWhenImeConnectionCloses = true,
    this.softwareKeyboardController,
    this.imePolicies = const SuperEditorImePolicies(),
    this.imeConfiguration = const SuperEditorImeConfiguration(),
    this.imeOverrides,
    this.hardwareKeyboardActions = const [],
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  /// All resources that are needed to edit a document.
  final SuperEditorContext editContext;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

  /// Controller that opens and closes the software keyboard.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [SuperEditorImePolicies.clearSelectionWhenEditorLosesFocus] are `false`,
  /// an app can use this controller to manually open and close the software
  /// keyboard, as needed.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [clearSelectionWhenImeDisconnects] are `true`, this controller probably
  /// shouldn't be used, because the commands to open and close the keyboard
  /// might conflict with teh automated behavior.
  final SoftwareKeyboardController? softwareKeyboardController;

  /// Policies that dictate when and how `SuperEditor` should interact with the
  /// platform IME.
  final SuperEditorImePolicies imePolicies;

  /// Preferences for how the platform IME should look and behave during editing.
  final SuperEditorImeConfiguration imeConfiguration;

  /// Overrides for IME actions.
  ///
  /// When the user edits document content in IME mode, those edits and actions
  /// are reported to a [DeltaTextInputClient], which is then responsible for
  /// applying those changes to a document.
  ///
  /// Provide a [DeltaTextInputClientDecorator], to override the default behaviors
  /// for various IME messages.
  final DeltaTextInputClientDecorator? imeOverrides;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  /// Controls "floating cursor" behavior for iOS devices.
  ///
  /// The floating cursor is an iOS-only feature. Flutter reports floating cursor
  /// messages through the IME API, which is why this controller is offered as
  /// a property on this IME interactor.
  final FloatingCursorController? floatingCursorController;

  final Widget child;

  @override
  State createState() => SuperEditorImeInteractorState();
}

@visibleForTesting
class SuperEditorImeInteractorState extends State<SuperEditorImeInteractor> implements ImeInputOwner {
  late FocusNode _focusNode;

  final _imeConnection = ValueNotifier<TextInputConnection?>(null);
  late TextInputConfiguration _textInputConfiguration;
  late final DocumentImeInputClient _documentImeClient;
  // The _imeClient is setup in one of two ways at any given time:
  //   _imeClient -> _documentImeClient, or
  //   _imeClient -> widget.imeOverrides -> _documentImeClient
  // See widget.imeOverrides for more info.
  late DeltaTextInputClientDecorator _imeClient;
  // _documentImeConnection functions as both a TextInputConnection and a
  // DeltaTextInputClient. This is required for a very specific reason that
  // occurs in specific situations. To understand why we need it, check the
  // implementation of DocumentImeInputClient. If we find a less confusing
  // way to handle that scenario, then get rid of this property.
  final _documentImeConnection = ValueNotifier<TextInputConnection?>(null);
  late final TextDeltasDocumentEditor _textDeltasDocumentEditor;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());

    _textDeltasDocumentEditor = TextDeltasDocumentEditor(
      editor: widget.editContext.editor,
      document: widget.editContext.document,
      documentLayoutResolver: () => widget.editContext.documentLayout,
      selection: widget.editContext.composer.selectionNotifier,
      composerPreferences: widget.editContext.composer.preferences,
      composingRegion: widget.editContext.composer.composingRegion,
      commonOps: widget.editContext.commonOps,
      onPerformAction: (action) => _imeClient.performAction(action),
    );
    _documentImeClient = DocumentImeInputClient(
      selection: widget.editContext.composer.selectionNotifier,
      composingRegion: widget.editContext.composer.composingRegion,
      textDeltasDocumentEditor: _textDeltasDocumentEditor,
      imeConnection: _imeConnection,
      floatingCursorController: widget.floatingCursorController,
    );

    _imeClient = DeltaTextInputClientDecorator();
    _configureImeClientDecorators();

    _imeConnection.addListener(_onImeConnectionChange);

    _textInputConfiguration = widget.imeConfiguration.toTextInputConfiguration();
  }

  @override
  void didUpdateWidget(SuperEditorImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.imeConfiguration != oldWidget.imeConfiguration) {
      _textInputConfiguration = widget.imeConfiguration.toTextInputConfiguration();
      if (isAttachedToIme) {
        _imeConnection.value!.updateConfig(_textInputConfiguration);
      }
    }

    if (widget.imeOverrides != oldWidget.imeOverrides) {
      oldWidget.imeOverrides?.client = null;
      _configureImeClientDecorators();
    }
  }

  @override
  void dispose() {
    _imeConnection.removeListener(_onImeConnectionChange);
    _imeConnection.value?.close();

    widget.imeOverrides?.client = null;
    _imeClient.client = null;
    _documentImeClient.dispose();

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient => _imeClient;

  @visibleForTesting
  bool get isAttachedToIme => _imeConnection.value?.attached ?? false;

  void _onImeConnectionChange() {
    if (_imeConnection.value == null) {
      _documentImeConnection.value = null;
      widget.imeOverrides?.client = null;
    } else {
      _configureImeClientDecorators();
      _documentImeConnection.value = _documentImeClient;
    }
  }

  void _configureImeClientDecorators() {
    // If we were given IME overrides, use those overrides to decorate our _documentImeClient.
    widget.imeOverrides?.client = _documentImeClient;

    // If we were given IME overrides, point our primary IME client to that client. Otherwise,
    // point our primary IME client directly towards the _documentImeClient.
    _imeClient.client = widget.imeOverrides ?? _documentImeClient;
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorImeDebugVisuals(
      imeConnection: _imeConnection,
      child: SuperEditorHardwareKeyHandler(
        focusNode: _focusNode,
        editContext: widget.editContext,
        keyboardActions: widget.hardwareKeyboardActions,
        autofocus: widget.autofocus,
        child: DocumentSelectionOpenAndCloseImePolicy(
          focusNode: _focusNode,
          editor: widget.editContext.editor,
          selection: widget.editContext.composer.selectionNotifier,
          imeConnection: _imeConnection,
          imeClientFactory: () => _imeClient,
          imeConfiguration: _textInputConfiguration,
          openKeyboardOnSelectionChange: widget.imePolicies.openKeyboardOnSelectionChange,
          closeKeyboardOnSelectionLost: widget.imePolicies.closeKeyboardOnSelectionLost,
          clearSelectionWhenImeConnectionCloses: widget.clearSelectionWhenImeConnectionCloses,
          child: ImeFocusPolicy(
            focusNode: _focusNode,
            imeConnection: _imeConnection,
            imeClientFactory: () => _imeClient,
            imeConfiguration: _textInputConfiguration,
            child: SoftwareKeyboardOpener(
              controller: widget.softwareKeyboardController,
              imeConnection: _imeConnection,
              createImeClient: () => _documentImeClient,
              createImeConfiguration: () => _textInputConfiguration,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A collection of policies that dictate how a [SuperEditor]'s focus, selection, and
/// IME should interact, such as opening the software keyboard whenever [SuperEditor]'s
/// selection changes ([openKeyboardOnSelectionChange]).
class SuperEditorImePolicies {
  const SuperEditorImePolicies({
    this.openKeyboardOnGainPrimaryFocus = true,
    this.closeKeyboardOnLosePrimaryFocus = true,
    this.openKeyboardOnSelectionChange = true,
    this.closeKeyboardOnSelectionLost = true,
  });

  /// Whether to automatically raise the software keyboard when [SuperEditor]
  /// gains primary focus (not just regular focus).
  ///
  /// Defaults to `true`.
  final bool openKeyboardOnGainPrimaryFocus;

  /// Whether to automatically close the software keyboard when [SuperEditor]
  /// loses primary focus (even if it retains regular focus).
  ///
  /// Defaults to `true`.
  final bool closeKeyboardOnLosePrimaryFocus;

  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  final bool openKeyboardOnSelectionChange;

  /// Whether the software keyboard should be closed whenever the editor goes from
  /// having a selection to not having a selection.
  ///
  /// In a typical app, this property should be `true`, because there's no place to
  /// apply IME input when there's no editor selection.
  final bool closeKeyboardOnSelectionLost;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorImePolicies &&
          runtimeType == other.runtimeType &&
          openKeyboardOnGainPrimaryFocus == other.openKeyboardOnGainPrimaryFocus &&
          closeKeyboardOnLosePrimaryFocus == other.closeKeyboardOnLosePrimaryFocus &&
          openKeyboardOnSelectionChange == other.openKeyboardOnSelectionChange &&
          closeKeyboardOnSelectionLost == other.closeKeyboardOnSelectionLost;

  @override
  int get hashCode =>
      openKeyboardOnGainPrimaryFocus.hashCode ^
      closeKeyboardOnLosePrimaryFocus.hashCode ^
      openKeyboardOnSelectionChange.hashCode ^
      closeKeyboardOnSelectionLost.hashCode;
}

/// Input Method Engine (IME) configuration for document text input.
class SuperEditorImeConfiguration {
  const SuperEditorImeConfiguration({
    this.enableAutocorrect = true,
    this.enableSuggestions = true,
    this.keyboardBrightness = Brightness.light,
    this.keyboardActionButton = TextInputAction.newline,
  });

  /// Whether the OS should offer auto-correction options to the user.
  final bool enableAutocorrect;

  /// Whether the OS should offer text completion suggestions to the user.
  final bool enableSuggestions;

  /// The brightness of the software keyboard (only applies to platforms
  /// with a software keyboard).
  final Brightness keyboardBrightness;

  /// The action button that's displayed on a software keyboard, e.g.,
  /// new-line, done, go, etc.
  final TextInputAction keyboardActionButton;

  TextInputConfiguration toTextInputConfiguration() {
    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: enableAutocorrect,
      enableSuggestions: enableSuggestions,
      inputAction: keyboardActionButton,
      keyboardAppearance: keyboardBrightness,
    );
  }

  SuperEditorImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
    bool? clearSelectionWhenImeDisconnects,
  }) {
    return SuperEditorImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorImeConfiguration &&
          runtimeType == other.runtimeType &&
          enableAutocorrect == other.enableAutocorrect &&
          enableSuggestions == other.enableSuggestions &&
          keyboardBrightness == other.keyboardBrightness &&
          keyboardActionButton == other.keyboardActionButton;

  @override
  int get hashCode =>
      enableAutocorrect.hashCode ^
      enableSuggestions.hashCode ^
      keyboardBrightness.hashCode ^
      keyboardActionButton.hashCode;
}
