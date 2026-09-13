import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

void main() {
  group('SuperEditor > composite > layout >', () {
    testWidgetsOnDesktop('places the caret in a leaf inside a composite by node id', (tester) async {
      await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .forDesktop()
          .pump();

      await tester.placeCaretInParagraph('p1', 4);

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );
      expect(SuperEditorInspector.findTextInComponent('p2').toPlainText(), 'Cell 2 text');

      final layout = SuperEditorInspector.findDocumentLayout();
      for (final nodeId in ['1', 'table', 'cell1', 'p1', 'p2', '3']) {
        expect(layout.getComponentByNodeId(nodeId), isNotNull, reason: 'no component for "$nodeId"');
      }
    });

    testWidgetsOnDesktop('renders a replaced child with a new id without throwing', (tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 1))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .forDesktop()
          .pump();

      context.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: 'p1',
          newNode: ParagraphNode(id: 'p1-new', text: AttributedText('replaced')),
        ),
      ]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(SuperEditorInspector.findTextInComponent('p1-new').toPlainText(), 'replaced');
    });
  });
}
