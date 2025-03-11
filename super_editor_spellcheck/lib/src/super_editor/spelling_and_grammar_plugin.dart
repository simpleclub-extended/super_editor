import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/platform/spell_checker.dart';
import 'package:super_editor_spellcheck/src/super_editor/spell_checker_popover_controller.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestion_overlay.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

/// A [SuperEditorPlugin] that checks spelling and grammar across a [Document],
/// underlining spelling and grammar mistakes, and offering corrections.
///
/// This plugin works on Android, iOS, and macOS.
class SpellingAndGrammarPlugin extends SuperEditorPlugin {
  static const spellingErrorSuggestionsKey = "SpellingAndGrammarPlugin.spellingErrorSuggestions";

  /// Creates a new [SpellingAndGrammarPlugin].
  ///
  /// - [isSpellingCheckEnabled]: determines whether spelling checks are initially enabled. This
  ///   can be toggled at runtime by setting the value of [isSpellCheckEnabled].
  /// - [spellingErrorUnderlineStyle]: the style of underline to apply to misspelled words.
  /// - [isGrammarCheckEnabled]: determines whether grammar checks are initially enabled. This
  ///   can be toggled at runtime by setting the value of [isGrammarCheckEnabled].
  /// - [grammarErrorUnderlineStyle]: the style of underline to apply to grammar errors.
  /// - [toolbarBuilder]: builds the toolbar for showing suggestions for misspelled words.
  /// - [selectedWordHighlightColor]: the color to use when highlighting the selected word,
  ///   if it's a misspelled word.
  /// - [androidControlsController]: the controls controller to use when running on Android. This
  ///   is required when running on Android.
  /// - [iosControlsController]: the controls controller to use when running on iOS. This is
  ///   required when running on iOS.
  /// - [ignoreRules]: a list of rules that determine ranges that should be ignored from spellchecking.
  ///   It can be used,  for example, to ignore links or text with specific attributions. See [SpellingIgnoreRules]
  ///   for a list of built-in rules.
  /// - [spellCheckService]: a spell check service to use for spell checking. If this is provided,
  ///   the plugin will use this service instead of the default spell check service. The default spell checker
  ///   supports macOS, Android, and iOS.
  /// - [grammarCheckService]: a grammar check service to use for grammar checking. If this is provided,
  ///   the plugin will use this service instead of the default grammar check service. The default grammar checker
  ///   supports macOS only.
  SpellingAndGrammarPlugin({
    bool isSpellingCheckEnabled = true,
    UnderlineStyle spellingErrorUnderlineStyle = defaultSpellingErrorUnderlineStyle,
    bool isGrammarCheckEnabled = true,
    UnderlineStyle grammarErrorUnderlineStyle = defaultGrammarErrorUnderlineStyle,
    SpellingErrorSuggestionToolbarBuilder toolbarBuilder = defaultSpellingSuggestionToolbarBuilder,
    Color? selectedWordHighlightColor,
    SuperEditorAndroidControlsController? androidControlsController,
    SuperEditorIosControlsController? iosControlsController,
    List<SpellingIgnoreRule> ignoreRules = const [],
    SpellCheckService? spellCheckService,
    GrammarCheckService? grammarCheckService,
  })  : _isSpellCheckEnabled = isSpellingCheckEnabled,
        _isGrammarCheckEnabled = isGrammarCheckEnabled {
    assert(defaultTargetPlatform != TargetPlatform.android || androidControlsController != null,
        'The androidControlsController must be provided when running on Android.');

    assert(defaultTargetPlatform != TargetPlatform.iOS || iosControlsController != null,
        'The iosControlsController must be provided when running on iOS.');

    _spellCheckService = spellCheckService ??
        switch (defaultTargetPlatform) {
          TargetPlatform.macOS => MacSpellCheckService(),
          TargetPlatform.android || TargetPlatform.iOS => DefaultSpellCheckService(),
          _ => null,
        };

    _grammarCheckService = grammarCheckService ??
        switch (defaultTargetPlatform) {
          TargetPlatform.macOS => MacGrammarCheckService(),
          _ => null,
        };

    documentOverlayBuilders = <SuperEditorLayerBuilder>[
      SpellingErrorSuggestionOverlayBuilder(
        _spellingErrorSuggestions,
        _selectedWordLink,
        popoverController: _popoverController,
        toolbarBuilder: toolbarBuilder,
      ),
    ];

    _styler = SpellingAndGrammarStyler(
      selectionHighlightColor: selectedWordHighlightColor ??
          (defaultTargetPlatform == TargetPlatform.android //
              ? Colors.red.withValues(alpha: 0.3)
              : null),
    );

    _ignoreRules = ignoreRules;

    _contentTapHandler = switch (defaultTargetPlatform) {
      TargetPlatform.android => SuperEditorAndroidSpellCheckerTapHandler(
          popoverController: _popoverController,
          controlsController: androidControlsController!,
          styler: _styler,
        ),
      TargetPlatform.iOS => SuperEditorIosSpellCheckerTapHandler(
          popoverController: _popoverController,
          controlsController: iosControlsController!,
          styler: _styler,
        ),
      _ => _SuperEditorDesktopSpellCheckerTapHandler(popoverController: _popoverController),
    };
  }

