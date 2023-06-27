import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/test_documents.dart';
import '../../test_tools.dart';
import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';

void main() {
  group(
    'Document keyboard actions',
    () {
      group('jumps to', () {
        testWidgetsOnMac('beginning of line with CMD + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere after the beginning of the first
          // line in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCmdLeftArrow();

          // Ensure that the caret moved to the beginning of the line.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
          );
        });

        testWidgetsOnMac('end of line with CMD + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere before the end of the first line
          // in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCmdRightArrow();

          // Ensure that the caret moved to the end of the line. This value
          // is very fragile. If the text size or layout width changes, this value
          // will also need to change.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 27),
              ),
            ),
          );
        });

        testWidgetsOnMac('beginning of word with ALT + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        });

        testWidgetsOnMac('end of word with ALT + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        });

        testWidgetsOnLinux('preceding character with ALT + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret moved one character to the left.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 7),
              ),
            ),
          );
        });

        testWidgetsOnLinux('next character with ALT + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret moved one character to the right
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 9),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('beginning of line with HOME in an auto-wrapping paragraph', (tester) async {
          await _pumpAutoWrappingTestSetup(tester);

          // Place caret at the second line at "adipiscing |elit"
          // We avoid placing the caret in the first line to make sure HOME doesn't move caret
          // all the way to the beginning of the text
          await tester.placeCaretInParagraph('1', 51);

          await tester.pressHome();

          // Ensure that the caret moved to the beginning of the wrapped line at "|adipiscing elit"
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 40),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('beginning of line with HOME in a paragraph with explicit new lines',
            (tester) async {
          await _pumpExplicitLineBreakTestSetup(tester);

          // Place caret at the second line at "consectetur adipiscing |elit"
          // We avoid placing the caret in the first line to make sure HOME doesn't move caret
          // all the way to the beginning of the text
          await tester.placeCaretInParagraph('1', 51);

          await tester.pressHome();

          // Ensure that the caret moved to the beginning of the second line at "|consectetur adipiscing elit"
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 27),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('end of line with END in an auto-wrapping paragraph', (tester) async {
          await _pumpAutoWrappingTestSetup(tester);

          // Place caret at the start of the first line
          // We avoid placing the caret in the last line to make sure END doesn't move caret
          // all the way to the end of the text
          await tester.placeCaretInParagraph('1', 0);

          await tester.pressEnd();

          // Ensure that the caret moved to the end of the line. This value
          // is very fragile. If the text size or layout width changes, this value
          // will also need to change.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('end of line with END in a paragraph with explicit new lines', (tester) async {
          // Configure the screen to a size big enough so there's no auto line-wrapping
          await _pumpExplicitLineBreakTestSetup(tester, size: const Size(1024, 400));

          // Place caret at the first line at "Lorem |ipsum"
          // Avoid placing caret in the last line to make sure END doesn't move caret
          // all the way to the end of the text
          await tester.placeCaretInParagraph('1', 6);

          await tester.pressEnd();

          // Ensure that the caret moved the end of the first line
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 26, affinity: TextAffinity.upstream),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('beginning of word with CTRL + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCtlLeftArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('end of word with CTRL + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCtlRightArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );
        });
      });

      group("does nothing", () {
        testWidgetsOnWindows("with ALT + LEFT ARROW", (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );
        });

        testWidgetsOnWindows("with ALT + RIGHT ARROW", (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('with ALT + UP ARROW', (tester) async {
          await _pumpExplicitLineBreakTestSetup(tester);

          // Place caret at the second line at "consectetur adipiscing |elit"
          await tester.placeCaretInParagraph('1', 51);

          await tester.pressAltUpArrow();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 51),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('with ALT + DOWN ARROW', (tester) async {
          await _pumpExplicitLineBreakTestSetup(tester);

          // Place caret at the first line at "Lorem |ipsum"
          await tester.placeCaretInParagraph('1', 6);

          await tester.pressAltDownArrow();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );
        });
      });

      group("shortcuts for Windows and Linux do nothing on mac", () {
        testWidgetsOnMac('HOME', (tester) async {
          // Start the user's selection somewhere after the beginning of the first
          // line in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressHome();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          );
        });

        testWidgetsOnMac('END', (tester) async {
          // Start the user's selection somewhere after the beginning of the first
          // line in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

          await tester.pressEnd();

          // Ensure that the caret didn't move
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 2),
              ),
            ),
          );
        });

        testWidgetsOnMac('CTRL + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCtlLeftArrow();

          // Ensure that the caret moved only one character to the left
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 7),
              ),
            ),
          );
        });

        testWidgetsOnMac('CTRL + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere in the middle of a word.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCtlRightArrow();

          // Ensure that the caret moved only one character to the right
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 9),
              ),
            ),
          );
        });
      });

      group("shortcuts for Mac do nothing on Windows and Linux", () {
        testWidgetsOnWindowsAndLinux('CMD + LEFT ARROW', (tester) async {
          // Start the user's selection somewhere after the beginning of the first
          // line in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCmdLeftArrow();

          // Ensure that the caret didn't move to the beginning of the line.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 7),
              ),
            ),
          );
        });

        testWidgetsOnWindowsAndLinux('CMD + RIGHT ARROW', (tester) async {
          // Start the user's selection somewhere before the end of the first line
          // in the first node.
          await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 2);

          await tester.pressCmdRightArrow();

          // Ensure that the caret didn't move to the end of the line.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 3),
              ),
            ),
          );
        });
      });

      group(
        'CMD + A to select all',
        () {
          testOnMac(
            'it does nothing when meta key is pressed but A-key is not pressed',
            () {
              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyC,
                    physicalKey: PhysicalKeyboardKey.keyC,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'c',
                ),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);
            },
          );

          testOnMac(
            'it does nothing when A-key is pressed but meta key is not pressed',
            () {
              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: false,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);
            },
          );

          testOnMac(
            'it does nothing when CMD+A is pressed but the document is empty',
            () {
              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                    data: FakeRawKeyEventData(
                      logicalKey: LogicalKeyboardKey.keyA,
                      physicalKey: PhysicalKeyboardKey.keyA,
                      isMetaPressed: true,
                      isModifierKeyPressed: false,
                    ),
                    character: 'a'),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);
            },
          );

          testOnMac(
            'it selects all when CMD+A is pressed with a single-node document',
            () {
              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: 'paragraph',
                      text: AttributedText(text: 'This is some text'),
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 'This is some text'.length),
                ),
              );
            },
          );
          testOnMac(
            'it selects all when CMD+A is pressed with a two-node document',
            () {
              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: 'paragraph_1',
                      text: AttributedText(text: 'This is some text'),
                    ),
                    ParagraphNode(
                      id: 'paragraph_2',
                      text: AttributedText(text: 'This is some text'),
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph_1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'paragraph_2',
                  nodePosition: TextNodePosition(offset: 'This is some text'.length),
                ),
              );
            },
          );
          testOnMac(
            'it selects all when CMD+A is pressed with a three-node document',
            () {
              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ImageNode(
                      id: 'image_1',
                      imageUrl: 'https://fake.com/image/url.png',
                    ),
                    ParagraphNode(
                      id: 'paragraph',
                      text: AttributedText(text: 'This is some text'),
                    ),
                    ImageNode(
                      id: 'image_2',
                      imageUrl: 'https://fake.com/image/url.png',
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyDownEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'image_1',
                  nodePosition: UpstreamDownstreamNodePosition.upstream(),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'image_2',
                  nodePosition: UpstreamDownstreamNodePosition.downstream(),
                ),
              );
            },
          );
        },
      );

      group('key pressed with selection', () {
        testOnMac('deletes selection if backspace is pressed', () {
          final document = MutableDocument(
            nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(text: 'Text with [DELETEME] selection'),
              ),
            ],
          );

          final editContext = createEditContext(
            document: document,
            documentComposer: MutableDocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyDownEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = editContext.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            ),
          );
        });

        testOnMac('deletes selection if delete is pressed', () {
          final document = MutableDocument(
            nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(text: 'Text with [DELETEME] selection'),
              ),
            ],
          );
          final editContext = createEditContext(
            document: document,
            documentComposer: MutableDocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyDownEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = editContext.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            ),
          );
        });

        testOnMac('deletes selection when character key is pressed', () {
          final document = MutableDocument(
            nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(text: 'Text with [DELETEME] selection'),
              ),
            ],
          );
          final editContext = createEditContext(
            document: document,
            documentComposer: MutableDocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyDownEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyA,
                physicalKey: PhysicalKeyboardKey.keyA,
              ),
              character: 'a',
            ),
          );

          // When we use a character key for deletion, we expect to continue
          // execution so that the character is also entered by another handler.
          expect(result, ExecutionInstruction.continueExecution);

          final paragraph = editContext.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            ),
          );
        });

        testOnMac('collapses selection if escape is pressed', () {
          final document = MutableDocument(
            nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(text: 'Text with [SELECTME] selection'),
              ),
            ],
          );
          final editContext = createEditContext(
            document: document,
            documentComposer: MutableDocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          final result = collapseSelectionWhenEscIsPressed(
            editContext: editContext,
            keyEvent: const FakeRawKeyDownEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.escape,
                physicalKey: PhysicalKeyboardKey.escape,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          // The text should remain the same
          final paragraph = editContext.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [SELECTME] selection');

          // The selection should be collapsed
          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );
        });
      });

      group('typing characters near a link', () {
        testWidgets('does not expand the link when inserting before the link', (tester) async {
          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(_singleParagraphWithLinkDoc())
              .pump();

          // Place the caret in the first paragraph at the start of the link.
          await tester.placeCaretInParagraph('1', 0);

          // Type some text by simulating hardware keyboard key presses.
          await tester.typeKeyboardText('Go to ');

          // Ensure that the link is unchanged
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown("Go to [https://google.com](https://google.com)"),
          );
        });

        testWidgets('does not expand the link when inserting after the link', (tester) async {
          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(_singleParagraphWithLinkDoc())
              .pump();

          // Place the caret in the first paragraph at the start of the link.
          await tester.placeCaretInParagraph('1', 18);

          // Type some text by simulating hardware keyboard key presses.
          await tester.typeKeyboardText(' to learn anything');

          // Ensure that the link is unchanged
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown("[https://google.com](https://google.com) to learn anything"),
          );
        });
      });

      testOnMac('does nothing when escape is pressed if the selection is collapsed', () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: '1',
              text: AttributedText(text: 'This is some text'),
            ),
          ],
        );
        final editContext = createEditContext(
          document: document,
          documentComposer: MutableDocumentComposer(
            initialSelection: const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          ),
        );

        final result = collapseSelectionWhenEscIsPressed(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.escape,
              physicalKey: PhysicalKeyboardKey.escape,
            ),
          ),
        );

        // The handler should pass on do nothing when there is no selection.
        expect(result, ExecutionInstruction.continueExecution);

        // The text should remain the same
        final paragraph = editContext.document.nodes.first as ParagraphNode;
        expect(paragraph.text.text, 'This is some text');

        // The selection should remain the same
        expect(
          editContext.composer.selection,
          equals(
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          ),
        );
      });
    },
  );
}

