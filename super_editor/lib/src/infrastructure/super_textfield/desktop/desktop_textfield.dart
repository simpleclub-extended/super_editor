import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/focus.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../../ime_input_owner.dart';
import '../../keyboard.dart';
import '../../multi_tap_gesture.dart';
import '../infrastructure/fill_width_if_constrained.dart';

final _log = textFieldLog;

/// Highly configurable text field intended for web and desktop uses.
///
/// [SuperDesktopTextField] provides two advantages over a typical [TextField].
/// First, [SuperDesktopTextField] is based on [AttributedText], which is a far
/// more useful foundation for styled text display than [TextSpan]. Second,
/// [SuperDesktopTextField] provides deeper control over various visual properties
/// including selection painting, caret painting, hint display, and keyboard
/// interaction.
///
/// If [SuperDesktopTextField] does not provide the desired level of configuration,
/// look at its implementation. Unlike Flutter's [TextField], [SuperDesktopTextField]
/// is composed of a few widgets that you can recompose to create your own
/// flavor of a text field.
class SuperDesktopTextField extends StatefulWidget {
  const SuperDesktopTextField({
    Key? key,
    this.focusNode,
    this.textController,
    this.textStyleBuilder = defaultTextFieldStyleBuilder,
    this.textAlign = TextAlign.left,
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.hintBuilder,
    this.selectionHighlightStyle = const SelectionHighlightStyle(
      color: Color(0xFFACCEF7),
    ),
    this.caretStyle = const CaretStyle(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
    this.padding = EdgeInsets.zero,
    this.minLines,
    this.maxLines = 1,
    this.decorationBuilder,
    this.onRightClick,
    this.inputSource = TextInputSource.keyboard,
    List<TextFieldKeyboardHandler>? keyboardHandlers,
  })  : keyboardHandlers = keyboardHandlers ??
            (inputSource == TextInputSource.keyboard
                ? defaultTextFieldKeyboardHandlers
                : defaultTextFieldImeKeyboardHandlers),
        super(key: key);

  final FocusNode? focusNode;

  final AttributedTextEditingController? textController;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  final AttributionStyleBuilder textStyleBuilder;

  /// Policy for when the hint should be displayed.
  final HintBehavior hintBehavior;

  /// Builder that creates the hint widget, when a hint is displayed.
  ///
  /// To easily build a hint with styled text, see [StyledHintBuilder].
  final WidgetBuilder? hintBuilder;

  /// The alignment to use for text in this text field.
  final TextAlign textAlign;

  /// The visual representation of the user's selection highlight.
  final SelectionHighlightStyle selectionHighlightStyle;

  /// The visual representation of the caret in this `SelectableText` widget.
  final CaretStyle caretStyle;

  final EdgeInsetsGeometry padding;

  final int? minLines;
  final int? maxLines;

  final DecorationBuilder? decorationBuilder;

  final RightClickListener? onRightClick;

  /// The [SuperDesktopTextField] input source, e.g., keyboard or Input Method Engine.
  final TextInputSource inputSource;

  /// Priority list of handlers that process all physical keyboard
  /// key presses, for text input, deletion, caret movement, etc.
  ///
  /// If the [inputSource] is [TextInputSource.ime], text input is already handled
  /// using [TextEditingDelta]s, so this list shouldn't include handlers
  /// that input text based on individual character key presses.
  final List<TextFieldKeyboardHandler> keyboardHandlers;

  @override
  SuperDesktopTextFieldState createState() => SuperDesktopTextFieldState();
}

class SuperDesktopTextFieldState extends State<SuperDesktopTextField> implements ProseTextBlock, ImeInputOwner {
  final _textKey = GlobalKey<ProseTextState>();
  final _textScrollKey = GlobalKey<SuperTextFieldScrollviewState>();
  late FocusNode _focusNode;
  bool _hasFocus = false; // cache whether we have focus so we know when it changes

  late ImeAttributedTextEditingController _controller;
  late ScrollController _scrollController;

  double? _viewportHeight;

  final _estimatedLineHeight = _EstimatedLineHeight();

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_updateSelectionOnFocusChange);

    _controller = widget.textController != null
        ? widget.textController is ImeAttributedTextEditingController
            ? (widget.textController as ImeAttributedTextEditingController)
            : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
        : ImeAttributedTextEditingController();
    _controller.addListener(_onSelectionOrContentChange);

    _scrollController = ScrollController();