  /// A service that provides spell checking functionality.
  late final SpellCheckService? _spellCheckService;

  /// A service that provides grammar checking functionality.
  late final GrammarCheckService? _grammarCheckService;

  final _spellingErrorSuggestions = SpellingErrorSuggestions();

  late final SpellingAndGrammarStyler _styler;

  /// Leader attached to an invisible rectangle around the currently selected
  /// misspelled word.
  final _selectedWordLink = LeaderLink();

  late final List<SpellingIgnoreRule> _ignoreRules;

  late final SpellingAndGrammarReaction _reaction;

  /// Whether this reaction checks spelling in the document.
  bool get isSpellCheckEnabled => _isSpellCheckEnabled;
  bool _isSpellCheckEnabled;
  set isSpellCheckEnabled(bool isEnabled) {
    _isSpellCheckEnabled = isEnabled;
    _reaction.isSpellCheckEnabled = isEnabled;
  }

  /// The [UnderlineStyle] applied to words of text that are mis-spelled.
  set spellingErrorUnderlineStyle(UnderlineStyle style) => _styler.spellingErrorUnderlineStyle = style;

  /// Whether this reaction checks grammar in the document.
  bool get isGrammarCheckEnabled => _isGrammarCheckEnabled;
  bool _isGrammarCheckEnabled;
  set isGrammarCheckEnabled(bool isEnabled) {
    _isGrammarCheckEnabled = isEnabled;
    _reaction.isGrammarCheckEnabled = isEnabled;
  }

  /// The [UnderlineStyle] applied to runs of text with incorrect grammar.
  set grammarErrorUnderlineStyle(UnderlineStyle style) => _styler.grammarErrorUnderlineStyle = style;

  /// A [SuperEditor] style phase that applies spelling error and grammar error
  /// underlines to text in the document.
  SpellingAndGrammarStyler get styler => _styler;

  /// [SuperEditor] overlay widgets that should be added to the [SuperEditor] this
  /// plugin is attached to.
  @override
  late final List<SuperEditorLayerBuilder> documentOverlayBuilders;

  @override
  List<ContentTapDelegate> get contentTapHandlers => _contentTapHandler != null //
      ? [_contentTapHandler!]
      : const [];
  late final _SpellCheckerContentTapDelegate? _contentTapHandler;

  final _popoverController = SpellCheckerPopoverController();

  @override
  List<SingleColumnLayoutStylePhase> get appendedStylePhases => [_styler];

  @override
  void attach(Editor editor) {
    editor.context.put(spellingErrorSuggestionsKey, _spellingErrorSuggestions);
    _contentTapHandler?.editor = editor;

    _reaction = SpellingAndGrammarReaction(
        _spellingErrorSuggestions, _styler, _ignoreRules, _spellCheckService!, _grammarCheckService);
    editor.reactionPipeline.add(_reaction);

    // Do initial spelling and grammar analysis, in case the document already
    // contains some content.
    _reaction.analyzeWholeDocument(editor.context);
  }

