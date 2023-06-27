import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/raw_key_event_extensions.dart';

import 'layout_single_column/layout_single_column.dart';
import 'text_tools.dart';

class ParagraphNode extends TextNode {
  ParagraphNode({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
  }) : super(
          id: id,
          text: text,
          metadata: metadata,
        ) {
    if (getMetadataValue("blockType") == null) {
      putMetadataValue("blockType", paragraphAttribution);
    }
  }
}

class ParagraphComponentBuilder implements ComponentBuilder {
  const ParagraphComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.text);

    TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
    final textAlignName = node.getMetadataValue('textAlign');
    switch (textAlignName) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    return ParagraphComponentViewModel(
      nodeId: node.id,
      blockType: node.getMetadataValue('blockType'),
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  TextComponent? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    editorLayoutLog.fine("Building paragraph component for node: ${componentViewModel.nodeId}");

    if (componentViewModel.selection != null) {
      editorLayoutLog.finer(' - painting a text selection:');
      editorLayoutLog.finer('   base: ${componentViewModel.selection!.base}');
      editorLayoutLog.finer('   extent: ${componentViewModel.selection!.extent}');
    } else {
      editorLayoutLog.finer(' - not painting any text selection');
    }

    return TextComponent(
      key: componentContext.componentKey,
      text: componentViewModel.text,
      textStyleBuilder: componentViewModel.textStyleBuilder,
      metadata: componentViewModel.blockType != null
          ? {
              'blockType': componentViewModel.blockType,
            }
          : {},
      textAlign: componentViewModel.textAlignment,
      textDirection: componentViewModel.textDirection,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
    );
  }
}

class ParagraphComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  ParagraphComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    this.blockType,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  Attribution? blockType;
  AttributedText text;
  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  @override
  ParagraphComponentViewModel copy() {
    return ParagraphComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      blockType: blockType,
      text: text,
      textStyleBuilder: textStyleBuilder,
      textDirection: textDirection,
      textAlignment: textAlignment,
      selection: selection,
      selectionColor: selectionColor,
      highlightWhenEmpty: highlightWhenEmpty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ParagraphComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          blockType == other.blockType &&
          text == other.text &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          highlightWhenEmpty == other.highlightWhenEmpty;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      blockType.hashCode ^
      text.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      highlightWhenEmpty.hashCode;
}

class ChangeParagraphBlockTypeRequest implements EditRequest {
  ChangeParagraphBlockTypeRequest({
    required this.nodeId,
    required this.blockType,
  });

  final String nodeId;
  final Attribution? blockType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeParagraphBlockTypeRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          blockType == other.blockType;

  @override
  int get hashCode => nodeId.hashCode ^ blockType.hashCode;
}

class ChangeParagraphBlockTypeCommand implements EditCommand {
  const ChangeParagraphBlockTypeCommand({
    required this.nodeId,
    required this.blockType,
  });

  final String nodeId;
  final Attribution? blockType;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);

    final existingNode = document.getNodeById(nodeId)! as ParagraphNode;
    existingNode.putMetadataValue('blockType', blockType);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(nodeId),
      ),
    ]);
  }
}

/// [EditRequest] to combine the [ParagraphNode] with [firstNodeId] with the [ParagraphNode] after it, which
/// should have the [secondNodeId].
class CombineParagraphsRequest implements EditRequest {
  CombineParagraphsRequest({
    required this.firstNodeId,
    required this.secondNodeId,
  }) : assert(firstNodeId != secondNodeId);

  final String firstNodeId;
  final String secondNodeId;
}

/// Combines two consecutive `ParagraphNode`s, indicated by `firstNodeId`
/// and `secondNodeId`, respectively.
///
/// If the specified nodes are not sequential, or are sequential
/// in reverse order, the command fizzles.
///
/// If both nodes are not `ParagraphNode`s, the command fizzles.
class CombineParagraphsCommand implements EditCommand {
  CombineParagraphsCommand({
    required this.firstNodeId,
    required this.secondNodeId,
  }) : assert(firstNodeId != secondNodeId);