/// Pumps a [SuperEditor] with a single-paragraph document, with focus, and returns
/// the associated [SuperEditorContext] for further inspection and control.
///
/// This particular setup is intended for caret movement testing within a single
/// paragraph node.
Future<SuperEditorContext> _pumpCaretMovementTestSetup(
  WidgetTester tester, {
  required int textOffsetInFirstNode,
}) async {
  final document = singleParagraphDoc();
  final composer = MutableDocumentComposer(
    initialSelection: DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: "1",
        nodePosition: TextNodePosition(offset: textOffsetInFirstNode),
      ),
    ),
  );
  final editContext = createEditContext(
    document: document,
    documentComposer: composer,
  );

  final focusNode = FocusNode()..requestFocus();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          focusNode: focusNode,
          editor: editContext.editor,
          document: editContext.document,
          composer: composer,
        ),
      ),
    ),
  );

  return editContext;
}

Future<TestDocumentContext> _pumpAutoWrappingTestSetup(WidgetTester tester) async {
  return await tester.createDocument().withSingleParagraph().forDesktop().withEditorSize(const Size(400, 400)).pump();
}

Future<TestDocumentContext> _pumpExplicitLineBreakTestSetup(
  WidgetTester tester, {
  Size? size,
}) async {
  return await tester
      .createDocument()
      .withCustomContent(MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'Lorem ipsum dolor sit amet\nconsectetur adipiscing elit',
            ),
          ),
        ],
      ))
      .forDesktop()
      .withEditorSize(size)
      .pump();
}

MutableDocument _singleParagraphWithLinkDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(
          text: "https://google.com",
          spans: AttributedSpans(
            attributions: [
              SpanMarker(
                attribution: LinkAttribution(url: Uri.parse('https://google.com')),
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: LinkAttribution(url: Uri.parse('https://google.com')),
                offset: 17,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      )
    ],
  );
}