  @override
  void detach(Editor editor) {
    _styler.clearAllErrors();
    editor.reactionPipeline.remove(_reaction);
    _contentTapHandler?.editor = null;

    editor.context.remove(spellingErrorSuggestionsKey);
    _spellingErrorSuggestions.clear();
  }
}

extension SpellingAndGrammarEditableExtensions on EditContext {
  SpellingErrorSuggestions get spellingErrorSuggestions => find<SpellingErrorSuggestions>(
        SpellingAndGrammarPlugin.spellingErrorSuggestionsKey,
      );
}

extension SpellingAndGrammarEditorExtensions on Editor {
  /// Deletes the text within the given [wordRange] and replaces it with
  /// the given [correctSpelling].
  void fixMisspelledWord(DocumentRange wordRange, String correctSpelling) {
    execute([
      // Move caret to start of mis-spelled word so that we ensure the
      // caret location is legitimate after deleting the word. E.g.,
      // consider what would happen if the mis-spelled word is the last
      // word in the given paragraph.
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: wordRange.start,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      // Delete the mis-spelled word.
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: wordRange.start,
          end: wordRange.end.copyWith(
            nodePosition: TextNodePosition(
              // +1 to make end of range exclusive.
              offset: (wordRange.end.nodePosition as TextNodePosition).offset + 1,
            ),
          ),
        ),
      ),
      // Insert the correctly spelled word.
      InsertTextRequest(
        documentPosition: wordRange.start,
        textToInsert: correctSpelling,
        attributions: {},
      ),
      // Make the composing region to start at the end of the corrected word. Otherwise,
      // the software keyboard will keep the misspelled word bounds as the composing region.
      ChangeComposingRegionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: wordRange.start.nodeId,
            nodePosition: TextNodePosition(
              offset: (wordRange.start.nodePosition as TextNodePosition).offset + correctSpelling.length,
            ),
          ),
        ),
      ),
    ]);
  }

  void removeMisspelledWord(DocumentRange wordRange) {
    execute([
      // Move caret to start of mis-spelled word so that we ensure the
      // caret location is legitimate after deleting the word. E.g.,
      // consider what would happen if the mis-spelled word is the last
      // word in the given paragraph.
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: wordRange.start,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      // Delete the mis-spelled word.
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: wordRange.start,
          end: wordRange.end.copyWith(
            nodePosition: TextNodePosition(
              // +1 to make end of range exclusive.
              offset: (wordRange.end.nodePosition as TextNodePosition).offset + 1,
            ),
          ),
        ),
      ),
      const ClearComposingRegionRequest(),
    ]);
  }
}

/// An [EditReaction] that runs spelling and grammar checks on all [TextNode]s
/// in a given [Document].
class SpellingAndGrammarReaction implements EditReaction {
  SpellingAndGrammarReaction(
      this._suggestions, this._styler, this._ignoreRules, this._spellCheckService, this._grammarCheckService);

  final SpellingErrorSuggestions _suggestions;

  final SpellingAndGrammarStyler _styler;

  final List<SpellingIgnoreRule> _ignoreRules;

  final SpellCheckService _spellCheckService;

  final GrammarCheckService? _grammarCheckService;

  bool isSpellCheckEnabled = true;

  set spellingErrorUnderlineStyle(UnderlineStyle style) => _styler.spellingErrorUnderlineStyle = style;

  bool isGrammarCheckEnabled = true;

  set grammarErrorUnderlineStyle(UnderlineStyle style) => _styler.grammarErrorUnderlineStyle = style;

  /// A map from a document node to the ID of the most recent spelling and grammar
  /// check request ID.
  ///
  /// This map is used to ignore spell and grammar check responses that arrive after
  /// later spelling and grammar checks. This is a concern because we cross an async
  /// boundary to the platform to run such checks, removing any guarantee about order
  /// of receipt.
  final _asyncRequestIds = <String, int>{};

