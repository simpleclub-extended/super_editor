import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

void expectCollapsedAt(DocumentSelection? selection, String nodeId, int offset) {
  expect(selection, isNotNull);
  expect(selection!.isCollapsed, isTrue);
  expect(selection.extent.nodeId, nodeId);
  expect((selection.extent.nodePosition as TextNodePosition).offset, offset);
}

void main() {
  group('SuperEditor > composite > deletion >', () {
    for (final isIsolating in [true, false]) {
      group('isIsolating $isIsolating >', () {
        testWidgetsOnDesktop('BACKSPACE at the start of a cell', (tester) async {
          final context = await tester
              .createDocument()
              .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2, isIsolating: isIsolating))
              .withAddedComponents([TestCompositeComponentBuilder()])
              .forDesktop(inputSource: TextInputSource.keyboard)
              .pump();

          await tester.placeCaretInParagraph('p2', 0);
          await tester.pressBackspace();

          if (isIsolating) {
            expect(context.document, documentEquivalentTo(paragraphThenCellsThenParagraphDoc(cellCount: 2)));
            expectCollapsedAt(context.composer.selection, 'p2', 0);
            return;
          }

          expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), 'Cell 1 textCell 2 text');
          final cell2 =
              (context.document.getNodeById('table') as TestTableNode).getChildByNodeId('cell2') as TestCellNode;
          expect(cell2.children.length, 1);
          expect(cell2.children.first.id, 'p2');
          expect((cell2.children.first as TextNode).text.toPlainText(), '');
          expectCollapsedAt(context.composer.selection, 'p1', 11);
        });

        testWidgetsOnDesktop('DELETE at the end of a cell', (tester) async {
          final context = await tester
              .createDocument()
              .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2, isIsolating: isIsolating))
              .withAddedComponents([TestCompositeComponentBuilder()])
              .forDesktop(inputSource: TextInputSource.keyboard)
              .pump();

          await tester.placeCaretInParagraph('p1', 11);
          await tester.pressDelete();

          if (isIsolating) {
            expect(context.document, documentEquivalentTo(paragraphThenCellsThenParagraphDoc(cellCount: 2)));
            expectCollapsedAt(context.composer.selection, 'p1', 11);
            return;
          }

          expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), 'Cell 1 textCell 2 text');
          final cell2 =
              (context.document.getNodeById('table') as TestTableNode).getChildByNodeId('cell2') as TestCellNode;
          expect(cell2.children.length, 1);
          expect(cell2.children.first.id, 'p2');
          expect((cell2.children.first as TextNode).text.toPlainText(), '');
          expectCollapsedAt(context.composer.selection, 'p1', 11);
        });

        testWidgetsOnDesktop('BACKSPACE at the start of the first cell', (tester) async {
          final context = await tester
              .createDocument()
              .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2, isIsolating: isIsolating))
              .withAddedComponents([TestCompositeComponentBuilder()])
              .forDesktop(inputSource: TextInputSource.keyboard)
              .pump();

          await tester.placeCaretInParagraph('p1', 0);
          await tester.pressBackspace();

          if (isIsolating) {
            expect(context.document, documentEquivalentTo(paragraphThenCellsThenParagraphDoc(cellCount: 2)));
            expectCollapsedAt(context.composer.selection, 'p1', 0);
            return;
          }

          expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'First paragraphCell 1 text');
          final cell1 =
              (context.document.getNodeById('table') as TestTableNode).getChildByNodeId('cell1') as TestCellNode;
          expect(cell1.children.length, 1);
          expect(cell1.children.first.id, 'p1');
          expect((cell1.children.first as TextNode).text.toPlainText(), '');
          expect(context.document.nodeCount, 3);
          expect(context.document.getNodeById(context.composer.selection!.extent.nodeId), isNotNull);
        });
      });
    }
  });
}