  final String firstNodeId;
  final String secondNodeId;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing CombineParagraphsCommand');
    editorDocLog.info(' - merging "$firstNodeId" <- "$secondNodeId"');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final secondNode = document.getNodeById(secondNodeId);
    if (secondNode is! TextNode) {
      editorDocLog.info('WARNING: Cannot merge node of type: $secondNode into node above.');
      return;
    }

    final nodeAbove = document.getNodeBefore(secondNode);
    if (nodeAbove == null) {
      editorDocLog.info('At top of document. Cannot merge with node above.');
      return;
    }
    if (nodeAbove.id != firstNodeId) {
      editorDocLog.info('The specified `firstNodeId` is not the node before `secondNodeId`.');
      return;
    }
    if (nodeAbove is! TextNode) {
      editorDocLog.info('Cannot merge ParagraphNode into node of type: $nodeAbove');
      return;
    }

    // Combine the text and delete the currently selected node.
    final isTopNodeEmpty = nodeAbove.text.text.isEmpty;
    nodeAbove.text = nodeAbove.text.copyAndAppend(secondNode.text);

    // Avoid overriding the metadata when the nodeAbove isn't a ParagraphNode.
    //
    // If we are combining different kinds of nodes, e.g., a list item and a paragraph,
    // overriding the metadata will cause the nodeAbove to end up with an incorrect blockType.
    // This will cause incorrect styles to be applied.
    if (isTopNodeEmpty && nodeAbove is ParagraphNode) {
      // If the top node was empty, we want to retain everything in the
      // bottom node, including the block attribution and styles.
      nodeAbove.metadata = secondNode.metadata;
    }
    bool didRemove = document.deleteNode(secondNode);
    if (!didRemove) {
      editorDocLog.info('ERROR: Failed to delete the currently selected node from the document.');
    }

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(secondNode.id, secondNode),
      ),
      DocumentEdit(
        NodeChangeEvent(nodeAbove.id),
      ),
    ]);
  }
}

class SplitParagraphRequest implements EditRequest {
  SplitParagraphRequest({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
    required this.replicateExistingMetadata,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;
  final bool replicateExistingMetadata;
}

/// Splits the `ParagraphNode` affiliated with the given `nodeId` at the
/// given `splitPosition`, placing all text after `splitPosition` in a
/// new `ParagraphNode` with the given `newNodeId`, inserted after the
/// original node.
class SplitParagraphCommand implements EditCommand {
  SplitParagraphCommand({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
    required this.replicateExistingMetadata,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;
  final bool replicateExistingMetadata;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing SplitParagraphCommand');

    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      editorDocLog.info('WARNING: Cannot split paragraph for node of type: $node.');
      return;
    }

    final text = node.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = text.copyText(splitPosition.offset);
    editorDocLog.info('Splitting paragraph:');
    editorDocLog.info(' - start text: "${startText.text}"');
    editorDocLog.info(' - end text: "${endText.text}"');

    // Change the current nodes content to just the text before the caret.
    editorDocLog.info(' - changing the original paragraph text due to split');
    node.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node. And create a
    // new copy of the metadata if `replicateExistingMetadata` is true.
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
      metadata: replicateExistingMetadata ? node.copyMetadata() : {},
    );

    // Insert the new node after the current node.
    editorDocLog.info(' - inserting new node in document');
    document.insertNodeAfter(
      existingNode: node,
      newNode: newNode,
    );

    editorDocLog.info(' - inserted new node: ${newNode.id} after old one: ${node.id}');

    // Move the caret to the new node.
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final oldSelection = composer.selection;
    final oldComposingRegion = composer.composingRegion.value;
    final newSelection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newNodeId,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );

    composer.setSelectionWithReason(newSelection, SelectionReason.userInteraction);
    composer.setComposingRegion(null);

    final documentChanges = [
      DocumentEdit(
        NodeChangeEvent(node.id),
      ),
      DocumentEdit(
        NodeInsertedEvent(newNodeId, document.getNodeIndexById(newNodeId)),
      ),
      SelectionChangeEvent(
        oldSelection: oldSelection,
        newSelection: newSelection,
        oldComposingRegion: oldComposingRegion,
        newComposingRegion: null,
        changeType: SelectionChangeType.insertContent,
        reason: SelectionReason.userInteraction,
      ),
    ];

    if (newNode.text.text.isEmpty) {
      executor.logChanges([
        SubmitParagraphIntention.start(),
        ...documentChanges,
        SubmitParagraphIntention.end(),
      ]);
    } else {
      executor.logChanges([
        SplitParagraphIntention.start(),
        ...documentChanges,
        SplitParagraphIntention.end(),
      ]);
    }
  }
}