  /// Checks every [TextNode] in the given document for spelling and grammar
  /// errors and stores them for visual styling.
  void analyzeWholeDocument(EditContext editorContext) {
    for (final node in editorContext.document) {
      if (node is! TextNode) {
        continue;
      }

      _findSpellingAndGrammarErrors(node);
    }
  }

  @override
  void modifyContent(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    // No-op - spelling and grammar checks style the document, they don't alter the document.
  }

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (kIsWeb ||
        !const [TargetPlatform.macOS, TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) {
      // We currently only support spell check when running on Mac desktop or mobile platforms.
      return;
    }

    // Clear our request cache for any nodes that were deleted.
    // Also clear suggestions for deleted nodes.
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeRemovedEvent) {
        continue;
      }

      _suggestions.clearNode(change.nodeId);
      _asyncRequestIds.remove(change.nodeId);
    }

    if (!isSpellCheckEnabled && !isGrammarCheckEnabled) {
      return;
    }

    final document = editorContext.document;

    final changedTextNodes = <String>{};
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeChangeEvent) {
        continue;
      }

      final node = document.getNodeById(change.nodeId);
      if (node is! TextNode) {
        continue;
      }

      // A TextNode was changed in some way. Queue it for spelling and grammar checks.
      changedTextNodes.add(node.id);
    }

    for (final textNodeId in changedTextNodes) {
      final textNode = document.getNodeById(textNodeId);
      if (textNode == null) {
        editorSpellingAndGrammarLog.warning(
            "A TextNode that was listed as changed in a transaction somehow disappeared from the Document before this Reaction ran.");
        continue;
      }
      if (textNode is! TextNode) {
        editorSpellingAndGrammarLog.warning(
            "A TextNode that was listed as changed in a transaction somehow became a non-text node before this Reaction ran.");
        continue;
      }

      _findSpellingAndGrammarErrors(textNode);
    }
  }

  Future<void> _findSpellingAndGrammarErrors(TextNode textNode) async {
    final textErrors = <TextError>{};
    final spellingSuggestions = <TextRange, SpellingError>{};

    // Track this spelling and grammar request to make sure we don't process
    // the response out of order with other requests.
    _asyncRequestIds[textNode.id] ??= 0;
    final requestId = _asyncRequestIds[textNode.id]! + 1;
    _asyncRequestIds[textNode.id] = requestId;

    final plainText = _filterIgnoredRanges(textNode);

    if (isSpellCheckEnabled) {
      final suggestions = await _spellCheckService.fetchSpellCheckSuggestions(
        PlatformDispatcher.instance.locale,
        plainText,
      );
      if (suggestions != null) {
        for (final suggestion in suggestions) {
          final misspelledWord = plainText.substring(suggestion.range.start, suggestion.range.end);
          spellingSuggestions[suggestion.range] = SpellingError(
            word: misspelledWord,
            nodeId: textNode.id,
            range: suggestion.range,
            suggestions: suggestion.suggestions,
          );
          textErrors.add(
            TextError.spelling(
              nodeId: textNode.id,
              range: suggestion.range,
              value: misspelledWord,
              suggestions: suggestion.suggestions,
            ),
          );
        }
      }
    }

    if (isGrammarCheckEnabled && _grammarCheckService != null) {
      final grammarErrors = await _grammarCheckService!.checkGrammar(
        PlatformDispatcher.instance.locale,
        plainText,
      );

      if (grammarErrors != null) {
        for (final grammarError in grammarErrors) {
          final errorRange = grammarError.range;
          final text = plainText.substring(errorRange.start, errorRange.end);
          textErrors.add(
            TextError.grammar(
              nodeId: textNode.id,
              range: errorRange,
              value: text,
            ),
          );
        }
      }
    }

    if (requestId != _asyncRequestIds[textNode.id]) {
      // Another request was started for this node while we were running our
      // request. Fizzle.
      return;
    }
    // Reset the request ID counter to zero so that we avoid increasing infinitely.
    _asyncRequestIds[textNode.id] = 0;

    // Display underlines on spelling and grammar errors.
    _styler
      ..clearErrorsForNode(textNode.id)
      ..addErrors(textNode.id, textErrors);

    // Update the shared repository of spelling suggestions so that the user can
    // see suggestions and select them.
    _suggestions.putSuggestions(textNode.id, spellingSuggestions);
  }

  /// Filters out ranges that should be ignored from spellchecking.
  ///
  /// This method replaces the ignored ranges with whitespaces so that the spellchecker
  /// doesn't see them.
  String _filterIgnoredRanges(TextNode node) {
    final ranges = _ignoreRules //
        .map((rule) => rule(node))
        .expand((listOfRanges) => listOfRanges)
        .toList();

    final text = node.text.toPlainText();

    if (ranges.isEmpty) {
      // We don't have any ranges to remove, short circuit.
      return text;
    }

    final buffer = StringBuffer();

    final mergedRanges = _mergeOverlappingRanges(ranges);
    int currentOffset = 0;
    for (final range in mergedRanges) {
      if (range.start > currentOffset) {
        // We have text before the ignored range. Add it.
        buffer.write(text.substring(currentOffset, range.start));
      }

      // Fill the ignored range with whitespaces.
      buffer.write(' ' * (range.end - range.start));

      currentOffset = range.end;
    }

    // Add the remaining text, after the last ignored range, if any.
    if (currentOffset < text.length) {
      buffer.write(text.substring(currentOffset));
    }

    return buffer.toString();
  }

  /// Merges overlapping ranges in the given list of [ranges].
  ///
  /// Returns a new sorted list of ranges where overlapping ranges are merged.
  List<TextRange> _mergeOverlappingRanges(List<TextRange> ranges) {
    final sortedRanges = ranges.sorted((a, b) {
      if (a.start < b.start) {
        return -1;
      } else if (a.start > b.start) {
        return 1;
      }

      return a.end - b.end;
    });

    TextRange currentRange = sortedRanges.first;

    final mergedRanges = <TextRange>[];
    for (int i = 1; i < sortedRanges.length; i++) {
      final nextRange = sortedRanges[i];
      if (currentRange.end >= nextRange.start) {
        // The ranges overlap, merge them.
        currentRange = TextRange(
          start: currentRange.start,
          end: nextRange.end,
        );
      } else {
        // The ranges don't overlap.
        mergedRanges.add(currentRange);
        currentRange = nextRange;
      }
    }
    mergedRanges.add(currentRange);

    return mergedRanges;
  }
}

