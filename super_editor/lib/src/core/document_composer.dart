import 'dart:async';
import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/pausable_value_notifier.dart';

import '../default_editor/document_ime/document_input_ime.dart';
import 'document_selection.dart';
import 'editor.dart';

/// Maintains a [DocumentSelection] within a [Document] and
/// uses that selection to edit the document.
abstract class DocumentComposer with ChangeNotifier {
  /// Constructs a [DocumentComposer] with the given [initialSelection].
  ///
  /// The [initialSelection] may be omitted if no initial selection is
  /// desired.
  DocumentComposer({
    DocumentSelection? initialSelection,
    SuperEditorImeConfiguration? imeConfiguration,
  }) : _preferences = ComposerPreferences() {
    _streamController = StreamController<DocumentSelectionChange>.broadcast();
    _selectionNotifier.value = initialSelection;
    _preferences.addListener(() {
      editorLog.fine("Composer preferences changed");
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _preferences.dispose();
    _streamController.close();
    super.dispose();
  }

  /// Returns the current [DocumentSelection] for a [Document].
  DocumentSelection? get selection => selectionNotifier.value;

  /// Returns the reason for the most recent selection change in the composer.
  ///
  /// For example, a selection might change as a result of user interaction, or as
  /// a result of another user editing content, or some other reason.
  Object? get latestSelectionChangeReason => _latestSelectionChange?.reason;

  /// Returns the most recent selection change in the composer.
  ///
  /// The [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  DocumentSelectionChange? get latestSelectionChange => _latestSelectionChange;
  DocumentSelectionChange? _latestSelectionChange;

  /// A stream of document selection changes.
  ///
  /// Each new [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  ///
  /// Listen to this [Stream] when the selection reason is needed. Otherwise, use [selectionNotifier].
  Stream<DocumentSelectionChange> get selectionChanges => _streamController.stream;
  late StreamController<DocumentSelectionChange> _streamController;

  /// Notifies whenever the current [DocumentSelection] changes.
  ///
  /// If the selection change reason is needed, use [selectionChanges] instead.
  ValueListenable<DocumentSelection?> get selectionNotifier => _selectionNotifier;
  final _selectionNotifier = PausableValueNotifier<DocumentSelection?>(null);

  /// The current composing region, which signifies spans of text
  /// that the IME is thinking about changing.
  ///
  /// Only valid when editing a document with an IME input method
  ValueListenable<DocumentRange?> get composingRegion => _composingRegion;
  final _composingRegion = PausableValueNotifier<DocumentRange?>(null);

  /// Whether the editor should allow special user interactions with the
  /// document content, such as clicking to open a link.
  ///
  /// Typically, this mode should be enabled and disabled with a special
  /// keyboard key such as `cmd` or `ctrl`.
  ///
  /// On desktop, when using interaction mode to launch URLs, window focus
  /// will jump from the Flutter app to the new browser window. This jump
  /// prevents the `cmd` or `ctrl` key release from being processed by Flutter,
  /// thereby locking the Flutter app in interaction mode. If this happens in
  /// your app, consider using the `window_manager` plugin to find out when
  /// your app window loses focus (called "blurring") and then set this value
  /// to `false`.
  ValueListenable<bool> get isInInteractionMode => _isInInteractionMode;
  final _isInInteractionMode = PausableValueNotifier(false);

  final ComposerPreferences _preferences;

  /// Returns the composition preferences for this composer.
  ComposerPreferences get preferences => _preferences;
}

class MutableDocumentComposer extends DocumentComposer implements Editable {
  MutableDocumentComposer({
    DocumentSelection? initialSelection,
    SuperEditorImeConfiguration? imeConfiguration,
  }) : super(
          initialSelection: initialSelection,
          imeConfiguration: imeConfiguration,
        );

  bool _isInTransaction = false;
  bool _didChangeSelectionDuringTransaction = false;

  /// Sets the current [selection] for a [Document].
  ///
  /// [reason] represents what caused the selection change to happen.
  void setSelectionWithReason(DocumentSelection? newSelection, [Object reason = SelectionReason.userInteraction]) {
    if (_isInTransaction && newSelection != _latestSelectionChange?.selection) {
      _didChangeSelectionDuringTransaction = true;
    }

    _latestSelectionChange = DocumentSelectionChange(
      selection: newSelection,
      reason: reason,
    );

    // Updates the selection, so both _latestSelectionChange and selectionNotifier are in sync.
    _selectionNotifier.value = newSelection;
  }

  /// Clears the current [selection].
  void clearSelection() {
    setSelectionWithReason(null, SelectionReason.userInteraction);
  }

  void setComposingRegion(DocumentRange? newComposingRegion) {
    _composingRegion.value = newComposingRegion;
  }

  void setIsInteractionMode(bool newValue) => _isInInteractionMode.value = newValue;

  @override
  void onTransactionStart() {
    _selectionNotifier.pauseNotifications();

    _composingRegion.pauseNotifications();

    _isInInteractionMode.pauseNotifications();

    _isInTransaction = true;
    _didChangeSelectionDuringTransaction = false;
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {
    _isInTransaction = false;

    _selectionNotifier.resumeNotifications();
    if (_latestSelectionChange != null && _didChangeSelectionDuringTransaction) {
      _streamController.sink.add(_latestSelectionChange!);
    }

    _composingRegion.resumeNotifications();

    _isInInteractionMode.resumeNotifications();
  }
}

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<Attribution> _currentAttributions = {};

  /// Returns the styles that should be applied to the next
  /// character that is entered in a [Document].
  Set<Attribution> get currentAttributions => _currentAttributions;

  /// Adds [attribution] to [currentAttributions].
  void addStyle(Attribution attribution) {
    _currentAttributions.add(attribution);
    notifyListeners();
  }

  /// Adds all [attributions] to [currentAttributions].
  void addStyles(Set<Attribution> attributions) {
    _currentAttributions.addAll(attributions);
    notifyListeners();
  }

  /// Removes [attributions] from [currentAttributions].
  void removeStyle(Attribution attributions) {
    _currentAttributions.remove(attributions);
    notifyListeners();
  }

  /// Removes all [attributions] from [currentAttributions].
  void removeStyles(Set<Attribution> attributions) {
    _currentAttributions.removeAll(attributions);
    notifyListeners();
  }

  /// Adds or removes [attribution] to/from [currentAttributions] depending
  /// on whether [attribution] is already in [currentAttributions].
  void toggleStyle(Attribution attribution) {
    if (_currentAttributions.contains(attribution)) {
      _currentAttributions.remove(attribution);
    } else {
      _currentAttributions.add(attribution);
    }
    notifyListeners();
  }

  /// Adds or removes all [attributions] to/from [currentAttributions] depending
  /// on whether each attribution is already in [currentAttributions].
  void toggleStyles(Set<Attribution> attributions) {
    for (final attribution in attributions) {
      if (_currentAttributions.contains(attribution)) {
        _currentAttributions.remove(attribution);
      } else {
        _currentAttributions.add(attribution);
      }
    }
    notifyListeners();
  }

  /// Removes all styles from [currentAttributions].
  void clearStyles() {
    _currentAttributions.clear();
    notifyListeners();
  }
}

/// A [ChangeSelectionRequest] that represents a user's desire to push the caret upstream
/// or downstream, such as when pressing LEFT or RIGHT.
///
/// It's useful to capture the user's desire to push the caret because sometimes the caret
/// needs to jump past a piece of content that doesn't allow partial selection, such as a
/// user tag. In the case of pushing the caret, we know which direction to jump over that
/// content.
class PushCaretRequest extends ChangeSelectionRequest {
  PushCaretRequest(
    DocumentPosition newPosition,
    this.direction,
  ) : super(DocumentSelection.collapsed(position: newPosition), SelectionChangeType.pushCaret,
            SelectionReason.userInteraction);

  final TextAffinity direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is PushCaretRequest && runtimeType == other.runtimeType && direction == other.direction;

  @override
  int get hashCode => super.hashCode ^ direction.hashCode;
}

/// A [ChangeSelectionRequest] that represents a user's desire to expand an existing selection
/// further upstream or downstream, such as when pressing SHIFT+LEFT or SHIFT+RIGHT.
///
/// It's useful to capture the user's desire to expand the current selection because sometimes
/// the selection needs to jump past a piece of content that doesn't allow partial selection,
/// such as a user tag. In the case of expanding the selection, we know which direction to jump
/// over that content.
class ExpandSelectionRequest extends ChangeSelectionRequest {
  const ExpandSelectionRequest(
    DocumentSelection newSelection,
  ) : super(newSelection, SelectionChangeType.expandSelection, SelectionReason.userInteraction);
}

/// A [ChangeSelectionRequest] that represents a user's desire to collapse an existing selection
/// further upstream or downstream, such as when pressing SHIFT+LEFT or SHIFT+RIGHT.
///
/// It's useful to capture the user's desire to expand the current selection because sometimes
/// the selection needs to jump past a piece of content that doesn't allow partial selection,
/// such as a user tag. In the case of expanding the selection, we know which direction to jump
/// over that content.
class CollapseSelectionRequest extends ChangeSelectionRequest {
  CollapseSelectionRequest(
    DocumentPosition newPosition,
  ) : super(
          DocumentSelection.collapsed(position: newPosition),
          SelectionChangeType.collapseSelection,
          SelectionReason.userInteraction,
        );
}

class ClearSelectionRequest implements EditRequest {
  const ClearSelectionRequest();
}

/// [EditRequest] that changes the [DocumentSelection] to the given [newSelection].
class ChangeSelectionRequest implements EditRequest {
  const ChangeSelectionRequest(
    this.newSelection,
    this.changeType,
    this.reason, {
    this.newComposingRegion,
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;
  final DocumentRange? newComposingRegion;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  final SelectionChangeType changeType;

  /// The reason that the selection changed, such as "user interaction".
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeSelectionRequest &&
          runtimeType == other.runtimeType &&
          newSelection == other.newSelection &&
          newComposingRegion == other.newComposingRegion &&
          notifyListeners == other.notifyListeners &&
          changeType == other.changeType &&
          reason == other.reason;

  @override
  int get hashCode =>
      newSelection.hashCode ^
      newComposingRegion.hashCode ^
      notifyListeners.hashCode ^
      changeType.hashCode ^
      reason.hashCode;
}

/// An [EditCommand] that changes the [DocumentSelection] in the [DocumentComposer]
/// to the [newSelection].
class ChangeSelectionCommand implements EditCommand {
  const ChangeSelectionCommand(
    this.newSelection,
    this.changeType,
    this.reason, {
    this.newComposingRegion,
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;
  final DocumentRange? newComposingRegion;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  final SelectionChangeType changeType;

  final String reason;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final initialSelection = composer.selection;
    final initialComposingRegion = composer.composingRegion.value;

    composer.setSelectionWithReason(newSelection, reason);
    composer.setComposingRegion(newComposingRegion);

    executor.logChanges([
      SelectionChangeEvent(
        oldSelection: initialSelection,
        newSelection: newSelection,
        oldComposingRegion: initialComposingRegion,
        newComposingRegion: newComposingRegion,
        changeType: changeType,
        reason: reason,
      )
    ]);
  }
}

/// A [EditEvent] that represents a change to the user's selection within a document.
class SelectionChangeEvent implements EditEvent {
  const SelectionChangeEvent({
    required this.oldSelection,
    required this.newSelection,
    required this.oldComposingRegion,
    required this.newComposingRegion,
    required this.changeType,
    required this.reason,
  });

  final DocumentSelection? oldSelection;
  final DocumentSelection? newSelection;
  final DocumentRange? oldComposingRegion;
  final DocumentRange? newComposingRegion;
  final SelectionChangeType changeType;
  // TODO: can we replace the concept of a `reason` with `changeType`
  final String reason;

  @override
  String toString() => "[SelectionChangeEvent] - New selection: $newSelection, change type: $changeType";
}

/// Represents a change of a [DocumentSelection].
///
/// The [reason] represents what cause the selection to change.
/// For example, [SelectionReason.userInteraction] represents
/// a selection change caused by the user interacting with the editor.
class DocumentSelectionChange {
  DocumentSelectionChange({
    this.selection,
    required this.reason,
  });

  final DocumentSelection? selection;
  final Object reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelectionChange && selection == other.selection && reason == other.reason;

  @override
  int get hashCode => (selection?.hashCode ?? 0) ^ reason.hashCode;
}

/// Holds common reasons for selection changes.
/// Developers aren't limited to these selection change reasons. Any object can be passed as
/// a reason for a selection change. However, some Super Editor behavior is based on [userInteraction].
class SelectionReason {
  /// Represents a change caused by an user interaction.
  static const userInteraction = "userInteraction";

  /// Represents a changed caused by an event which was not initiated by the user.
  static const contentChange = "contentChange";
}

enum SelectionChangeType {
  /// Place the caret, or an expanded selection, somewhere in the document, with no relationship to the previous selection.
  place,

  /// Place the caret based on a desire to move the previous caret position upstream or downstream.
  pushCaret,

  /// Expand a caret to an expanded selection, or move the base or extent of an already expanded selection.
  expandSelection,

  /// Collapse an expanded selection down to a caret.
  collapseSelection,

  /// Change the selection as the result of inserting content, e.g., typing a character, pasting content.
  insertContent,

  /// Change the selection by deleting content, e.g., pressing backspace or delete.
  deleteContent,

  /// Clears the document selection, such as when a user taps in a textfield outside the editor.
  clearSelection,
}

class ChangeComposingRegionRequest implements EditRequest {
  ChangeComposingRegionRequest(this.composingRegion);

  final DocumentRange? composingRegion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeComposingRegionRequest &&
          runtimeType == other.runtimeType &&
          composingRegion == other.composingRegion;

  @override
  int get hashCode => composingRegion.hashCode;
}

class ChangeComposingRegionCommand implements EditCommand {
  ChangeComposingRegionCommand(this.composingRegion);

  final DocumentRange? composingRegion;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    context.find<MutableDocumentComposer>(Editor.composerKey)._composingRegion.value = composingRegion;
  }
}

class ChangeInteractionModeRequest implements EditRequest {
  const ChangeInteractionModeRequest({
    required this.isInteractionModeDesired,
  });

  final bool isInteractionModeDesired;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeInteractionModeRequest &&
          runtimeType == other.runtimeType &&
          isInteractionModeDesired == other.isInteractionModeDesired;

  @override
  int get hashCode => isInteractionModeDesired.hashCode;
}

class ChangeInteractionModeCommand implements EditCommand {
  ChangeInteractionModeCommand({
    required this.isInteractionModeDesired,
  });

  final bool isInteractionModeDesired;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    context.find<MutableDocumentComposer>(Editor.composerKey).setIsInteractionMode(isInteractionModeDesired);
  }
}