class Intention implements EditEvent {
  Intention.start() : _isStart = true;

  Intention.end() : _isStart = false;

  final bool _isStart;

  bool get isStart => _isStart;

  bool get isEnd => !_isStart;
}

class SplitParagraphIntention extends Intention {
  SplitParagraphIntention.start() : super.start();

  SplitParagraphIntention.end() : super.end();
}

class SubmitParagraphIntention extends Intention {
  SubmitParagraphIntention.start() : super.start();

  SubmitParagraphIntention.end() : super.end();
}

ExecutionInstruction anyCharacterToInsertInParagraph({
  required SuperEditorContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (keyEvent.isControlPressed || keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }

  var character = keyEvent.character;
  if (character == null || character == '') {
    return ExecutionInstruction.continueExecution;
  }

  if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!) || keyEvent.isArrowKeyPressed) {
    return ExecutionInstruction.continueExecution;
  }

  // On web, keys like shift and alt are sending their full name
  // as a character, e.g., "Shift" and "Alt". This check prevents
  // those keys from inserting their name into content.
  if (isKeyEventCharacterBlacklisted(character) && character != 'Tab') {
    return ExecutionInstruction.continueExecution;
  }

  // The web reports a tab as "Tab". Intercept it and translate it to a space.
  if (character == 'Tab') {
    character = ' ';
  }

  final didInsertCharacter = editContext.commonOps.insertCharacter(character);

  return didInsertCharacter ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

class DeleteParagraphCommand implements EditCommand {
  DeleteParagraphCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing DeleteParagraphCommand');
    editorDocLog.info(' - deleting "$nodeId"');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      editorDocLog.shout('WARNING: Cannot delete node of type: $node.');
      return;
    }

    bool didRemove = document.deleteNode(node);
    if (!didRemove) {
      editorDocLog.shout('ERROR: Failed to delete node "$node" from the document.');
    }

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(node.id, node),
      )
    ]);
  }
}

/// When the caret is collapsed at the beginning of a ParagraphNode
/// and backspace is pressed, clear any existing block type, e.g.,
/// header 1, header 2, blockquote.
ExecutionInstruction backspaceToClearParagraphBlockType({
  required SuperEditorContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = editContext.composer.selection!.extent.nodePosition;
  if (textPosition is! TextNodePosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final didClearBlockType = editContext.commonOps.convertToParagraph();
  return didClearBlockType ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction enterToInsertBlockNewline({
  required SuperEditorContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }

  final didInsertBlockNewline = editContext.commonOps.insertBlockLevelNewline();

  return didInsertBlockNewline ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction moveParagraphSelectionUpWhenBackspaceIsPressed({
  required SuperEditorContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (node.text.text.isEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = editContext.document.getNodeBefore(node);
  if (nodeAbove == null) {
    return ExecutionInstruction.continueExecution;
  }
  final newDocumentPosition = DocumentPosition(
    nodeId: nodeAbove.id,
    nodePosition: nodeAbove.endPosition,
  );

  editContext.editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: newDocumentPosition,
      ),
      SelectionChangeType.deleteContent,
      SelectionReason.userInteraction,
    ),
  ]);

  return ExecutionInstruction.haltExecution;
}