/// A [ContentTapDelegate] that shows the suggestions popover when the user taps on
/// a misspelled word.
///
/// When the suggestions popover is displayed, the selection expands to the whole word
/// and the selection handles are hidden.
class SuperEditorIosSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  SuperEditorIosSpellCheckerTapHandler({
    required this.popoverController,
    required this.controlsController,
    required this.styler,
  });

  final SpellCheckerPopoverController popoverController;
  final SuperEditorIosControlsController controlsController;
  final SpellingAndGrammarStyler styler;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final spelling = popoverController.findSuggestionsForWordAt(DocumentSelection.collapsed(position: tapPosition));
    if (spelling == null || spelling.suggestions.isEmpty) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    controlsController
      ..hideToolbar()
      ..hideMagnifier()
      ..preventSelectionHandles();

    // Select the whole word.
    editor!.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: tapPosition.nodeId,
            nodePosition: TextNodePosition(offset: spelling.range.start),
          ),
          extent: DocumentPosition(
            nodeId: tapPosition.nodeId,
            nodePosition: TextNodePosition(offset: spelling.range.end),
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    // Change the selection color while the suggestions popover is visible.
    styler.overrideSelectionColor();

    popoverController.showSuggestions(spelling);

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  @override
  TapHandlingInstruction onPanStart(DocumentTapDetails details) {
    if (popoverController.isShowing) {
      _hideSpellCheckerPopover();
    }
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    styler.useDefaultSelectionColor();
    controlsController.allowSelectionHandles();
    popoverController.hide();
  }
}

