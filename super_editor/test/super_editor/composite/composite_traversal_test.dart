import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

void main() {
  group('SuperEditor > composite > traversal >', () {
    Future<Document> pumpTable(WidgetTester tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 3))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .forDesktop()
          .pump();
      return context.document;
    }

    String? Function(String, DocumentNodeLookupDirection, {double? nearX}) nextOf(Document document) {
      final layout = SuperEditorInspector.findDocumentLayout();
      return (String nodeId, DocumentNodeLookupDirection direction, {double? nearX}) => document
          .getNextSelectableNode(
            startingNode: document.getNodeById(nodeId)!,
            documentLayoutResolver: () => layout,
            direction: direction,
            nearX: nearX,
          )
          ?.id;
    }

    testWidgetsOnDesktop('descends into a composite and never skips a leaf going right', (tester) async {
      final document = await pumpTable(tester);
      final next = nextOf(document);

      expect(next('1', DocumentNodeLookupDirection.right), 'p1');
      expect(next('p1', DocumentNodeLookupDirection.right), 'p2');
      expect(next('p2', DocumentNodeLookupDirection.right), 'p3');
      expect(next('p3', DocumentNodeLookupDirection.right), '3');
      expect(next('3', DocumentNodeLookupDirection.right), isNull);
    });

    testWidgetsOnDesktop('walks the same leaves going left', (tester) async {
      final document = await pumpTable(tester);
      final next = nextOf(document);

      expect(next('3', DocumentNodeLookupDirection.left), 'p3');
      expect(next('p3', DocumentNodeLookupDirection.left), 'p2');
      expect(next('p2', DocumentNodeLookupDirection.left), 'p1');
      expect(next('p1', DocumentNodeLookupDirection.left), '1');
      expect(next('1', DocumentNodeLookupDirection.left), isNull);
    });

    testWidgetsOnDesktop('lists leaves in document order', (tester) async {
      final document = await pumpTable(tester);

      expect([for (final (_, node) in document.getLeafNodes()) node.id], ['1', 'p1', 'p2', 'p3', '3']);
    });

    testWidgetsOnDesktop('moves down and up through a composite with nearX', (tester) async {
      final document = await pumpTable(tester);
      final next = nextOf(document);

      expect(next('1', DocumentNodeLookupDirection.down, nearX: 0), 'p1');
      expect(next('3', DocumentNodeLookupDirection.up, nearX: 0), 'p3');
    });
  });
}