    // Check if we need to update the selection.
    _updateSelectionOnFocusChange();
  }

  @override
  void didUpdateWidget(SuperDesktopTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_updateSelectionOnFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_updateSelectionOnFocusChange);

      // Check if we need to update the selection.
      _updateSelectionOnFocusChange();
    }

    if (widget.textController != oldWidget.textController) {
      _controller.removeListener(_onSelectionOrContentChange);
      // When the given textController isn't an ImeAttributedTextEditingController,
      // we wrap it with one. So we need to dispose it.
      if (oldWidget.textController == null || oldWidget.textController is! ImeAttributedTextEditingController) {
        _controller.dispose();
      }
      _controller = widget.textController != null
          ? widget.textController is ImeAttributedTextEditingController
              ? (widget.textController as ImeAttributedTextEditingController)
              : ImeAttributedTextEditingController(controller: widget.textController, disposeClientController: false)
          : ImeAttributedTextEditingController();

      _controller.addListener(_onSelectionOrContentChange);
    }

    if (widget.padding != oldWidget.padding ||
        widget.minLines != oldWidget.minLines ||
        widget.maxLines != oldWidget.maxLines) {
      _onSelectionOrContentChange();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.removeListener(_updateSelectionOnFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller
      ..removeListener(_onSelectionOrContentChange)
      ..detachFromIme();
    if (widget.textController == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  ProseTextLayout get textLayout => _textKey.currentState!.textLayout;

  @override
  @visibleForTesting
  DeltaTextInputClient get imeClient => _controller;

  FocusNode get focusNode => _focusNode;

  double get _textScaleFactor => MediaQuery.textScaleFactorOf(context);

  void requestFocus() {
    _focusNode.requestFocus();
  }

  void _updateSelectionOnFocusChange() {
    // If our FocusNode just received focus, automatically set our
    // controller's text position to the end of the available content.
    //
    // This behavior matches Flutter's standard behavior.
    if (_focusNode.hasFocus && !_hasFocus && _controller.selection.extentOffset == -1) {
      _controller.selection = TextSelection.collapsed(offset: _controller.text.text.length);
    }
    _hasFocus = _focusNode.hasFocus;
  }

  AttributedTextEditingController get controller => _controller;

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _updateViewportHeight();
      }
    });
  }

  /// Returns true if the viewport height changed, false otherwise.
  bool _updateViewportHeight() {
    final estimatedLineHeight = _getEstimatedLineHeight();
    final estimatedLinesOfText = _getEstimatedLinesOfText();
    final estimatedContentHeight = (estimatedLinesOfText * estimatedLineHeight) + widget.padding.vertical;
    final minHeight = widget.minLines != null ? widget.minLines! * estimatedLineHeight + widget.padding.vertical : null;
    final maxHeight = widget.maxLines != null ? widget.maxLines! * estimatedLineHeight + widget.padding.vertical : null;
    double? viewportHeight;
    if (maxHeight != null && estimatedContentHeight > maxHeight) {
      viewportHeight = maxHeight;
    } else if (minHeight != null && estimatedContentHeight < minHeight) {
      viewportHeight = minHeight;
    }

    if (viewportHeight == _viewportHeight) {
      // The height of the viewport hasn't changed. Return.
      return false;
    }

    setState(() {
      _viewportHeight = viewportHeight;
    });

    return true;
  }

  int _getEstimatedLinesOfText() {
    if (_controller.text.text.isEmpty) {
      return 0;
    }

    if (_textKey.currentState == null) {
      return 0;
    }

    final offsetAtEndOfText = textLayout.getOffsetAtPosition(TextPosition(offset: _controller.text.text.length));
    int lineCount = (offsetAtEndOfText.dy / _getEstimatedLineHeight()).ceil();

    if (_controller.text.text.endsWith('\n')) {
      lineCount += 1;
    }

    return lineCount;
  }

  double _getEstimatedLineHeight() {
    // After hot reloading, the text layout might be null, so we can't
    // directly use _textKey.currentState!.textLayout because using it
    // we can't check for null.
    final textLayout = RenderSuperTextLayout.textLayoutFrom(_textKey);
    final lineHeight = _controller.text.text.isEmpty || textLayout == null
        ? 0.0
        : textLayout.getLineHeightAtPosition(const TextPosition(offset: 0));
    if (lineHeight > 0) {
      return lineHeight;
    }
    final defaultStyle = widget.textStyleBuilder({});
    return _estimatedLineHeight.calculate(defaultStyle, _textScaleFactor);
  }

  @override
  Widget build(BuildContext context) {
    if (_textKey.currentContext == null) {
      // The text hasn't been laid out yet, which means our calculations
      // for text height is probably wrong. Schedule a post frame callback
      // to re-calculate the height after initial layout.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {
            _updateViewportHeight();
          });
        }
      });
    }

    final isMultiline = widget.minLines != 1 || widget.maxLines != 1;

    return _buildTextInputSystem(
      isMultiline: isMultiline,
      child: SuperTextFieldGestureInteractor(
        focusNode: _focusNode,
        textController: _controller,
        textKey: _textKey,
        textScrollKey: _textScrollKey,
        isMultiline: isMultiline,
        onRightClick: widget.onRightClick,
        child: MultiListenableBuilder(
          listenables: {
            _focusNode,
            _controller,
          },
          builder: (context) {
            final isTextEmpty = _controller.text.text.isEmpty;
            final showHint = widget.hintBuilder != null &&
                ((isTextEmpty && widget.hintBehavior == HintBehavior.displayHintUntilTextEntered) ||
                    (isTextEmpty && !_focusNode.hasFocus && widget.hintBehavior == HintBehavior.displayHintUntilFocus));

            return _buildDecoration(
              child: SuperTextFieldScrollview(
                key: _textScrollKey,
                textKey: _textKey,
                textController: _controller,
                textAlign: widget.textAlign,
                scrollController: _scrollController,
                viewportHeight: _viewportHeight,
                estimatedLineHeight: _getEstimatedLineHeight(),
                padding: widget.padding,
                isMultiline: isMultiline,
                child: Stack(
                  children: [
                    if (showHint) widget.hintBuilder!(context),
                    _buildSelectableText(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDecoration({
    required Widget child,
  }) {
    return widget.decorationBuilder != null ? widget.decorationBuilder!(context, child) : child;
  }

  Widget _buildTextInputSystem({
    required bool isMultiline,
    required Widget child,
  }) {
    return SuperTextFieldKeyboardInteractor(
      focusNode: _focusNode,
      textController: _controller,
      textKey: _textKey,
      keyboardActions: widget.keyboardHandlers,
      child: widget.inputSource == TextInputSource.ime
          ? SuperTextFieldImeInteractor(
              focusNode: _focusNode,
              textController: _controller,
              isMultiline: isMultiline,
              child: child,
            )
          : child,
    );
  }

  Widget _buildSelectableText() {
    return FillWidthIfConstrained(
      child: SuperTextWithSelection.single(
        key: _textKey,
        richText: _controller.text.computeTextSpan(widget.textStyleBuilder),
        textAlign: widget.textAlign,
        textScaleFactor: _textScaleFactor,
        userSelection: UserSelection(
          highlightStyle: widget.selectionHighlightStyle,
          caretStyle: widget.caretStyle,
          selection: _controller.selection,
          hasCaret: _focusNode.hasFocus,
        ),
      ),
    );
  }
}

typedef DecorationBuilder = Widget Function(BuildContext, Widget child);

/// Handles all user gesture interactions for text entry.
///
/// [SuperTextFieldGestureInteractor] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldGestureInteractor]
/// is defined on its own so that it can be replaced with a widget that handles
/// gestures differently.
///
/// The gestures are applied to a [SuperSelectableText] widget that is
/// tied to [textKey].
///
/// A [SuperTextFieldScrollview] must sit between this [SuperTextFieldGestureInteractor]
/// and the underlying [SuperSelectableText]. That [SuperTextFieldScrollview] must
/// be tied to [textScrollKey].
class SuperTextFieldGestureInteractor extends StatefulWidget {
  const SuperTextFieldGestureInteractor({
    Key? key,
    required this.focusNode,
    required this.textController,
    required this.textKey,
    required this.textScrollKey,
    required this.isMultiline,
    this.onRightClick,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  /// [TextController] for the text/selection within this text field.
  final AttributedTextEditingController textController;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [SuperTextFieldScrollview] that's responsible for scrolling
  /// content that exceeds the available space within this text field.
  final GlobalKey<SuperTextFieldScrollviewState> textScrollKey;

  /// Whether or not this text field supports multiple lines of text.
  final bool isMultiline;

  /// Callback invoked when the user right clicks on this text field.
  final RightClickListener? onRightClick;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State createState() => _SuperTextFieldGestureInteractorState();
}

class _SuperTextFieldGestureInteractorState extends State<SuperTextFieldGestureInteractor> {
  _SelectionType _selectionType = _SelectionType.position;
  Offset? _dragStartInViewport;
  Offset? _dragStartInText;
  Offset? _dragEndInViewport;
  Offset? _dragEndInText;
  Rect? _dragRectInViewport;

  final _dragGutterExtent = 24;
  final _maxDragSpeed = 20;

  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  SuperTextFieldScrollviewState get _textScroll => widget.textScrollKey.currentState!;

  void _onTapDown(TapDownDetails details) {
    _log.fine('Tap down on SuperTextField');
    _selectionType = _SelectionType.position;

    final textOffset = _getTextOffset(details.localPosition);
    final tapTextPosition = _getPositionNearestToTextOffset(textOffset);
    _log.finer("Tap text position: $tapTextPosition");

    final expandSelection = RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shift);

    setState(() {
      widget.textController.selection = expandSelection
          ? TextSelection(
              baseOffset: widget.textController.selection.baseOffset,
              extentOffset: tapTextPosition.offset,
            )
          : TextSelection.collapsed(offset: tapTextPosition.offset);

      _log.finer("New text field selection: ${widget.textController.selection}");
    });

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.word;

    _log.finer('_onDoubleTapDown - EditableDocument: onDoubleTap()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.textController.selection = _textLayout.getWordSelectionAt(tapTextPosition);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.paragraph;

    _log.finer('_onTripleTapDown - EditableDocument: onTripleTapDown()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.textController.selection = _getParagraphSelectionAt(tapTextPosition, TextAffinity.downstream);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onRightClick(TapUpDetails details) {
    widget.onRightClick?.call(context, widget.textController, details.localPosition);
  }

  void _onPanStart(DragStartDetails details) {
    _log.fine("User started pan");
    _dragStartInViewport = details.localPosition;
    _dragStartInText = _getTextOffset(_dragStartInViewport!);

    _dragRectInViewport = Rect.fromLTWH(_dragStartInViewport!.dx, _dragStartInViewport!.dy, 1, 1);

    widget.focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.finer("User moved during pan");
    setState(() {
      _dragEndInViewport = details.localPosition;
      _dragEndInText = _getTextOffset(_dragEndInViewport!);
      _dragRectInViewport = Rect.fromPoints(_dragStartInViewport!, _dragEndInViewport!);
      _log.finer('_onPanUpdate - drag rect: $_dragRectInViewport');
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _log.finer("User ended a pan");
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll.stopScrollingToStart();
    _textScroll.stopScrollingToEnd();
  }

  void _onPanCancel() {
    _log.finer("User cancelled a pan");
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll.stopScrollingToStart();
    _textScroll.stopScrollingToEnd();
  }

  void _updateDragSelection() {
    if (_dragStartInText == null || _dragEndInText == null) {
      return;
    }

    setState(() {
      final startDragOffset = _getPositionNearestToTextOffset(_dragStartInText!).offset;
      final endDragOffset = _getPositionNearestToTextOffset(_dragEndInText!).offset;
      final affinity = startDragOffset <= endDragOffset ? TextAffinity.downstream : TextAffinity.upstream;

      if (_selectionType == _SelectionType.paragraph) {
        final baseParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: startDragOffset), affinity);
        final extentParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: endDragOffset), affinity);

        widget.textController.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else if (_selectionType == _SelectionType.word) {
        final baseParagraphSelection = _textLayout.getWordSelectionAt(TextPosition(offset: startDragOffset));
        final extentParagraphSelection = _textLayout.getWordSelectionAt(TextPosition(offset: endDragOffset));

        widget.textController.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else {
        widget.textController.selection = TextSelection(
          baseOffset: startDragOffset,
          extentOffset: endDragOffset,
        );
      }
    });
  }

  TextSelection _combineSelections(
    TextSelection selection1,
    TextSelection selection2,
    TextAffinity affinity,
  ) {
    return affinity == TextAffinity.downstream
        ? TextSelection(
            baseOffset: min(selection1.start, selection2.start),
            extentOffset: max(selection1.end, selection2.end),
          )
        : TextSelection(
            baseOffset: max(selection1.end, selection2.end),
            extentOffset: min(selection1.start, selection2.start),
          );
  }

  void _clearSelection() {
    setState(() {
      widget.textController.selection = const TextSelection.collapsed(offset: -1);
    });
  }

  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // TODO: remove access to _textScroll.widget
      final newScrollOffset = (_textScroll.widget.scrollController.offset + event.scrollDelta.dy)
          .clamp(0.0, _textScroll.widget.scrollController.position.maxScrollExtent);
      _textScroll.widget.scrollController.jumpTo(newScrollOffset);

      _updateDragSelection();
    }
  }

  void _scrollIfNearBoundary() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollIfNearBoundary - Can't scroll near boundary because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    if (!widget.isMultiline) {
      _scrollIfNearHorizontalBoundary();
    } else {
      _scrollIfNearVerticalBoundary();
    }
  }

  void _scrollIfNearHorizontalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToStart();
    } else {
      _stopScrollingToStart();
    }
    if (editorBox.size.width - _dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToEnd();
    } else {
      _stopScrollingToEnd();
    }
  }

  void _scrollIfNearVerticalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToStart();
      return;
    } else {
      _stopScrollingToStart();
    }

    if (editorBox.size.height - _dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToEnd();
      return;
    } else {
      _stopScrollingToEnd();
    }
  }

  void _startScrollingToStart() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollUp - Can't scroll up because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final gutterAmount = _dragEndInViewport!.dy.clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = ui.lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll.startScrollingToStart(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToStart() {
    _textScroll.stopScrollingToStart();
  }

  void _startScrollingToEnd() {
    if (_dragEndInViewport == null) {
      _log.finer("_scrollDown - Can't scroll down because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final editorBox = context.findRenderObject() as RenderBox;
    final gutterAmount = (editorBox.size.height - _dragEndInViewport!.dy).clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = ui.lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll.startScrollingToEnd(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToEnd() {
    _textScroll.stopScrollingToEnd();
  }

  TextPosition? _getPositionAtOffset(Offset textFieldOffset) {
    final textOffset = _getTextOffset(textFieldOffset);
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;

    return textBox.size.contains(textOffset) ? _textLayout.getPositionAtOffset(textOffset) : null;
  }

  TextSelection _getParagraphSelectionAt(TextPosition textPosition, TextAffinity affinity) {
    return _textLayout.expandSelection(textPosition, paragraphExpansionFilter, affinity);
  }

  TextPosition _getPositionNearestToTextOffset(Offset textOffset) {
    return _textLayout.getPositionNearestToOffset(textOffset);
  }

  Offset _getTextOffset(Offset textFieldOffset) {
    final textFieldBox = context.findRenderObject() as RenderBox;
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(textFieldOffset, ancestor: textFieldBox);
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onSecondaryTapUp: _onRightClick,
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
              () => TapSequenceGestureRecognizer(),
              (TapSequenceGestureRecognizer recognizer) {
                recognizer
                  ..onTapDown = _onTapDown
                  ..onDoubleTapDown = _onDoubleTapDown
                  ..onDoubleTap = _onDoubleTap
                  ..onTripleTapDown = _onTripleTapDown
                  ..onTripleTap = _onTripleTap
                  ..gestureSettings = gestureSettings;
              },
            ),
            PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(
                supportedDevices: {PointerDeviceKind.mouse},
              ),
              (PanGestureRecognizer recognizer) {
                recognizer
                  ..onStart = _onPanStart
                  ..onUpdate = _onPanUpdate
                  ..onEnd = _onPanEnd
                  ..onCancel = _onPanCancel
                  ..gestureSettings = gestureSettings;
              },
            ),
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Handles all keyboard interactions for text entry in a text field.
///
/// [SuperTextFieldKeyboardInteractor] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldKeyboardInteractor]
/// is defined on its own so that it can be replaced with a widget that handles
/// key events differently.
///
/// The key events are passed down the [keyboardActions] Chain of Responsibility.
/// Each handler is given a reference to the [textController], to manipulate the
/// text content, and a [TextLayout] via the [textKey], which can be used to make
/// decisions about manipulations, such as moving the caret to the beginning/end
/// of a line.
class SuperTextFieldKeyboardInteractor extends StatefulWidget {
  const SuperTextFieldKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.textController,
    required this.textKey,
    required this.keyboardActions,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  /// [TextController] for the text/selection within this text field.
  final AttributedTextEditingController textController;

  /// [GlobalKey] that links this [SuperTextFieldGestureInteractor] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// Ordered list of actions that correspond to various key events.
  ///
  /// Each handler in the list may be given a key event from the keyboard. That
  /// handler chooses to take an action, or not. A handler must respond with
  /// a [TextFieldKeyboardHandlerResult], which indicates how the key event was handled,
  /// or not.
  ///
  /// When a handler reports [TextFieldKeyboardHandlerResult.notHandled], the key event
  /// is sent to the next handler.
  ///
  /// As soon as a handler reports [TextFieldKeyboardHandlerResult.handled], no other
  /// handler is executed and the key event is prevented from propagating up
  /// the widget tree.
  ///
  /// When a handler reports [TextFieldKeyboardHandlerResult.blocked], no other
  /// handler is executed, but the key event **continues** to propagate up
  /// the widget tree for other listeners to act upon.
  ///
  /// If all handlers report [TextFieldKeyboardHandlerResult.notHandled], the key
  /// event propagates up the widget tree for other listeners to act upon.
  final List<TextFieldKeyboardHandler> keyboardActions;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State createState() => _SuperTextFieldKeyboardInteractorState();
}

class _SuperTextFieldKeyboardInteractorState extends State<SuperTextFieldKeyboardInteractor> {
  KeyEventResult _onKeyPressed(FocusNode focusNode, RawKeyEvent keyEvent) {
    _log.fine('_onKeyPressed - keyEvent: ${keyEvent.logicalKey}, character: ${keyEvent.character}');
    if (keyEvent is! RawKeyDownEvent) {
      _log.finer('_onKeyPressed - not a "down" event. Ignoring.');
      return KeyEventResult.ignored;
    }

    TextFieldKeyboardHandlerResult result = TextFieldKeyboardHandlerResult.notHandled;
    int index = 0;
    while (result == TextFieldKeyboardHandlerResult.notHandled && index < widget.keyboardActions.length) {
      result = widget.keyboardActions[index](
        controller: widget.textController,
        textLayout: widget.textKey.currentState!.textLayout,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    _log.finest("Key handler result: $result");
    return result == TextFieldKeyboardHandlerResult.handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return NonReparentingFocus(
      focusNode: widget.focusNode,
      onKey: _onKeyPressed,
      child: widget.child,
    );
  }
}

/// Opens and closes an IME connection based on changes to focus and selection.
///
/// This widget watches [focusNode] for focus changes, and [textController] for
/// selection changes.
///
/// All IME commands are handled and applied to text field text by the given [textController].
///
/// When [focusNode] gains focus, if the [textController] doesn't have a selection, the caret is
/// placed at the end of the text.
///
/// When [focusNode] loses focus, the [textController]'s selection is cleared.
class SuperTextFieldImeInteractor extends StatefulWidget {
  const SuperTextFieldImeInteractor({
    Key? key,
    required this.focusNode,
    required this.textController,
    required this.isMultiline,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for this text field.
  final FocusNode focusNode;

  /// Controller for the text/selection within this text field.
  final ImeAttributedTextEditingController textController;

  /// Whether or not this text field supports multiple lines of text.
  final bool isMultiline;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  State<SuperTextFieldImeInteractor> createState() => _SuperTextFieldImeInteractorState();
}

class _SuperTextFieldImeInteractorState extends State<SuperTextFieldImeInteractor> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_updateSelectionAndImeConnectionOnFocusChange);

    if (widget.focusNode.hasFocus) {
      // We got an already focused FocusNode, we need to attach to the IME.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _updateSelectionAndImeConnectionOnFocusChange();
      });
    }
  }

  @override
  void didUpdateWidget(SuperTextFieldImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
      widget.focusNode.addListener(_updateSelectionAndImeConnectionOnFocusChange);

      if (widget.focusNode.hasFocus) {
        // We got an already focused FocusNode, we need to attach to the IME.
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _updateSelectionAndImeConnectionOnFocusChange();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_updateSelectionAndImeConnectionOnFocusChange);
    super.dispose();
  }

  void _updateSelectionAndImeConnectionOnFocusChange() {
    if (widget.focusNode.hasFocus) {
      if (!widget.textController.isAttachedToIme) {
        _log.info('Attaching TextInputClient to TextInput');
        setState(() {
          if (!widget.textController.selection.isValid) {
            widget.textController.selection = TextSelection.collapsed(offset: widget.textController.text.text.length);
          }

          widget.textController.attachToIme(
            textInputType: widget.isMultiline ? TextInputType.multiline : TextInputType.text,
          );
        });
      }
    } else {
      _log.info('Lost focus. Detaching TextInputClient from TextInput.');
      setState(() {
        widget.textController.detachFromIme();
        widget.textController.selection = const TextSelection.collapsed(offset: -1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Handles all scrolling behavior for a text field.
///
/// [SuperTextFieldScrollview] is intended to operate as a piece within
/// a larger composition that behaves as a text field. [SuperTextFieldScrollview]
/// is defined on its own so that it can be replaced with a widget that handles
/// scrolling differently.
///
/// [SuperTextFieldScrollview] determines when and where to scroll by working
/// with a corresponding [SuperSelectableText] widget that is tied to [textKey].
class SuperTextFieldScrollview extends StatefulWidget {
  const SuperTextFieldScrollview({
    Key? key,
    required this.textKey,
    required this.textController,
    required this.scrollController,
    required this.padding,
    required this.viewportHeight,
    required this.estimatedLineHeight,
    required this.isMultiline,
    this.textAlign = TextAlign.left,
    required this.child,
  }) : super(key: key);

  /// [TextController] for the text/selection within this text field.
  final AttributedTextEditingController textController;

  /// [GlobalKey] that links this [SuperTextFieldScrollview] to
  /// the [ProseTextLayout] widget that paints the text for this text field.
  final GlobalKey<ProseTextState> textKey;

  /// [ScrollController] that controls the scroll offset of this [SuperTextFieldScrollview].
  final ScrollController scrollController;

  /// Padding placed around the text content of this text field, but within the
  /// scrollable viewport.
  final EdgeInsetsGeometry padding;

  /// The height of the viewport for this text field.
  ///
  /// If [null] then the viewport is permitted to grow/shrink to any desired height.
  final double? viewportHeight;

  /// An estimate for the height in pixels of a single line of text within this
  /// text field.
  final double estimatedLineHeight;

  /// Whether or not this text field allows multiple lines of text.
  final bool isMultiline;

  /// The text alignment within the scrollview.
  final TextAlign textAlign;

  /// The rest of the subtree for this text field.
  final Widget child;

  @override
  SuperTextFieldScrollviewState createState() => SuperTextFieldScrollviewState();
}

class SuperTextFieldScrollviewState extends State<SuperTextFieldScrollview> with SingleTickerProviderStateMixin {
  bool _scrollToStartOnTick = false;
  bool _scrollToEndOnTick = false;
  double _scrollAmountPerFrame = 0;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    widget.textController.addListener(_onSelectionOrContentChange);
  }

  @override
  void didUpdateWidget(SuperTextFieldScrollview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onSelectionOrContentChange);
      widget.textController.addListener(_onSelectionOrContentChange);
    }

    if (widget.viewportHeight != oldWidget.viewportHeight) {
      // After the current layout, ensure that the current text
      // selection is visible.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          _ensureSelectionExtentIsVisible();
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _ensureSelectionExtentIsVisible();
      }
    });
  }

  void _ensureSelectionExtentIsVisible() {
    if (!widget.isMultiline) {
      _ensureSelectionExtentIsVisibleInSingleLineTextField();
    } else {
      _ensureSelectionExtentIsVisibleInMultilineTextField();
    }
  }

  void _ensureSelectionExtentIsVisibleInSingleLineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final extentOffset = _textLayout.getOffsetAtPosition(selection.extent);

    const gutterExtent = 0; // _dragGutterExtent

    final myBox = context.findRenderObject() as RenderBox;
    final beyondLeftExtent = min(extentOffset.dx - widget.scrollController.offset - gutterExtent, 0).abs();
    final beyondRightExtent = max(
        extentOffset.dx - myBox.size.width - widget.scrollController.offset + gutterExtent + widget.padding.horizontal,
        0);

    if (beyondLeftExtent > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondLeftExtent)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondRightExtent > 0) {
      final newScrollPosition = (beyondRightExtent + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _ensureSelectionExtentIsVisibleInMultilineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final extentOffset = _textLayout.getOffsetAtPosition(selection.extent);

    const gutterExtent = 0; // _dragGutterExtent
    final extentLineIndex = (extentOffset.dy / widget.estimatedLineHeight).round();

    final firstCharY = _textLayout.getCharacterBox(const TextPosition(offset: 0))?.top ?? 0.0;
    final isAtFirstLine = extentOffset.dy == firstCharY;

    final myBox = context.findRenderObject() as RenderBox;
    final beyondTopExtent = min<double>(
            extentOffset.dy - //
                widget.scrollController.offset -
                gutterExtent -
                (isAtFirstLine ? _textLayout.getLineHeightAtPosition(selection.extent) / 2 : 0),
            0)
        .abs();

    final lastCharY =
        _textLayout.getCharacterBox(TextPosition(offset: widget.textController.text.text.length - 1))?.top ?? 0.0;
    final isAtLastLine = extentOffset.dy == lastCharY;

    final beyondBottomExtent = max<double>(
        ((extentLineIndex + 1) * widget.estimatedLineHeight) -
            myBox.size.height -
            widget.scrollController.offset +
            gutterExtent +
            (isAtLastLine ? _textLayout.getLineHeightAtPosition(selection.extent) / 2 : 0) +
            (widget.estimatedLineHeight / 2) + // manual adjustment to avoid line getting half cut off
            (widget.padding.vertical / 2),
        0);

    _log.finer('_ensureSelectionExtentIsVisible - Ensuring extent is visible.');
    _log.finer('_ensureSelectionExtentIsVisible    - interaction size: ${myBox.size}');
    _log.finer('_ensureSelectionExtentIsVisible    - scroll extent: ${widget.scrollController.offset}');
    _log.finer('_ensureSelectionExtentIsVisible    - extent rect: $extentOffset');
    _log.finer('_ensureSelectionExtentIsVisible    - beyond top: $beyondTopExtent');
    _log.finer('_ensureSelectionExtentIsVisible    - beyond bottom: $beyondBottomExtent');

    if (beyondTopExtent > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondTopExtent)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondBottomExtent > 0) {
      final newScrollPosition = (beyondBottomExtent + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void startScrollingToStart({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToStartOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToStartOnTick = true;
    _log.finer("Starting Ticker to auto-scroll up");
    _ticker.start();
  }

  void stopScrollingToStart() {
    if (!_scrollToStartOnTick) {
      return;
    }

    _scrollToStartOnTick = false;
    _scrollAmountPerFrame = 0;
    _log.finer("Stopping Ticker after auto-scroll up");
    _ticker.stop();
  }

  void scrollToStart() {
    if (widget.scrollController.offset <= 0) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset - _scrollAmountPerFrame);
  }

  void startScrollingToEnd({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToEndOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToEndOnTick = true;
    _log.finer("Starting Ticker to auto-scroll down");
    _ticker.start();
  }

  void stopScrollingToEnd() {
    if (!_scrollToEndOnTick) {
      return;
    }

    _scrollToEndOnTick = false;
    _scrollAmountPerFrame = 0;
    _log.finer("Stopping Ticker after auto-scroll down");
    _ticker.stop();
  }

  void scrollToEnd() {
    if (widget.scrollController.offset >= widget.scrollController.position.maxScrollExtent) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset + _scrollAmountPerFrame);
  }

  void _onTick(elapsedTime) {
    if (_scrollToStartOnTick) {
      scrollToStart();
    }
    if (_scrollToEndOnTick) {
      scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.viewportHeight,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: widget.isMultiline ? Axis.vertical : Axis.horizontal,
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

typedef RightClickListener = void Function(
    BuildContext textFieldContext, AttributedTextEditingController textController, Offset textFieldOffset);

enum _SelectionType {
  /// The selection bound is set on a per-character basis.
  ///
  /// This is standard text selection behavior.
  position,

  /// The selection bound expands to include any word that the
  /// cursor touches.
  word,

  /// The selection bound expands to include any paragraph that
  /// the cursor touches.
  paragraph,
}

enum TextFieldKeyboardHandlerResult {
  /// The handler recognized the key event and chose to
  /// take an action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **shouldn't** bubble up the tree.
  handled,

  /// The handler recognized the key event but chose to
  /// take no action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **should** bubble up the tree to
  /// (possibly) be handled by other keyboard/shortcut
  /// listeners.
  blocked,

  /// The handler has no relation to the key event and
  /// took no action.
  ///
  /// Other handlers should be given a chance to act on
  /// the key press.
  notHandled,
}

typedef TextFieldKeyboardHandler = TextFieldKeyboardHandlerResult Function({
  required AttributedTextEditingController controller,
  required ProseTextLayout textLayout,
  required RawKeyEvent keyEvent,
});

/// A [TextFieldKeyboardHandler] that reports [TextFieldKeyboardHandlerResult.blocked]
/// for any key combination that matches one of the given [keys].
TextFieldKeyboardHandler ignoreTextFieldKeyCombos(List<ShortcutActivator> keys) {
  return ({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    for (final key in keys) {
      if (key.accepts(keyEvent, RawKeyboard.instance)) {
        return TextFieldKeyboardHandlerResult.blocked;
      }
    }
    return TextFieldKeyboardHandlerResult.notHandled;
  };
}

/// The keyboard actions that a [SuperTextField] uses by default.
///
/// It's common for developers to want all of these actions, but also
/// want to add more actions that take priority. To achieve that,
/// add the new actions to the front of the list:
///
/// ```
/// SuperTextField(
///   keyboardActions: [
///     myNewAction1,
///     myNewAction2,
///     ...defaultTextfieldKeyboardActions,
///   ],
/// );
/// ```
const defaultTextFieldKeyboardHandlers = <TextFieldKeyboardHandler>[
  DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd,
  DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineStartWithHome,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineEndWithEnd,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressedOnMac,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed,
];

/// The keyboard actions that a [SuperTextField] uses by default when using [TextInputSource.ime].
///
/// Using the IME on desktop involves partial input from the IME and partial input from non-content keys,
/// like arrow keys.
///
/// This list has the same handlers as [defaultTextFieldKeyboardHandlers], except the handlers that
/// input text. Text input is handled using [TextEditingDelta]s from the IME.
///
/// It's common for developers to want all of these actions, but also
/// want to add more actions that take priority. To achieve that,
/// add the new actions to the front of the list:
///
/// ```
/// SuperTextField(
///   keyboardActions: [
///     myNewAction1,
///     myNewAction2,
///     ...defaultTextFieldImeKeyboardHandlers,
///   ],
/// );
/// ```
const defaultTextFieldImeKeyboardHandlers = <TextFieldKeyboardHandler>[
  DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd,
  DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineStartWithHome,
  DefaultSuperTextFieldKeyboardHandlers.moveToLineEndWithEnd,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressedOnMac,
  DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed,
  DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed,
];

class DefaultSuperTextFieldKeyboardHandlers {
  /// [copyTextWhenCmdCIsPressed] copies text to clipboard when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + C is pressed.
  static TextFieldKeyboardHandlerResult copyTextWhenCmdCIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    controller.copySelectedTextToClipboard();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [pasteTextWhenCmdVIsPressed] pastes text from clipboard to document when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + V is pressed.
  static TextFieldKeyboardHandlerResult pasteTextWhenCmdVIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!controller.selection.isCollapsed) {
      controller.deleteSelectedText();
    }

    controller.pasteClipboard();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [selectAllTextFieldWhenCmdAIsPressed] selects all text when primary shortcut key
  /// (CMD on Mac, CTL on Windows) + A is pressed.
  static TextFieldKeyboardHandlerResult selectAllTextFieldWhenCmdAIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyA) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    controller.selectAll();

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [moveCaretToStartOrEnd] moves caret to start (using CTL+A) or end of line (using CTL+E)
  /// on MacOS platforms. This is part of expected behavior on MacOS. Not applicable to Windows.
  static TextFieldKeyboardHandlerResult moveCaretToStartOrEnd({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    bool moveLeft = false;
    if (!keyEvent.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyA && keyEvent.logicalKey != LogicalKeyboardKey.keyE) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset == -1) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    keyEvent.logicalKey == LogicalKeyboardKey.keyA
        ? moveLeft = true
        : keyEvent.logicalKey == LogicalKeyboardKey.keyE
            ? moveLeft = false
            : null;

    controller.moveCaretHorizontally(
      textLayout: textLayout!,
      expandSelection: false,
      moveLeft: moveLeft,
      movementModifier: MovementModifier.line,
    );

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [moveUpDownLeftAndRightWithArrowKeys] moves caret according to the directional key which was pressed.
  /// If there is no caret selection. it does nothing.
  static TextFieldKeyboardHandlerResult moveUpDownLeftAndRightWithArrowKeys({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    const arrowKeys = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ];
    if (!arrowKeys.contains(keyEvent.logicalKey)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset == -1) {
      // The result is reported as "handled" because an arrow
      // key was pressed, but we return early because there is
      // nowhere to move without a selection.
      return TextFieldKeyboardHandlerResult.handled;
    }

    if (defaultTargetPlatform == TargetPlatform.windows && keyEvent.isAltPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (defaultTargetPlatform == TargetPlatform.linux &&
        keyEvent.isAltPressed &&
        (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling left arrow key');

      MovementModifier? movementModifier;
      if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
          keyEvent.isControlPressed) {
        movementModifier = MovementModifier.word;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isMetaPressed) {
        movementModifier = MovementModifier.line;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isAltPressed) {
        movementModifier = MovementModifier.word;
      }

      controller.moveCaretHorizontally(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveLeft: true,
        movementModifier: movementModifier,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling right arrow key');

      MovementModifier? movementModifier;
      if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
          keyEvent.isControlPressed) {
        movementModifier = MovementModifier.word;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isMetaPressed) {
        movementModifier = MovementModifier.line;
      } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isAltPressed) {
        movementModifier = MovementModifier.word;
      }

      controller.moveCaretHorizontally(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveLeft: false,
        movementModifier: movementModifier,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling up arrow key');
      controller.moveCaretVertically(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveUp: true,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      _log.finer('moveUpDownLeftAndRightWithArrowKeys - handling down arrow key');
      controller.moveCaretVertically(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveUp: false,
      );
    }

    return TextFieldKeyboardHandlerResult.handled;
  }

  static TextFieldKeyboardHandlerResult moveToLineStartWithHome({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.home) {
      controller.moveCaretHorizontally(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveLeft: true,
        movementModifier: MovementModifier.line,
      );
      return TextFieldKeyboardHandlerResult.handled;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  static TextFieldKeyboardHandlerResult moveToLineEndWithEnd({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.end) {
      controller.moveCaretHorizontally(
        textLayout: textLayout,
        expandSelection: keyEvent.isShiftPressed,
        moveLeft: false,
        movementModifier: MovementModifier.line,
      );
      return TextFieldKeyboardHandlerResult.handled;
    }

    return TextFieldKeyboardHandlerResult.notHandled;
  }

  /// [insertCharacterWhenKeyIsPressed] adds any character when that key is pressed.
  /// Certain keys are currently checked against a blacklist of characters for web
  /// since their behavior is unexpected. Check definition for more details.
  static TextFieldKeyboardHandlerResult insertCharacterWhenKeyIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (keyEvent.isMetaPressed || keyEvent.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.character == null || keyEvent.character == '') {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    // On web, keys like shift and alt are sending their full name
    // as a character, e.g., "Shift" and "Alt". This check prevents
    // those keys from inserting their name into content.
    //
    // This filter is a blacklist, and therefore it will fail to
    // catch any key that isn't explicitly listed. The eventual solution
    // to this is for the web to honor the standard key event contract,
    // but that's out of our control.
    if (isKeyEventCharacterBlacklisted(keyEvent.character)) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    controller.insertCharacter(keyEvent.character!);

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// Deletes text between the beginning of the line and the caret, when the user
  /// presses CMD + Backspace, or CTL + Backspace.
  static TextFieldKeyboardHandlerResult deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (!controller.selection.isCollapsed) {
      controller.deleteSelection();
      return TextFieldKeyboardHandlerResult.handled;
    }

    if (textLayout.getPositionAtStartOfLine(controller.selection.extent).offset == controller.selection.extentOffset) {
      // The caret is sitting at the beginning of a line. There's nothing for us to
      // delete upstream on this line. But we also don't want a regular BACKSPACE to
      // run, either. Report this key combination as handled.
      return TextFieldKeyboardHandlerResult.handled;
    }

    controller.deleteTextOnLineBeforeCaret(textLayout: textLayout);

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteTextWhenBackspaceOrDeleteIsPressed] deletes single characters when delete or backspace is pressed.
  static TextFieldKeyboardHandlerResult deleteTextWhenBackspaceOrDeleteIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    final isBackspace = keyEvent.logicalKey == LogicalKeyboardKey.backspace;
    final isDelete = keyEvent.logicalKey == LogicalKeyboardKey.delete;
    if (!isBackspace && !isDelete) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (controller.selection.isCollapsed) {
      controller.deleteCharacter(isBackspace ? TextAffinity.upstream : TextAffinity.downstream);
    } else {
      controller.deleteSelectedText();
    }

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteWordWhenAltBackSpaceIsPressedOnMac] deletes single words when Alt+Backspace is pressed on Mac.
  static TextFieldKeyboardHandlerResult deleteWordWhenAltBackSpaceIsPressedOnMac({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.backspace || !keyEvent.isAltPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    _deleteUpstreamWord(controller, textLayout);

    return TextFieldKeyboardHandlerResult.handled;
  }

  /// [deleteWordWhenAltBackSpaceIsPressedOnMac] deletes single words when Ctl+Backspace is pressed on Windows/Linux.
  static TextFieldKeyboardHandlerResult deleteWordWhenCtlBackSpaceIsPressedOnWindowsAndLinux({
    required AttributedTextEditingController controller,
    required ProseTextLayout textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.backspace || !keyEvent.isControlPressed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (controller.selection.extentOffset < 0) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    _deleteUpstreamWord(controller, textLayout);

    return TextFieldKeyboardHandlerResult.handled;
  }

  static void _deleteUpstreamWord(AttributedTextEditingController controller, ProseTextLayout textLayout) {
    if (!controller.selection.isCollapsed) {
      controller.deleteSelectedText();
      return;
    }

    controller.moveCaretHorizontally(
      textLayout: textLayout,
      expandSelection: true,
      moveLeft: true,
      movementModifier: MovementModifier.word,
    );
    controller.deleteSelectedText();
  }

  /// [insertNewlineWhenEnterIsPressed] inserts a new line character when the enter key is pressed.
  static TextFieldKeyboardHandlerResult insertNewlineWhenEnterIsPressed({
    required AttributedTextEditingController controller,
    ProseTextLayout? textLayout,
    required RawKeyEvent keyEvent,
  }) {
    if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }
    if (!controller.selection.isCollapsed) {
      return TextFieldKeyboardHandlerResult.notHandled;
    }

    controller.insertNewline();

    return TextFieldKeyboardHandlerResult.handled;
  }

  DefaultSuperTextFieldKeyboardHandlers._();
}

/// Computes the estimated line height of a [TextStyle].
class _EstimatedLineHeight {
  /// Last computed line height.
  double? _lastLineHeight;

  /// TextStyle used to compute [_lastLineHeight].
  TextStyle? _lastComputedStyle;

  /// Text scale factor used to compute [_lastLineHeight].
  double? _lastTextScaleFactor;

  /// Computes the estimated line height for the given [style].
  ///
  /// The height is computed by laying out a [Paragraph] with an arbitrary
  /// character and inspecting it's height.
  ///
  /// The result is cached for the last [style] and [textScaleFactor] used, so it's not computed
  /// at each call.
  double calculate(TextStyle style, double textScaleFactor) {
    if (_lastComputedStyle == style &&
        _lastLineHeight != null &&
        _lastTextScaleFactor == textScaleFactor &&
        _lastTextScaleFactor != null) {
      return _lastLineHeight!;
    }

    final builder = ui.ParagraphBuilder(style.getParagraphStyle())
      ..pushStyle(style.getTextStyle(textScaleFactor: textScaleFactor))
      ..addText('A');

    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));

    _lastLineHeight = paragraph.height;
    _lastComputedStyle = style;
    _lastTextScaleFactor = textScaleFactor;
    return _lastLineHeight!;
  }
}