/// A [ContentTapDelegate] that shows the suggestions popover when the user taps on
/// a misspelled word.
///
/// When the suggestions popover is displayed, the selection and the composing region
/// expand to the whole word and the selection handles are hidden.
class SuperEditorAndroidSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  SuperEditorAndroidSpellCheckerTapHandler({
    required this.popoverController,
    required this.controlsController,
    required this.styler,
  });

  final SpellCheckerPopoverController popoverController;
  final SuperEditorAndroidControlsController controlsController;
  final SpellingAndGrammarStyler styler;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final selectionAtTapPosition = DocumentSelection.collapsed(position: tapPosition);

    final spelling = popoverController.findSuggestionsForWordAt(selectionAtTapPosition);
    if (spelling == null || spelling.suggestions.isEmpty) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    // On Android, tapping on a misspelled word first places the caret at the tap
    // position, then expands the selection to the whole word and shows the suggestions
    // popover, after a brief delay.
    editor!.execute([
      ChangeSelectionRequest(
        selectionAtTapPosition,
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      ChangeComposingRegionRequest(selectionAtTapPosition),
    ]);

    // Allow the selection handles, otherwise the caret won't be visible prior
    // to expanding the selection.
    controlsController.allowSelectionHandles();

    Timer(const Duration(milliseconds: 300), () {
      // Hide all controls and prevent handles being displayed. We don't want
      // to display drag handles while the suggestion popover is visible.
      controlsController
        ..hideToolbar()
        ..hideMagnifier()
        ..hideToolbar()
        ..preventSelectionHandles();

      // The word bounds around the tap position.
      final wordSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: tapPosition.nodeId,
          nodePosition: TextNodePosition(offset: spelling.range.start),
        ),
        extent: DocumentPosition(
          nodeId: tapPosition.nodeId,
          nodePosition: TextNodePosition(offset: spelling.range.end),
        ),
      );

      // Select the whole word and update the composing region to match
      // the Android behavior of placing the whole word on the composing
      // region when tapping at a word.
      editor!.execute([
        ChangeSelectionRequest(
          wordSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(wordSelection),
      ]);

      // Change the selection color while the suggestion popover is visible.
      styler.overrideSelectionColor();

      popoverController.showSuggestions(
        spelling,
        // When the user dismisses the popover, we want to restore the selection
        // to the exact tap position.
        onDismiss: () {
          editor!.execute([
            ChangeSelectionRequest(
              selectionAtTapPosition,
              SelectionChangeType.placeCaret,
              SelectionReason.userInteraction,
            ),
            ChangeComposingRegionRequest(selectionAtTapPosition),
          ]);

          _hideSpellCheckerPopover();
        },
      );
    });

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    controlsController.allowSelectionHandles();
    styler.useDefaultSelectionColor();
    popoverController.hide();
  }
}

/// A [ContentTapDelegate] that shows the suggestions popover when the user taps on
/// a misspelled word.
class _SuperEditorDesktopSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  _SuperEditorDesktopSpellCheckerTapHandler({
    required this.popoverController,
  });

  final SpellCheckerPopoverController popoverController;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final spelling = popoverController.findSuggestionsForWordAt(DocumentSelection.collapsed(position: tapPosition));
    if (spelling == null || spelling.suggestions.isEmpty) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    editor!.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: tapPosition),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    popoverController.showSuggestions(spelling);

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    popoverController.hide();
  }
}

/// A [ContentTapDelegate] that has access to the [editor] while the
/// plugin is attached to it.
class _SpellCheckerContentTapDelegate extends ContentTapDelegate {
  _SpellCheckerContentTapDelegate();

  Editor? editor;
}

/// A function that determines ranges to be ignored from spellchecking.
typedef SpellingIgnoreRule = List<TextRange> Function(TextNode node);

