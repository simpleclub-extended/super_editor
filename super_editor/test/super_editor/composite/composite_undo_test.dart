import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

Future<TestDocumentContext> _pump(WidgetTester tester, {required int cellCount}) {
  return tester
      .createDocument()
      .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: cellCount))
      .withAddedComponents([TestCompositeComponentBuilder()])
      .enableHistory(true)
      .forDesktop(inputSource: TextInputSource.keyboard)
      .pump();
}

String leafText(TestDocumentContext context, String nodeId) =>
    (context.document.getNodeById(nodeId) as TextNode).text.toPlainText();

List<String> cellChildIds(TestDocumentContext context, String cellId) {
  final table = context.document.getNodeById('table') as TestTableNode;
  return [for (final child in (table.getChildByNodeId(cellId) as TestCellNode).children) child.id];
}

void main() {
  group('SuperEditor > composite > undo >', () {
    testWidgetsOnMac('restores a leaf edit inside a composite on CMD + Z', (tester) async {
      final context = await _pump(tester, cellCount: 2);

      await tester.placeCaretInParagraph('p1', 11);
      await tester.typeKeyboardText('Zn');
      expect(leafText(context, 'p1'), 'Cell 1 textZn');

      await tester.pressCmdZ(tester);
      await tester.pressCmdZ(tester);

      expect(leafText(context, 'p1'), 'Cell 1 text');
      expect(context.document, documentEquivalentTo(paragraphThenCellsThenParagraphDoc(cellCount: 2)));
    });

    testWidgetsOnMac('restores a cell emptied by a cross-cell deletion on CMD + Z', (tester) async {
      final context = await _pump(tester, cellCount: 3);

      await tester.placeCaretInParagraph('p1', 2);
      const spanningSelection = DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 2)),
        extent: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 2)),
      );
      context.editor.execute([
        const ChangeSelectionRequest(
            spanningSelection, SelectionChangeType.expandSelection, SelectionReason.userInteraction),
      ]);
      await tester.pump();

      await tester.pressDelete();

      final table = context.document.getNodeById('table') as TestTableNode;
      expect(table.children.length, 3);
      expect(cellChildIds(context, 'cell2'), ['p2']);
      expect(leafText(context, 'p2'), '');

      await tester.pressCmdZ(tester);

      expect(context.document, documentEquivalentTo(paragraphThenCellsThenParagraphDoc(cellCount: 3)));
      expect(context.composer.selection, spanningSelection);
    });

    testWidgetsOnMac('replays a request-created id identically on CMD + Z then CMD + SHIFT + Z', (tester) async {
      final context = await _pump(tester, cellCount: 2);
      await tester.placeCaretInParagraph('p1', 0);

      context.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: 'p1',
          newNode: ParagraphNode(id: 'p1-new', text: AttributedText('replaced')),
        ),
      ]);
      await tester.pump();
      expect(cellChildIds(context, 'cell1'), ['p1-new']);
      expect(leafText(context, 'p1-new'), 'replaced');

      await tester.pressCmdZ(tester);
      expect(cellChildIds(context, 'cell1'), ['p1']);
      expect(leafText(context, 'p1'), 'Cell 1 text');

      await tester.pressCmdShiftZ(tester);
      expect(cellChildIds(context, 'cell1'), ['p1-new']);
      expect(leafText(context, 'p1-new'), 'replaced');
    });
  });
}