/// A collection of built-in rules for ignoring spans of text from spellchecking.
class SpellingIgnoreRules {
  /// Creates a rule that ignores text spans that match the given [pattern].
  static SpellingIgnoreRule byPattern(Pattern pattern) {
    return (TextNode node) {
      return pattern
          .allMatches(node.text.toPlainText())
          .map((match) => TextRange(start: match.start, end: match.end))
          .toList();
    };
  }

  /// Creates a rule that ignores text spans that have the given [attribution].
  static SpellingIgnoreRule byAttribution(Attribution attribution) {
    return byAttributionFilter((candidate) => candidate == attribution);
  }

  /// Creates a rule that ignore text spans that have at least one atribution that matches the given [filter].
  static SpellingIgnoreRule byAttributionFilter(AttributionFilter filter) {
    return (TextNode node) {
      return node.text.spans
          .getAttributionSpansInRange(
            attributionFilter: filter,
            start: 0,
            end: node.text.toPlainText().length - 1, // -1 to make end of range inclusive.
          )
          .map((span) => TextRange(start: span.start, end: span.end + 1)) // +1 to make the end exclusive.
          .toList();
    };
  }
}

/// A [SpellCheckService] that uses a macOS plugin to check spelling.
class MacSpellCheckService implements SpellCheckService {
  final _macSpellChecker = SuperEditorSpellCheckerPlugin().macSpellChecker;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    // TODO: Investigate whether we can parallelize spelling and grammar checks
    //       for a given node (and whether it's worth the complexity).

    final suggestionSpans = <SuggestionSpan>[];

    int startingOffset = 0;
    TextRange prevError = TextRange.empty;
    final locale = PlatformDispatcher.instance.locale;
    final language = _macSpellChecker.convertDartLocaleToMacLanguageCode(locale)!;
    do {
      prevError = await _macSpellChecker.checkSpelling(
        stringToCheck: text,
        startingOffset: startingOffset,
        language: language,
      );

      if (prevError.isValid) {
        final guesses = await _macSpellChecker.guesses(range: prevError, text: text);
        suggestionSpans.add(SuggestionSpan(prevError, guesses));
        startingOffset = prevError.end;
      }
    } while (prevError.isValid);

    return suggestionSpans;
  }
}

/// A service that knows how to check grammar on a text.
abstract class GrammarCheckService {
  /// Checks the given [text] for grammar errors with the given [locale].
  ///
  /// Returns a list of [GrammarError]s where each item represents a sentence
  /// that has a grammatical error, with details about the error.
  ///
  /// Returns an empty list if no grammar errors are found or if the [locale]
  /// isn't supported by the grammar checker.
  ///
  /// Returns `null` if the check was unsucessful.
  Future<List<GrammarError>?> checkGrammar(Locale locale, String text);
}

/// A [GrammarCheckService] that uses a macOS plugin to check grammar.
class MacGrammarCheckService implements GrammarCheckService {
  final _macSpellChecker = SuperEditorSpellCheckerPlugin().macSpellChecker;

  @override
  Future<List<GrammarError>?> checkGrammar(Locale locale, String text) async {
    final errors = <GrammarError>[];

    final language = _macSpellChecker.convertDartLocaleToMacLanguageCode(locale)!;

    int startingOffset = 0;
    TextRange prevError = TextRange.empty;
    do {
      final result = await _macSpellChecker.checkGrammar(
        stringToCheck: text,
        startingOffset: startingOffset,
        language: language,
      );
      prevError = result.firstError ?? TextRange.empty;

      if (prevError.isValid) {
        errors.addAll(
          result.details.map(
            (detail) => GrammarError(
              range: detail.range,
              description: detail.userDescription,
            ),
          ),
        );

        startingOffset = prevError.end;
      }
    } while (prevError.isValid);

    return errors;
  }
}

/// A grammatical error found in a text at [range].
class GrammarError {
  GrammarError({
    required this.range,
    required this.description,
  });

  /// The range of text that has a grammatical error.
  final TextRange range;

  /// The description of the grammatical error.
  final String description;
}
