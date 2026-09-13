import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

TestTableNode tableOf(Document document) => document.getNodeById('table') as TestTableNode;

void expectCaretAt(MutableDocumentComposer composer, Document document, String nodeId, int offset) {
  expect(document.getNodeById(nodeId), isNotNull);
  expect(composer.selection!.isCollapsed, isTrue);
  expect(composer.selection!.extent.nodeId, nodeId);
  expect((composer.selection!.extent.nodePosition as TextNodePosition).offset, offset);
}

CommonEditorOperations _opsFor(MutableDocument document, MutableDocumentComposer composer) {
  final layout = FakeDocumentLayout();
  return CommonEditorOperations(
    editor: createDefaultDocumentEditor(document: document, composer: composer),
    document: document,
    composer: composer,
    documentLayoutResolver: () => layout,
  );
}

void main() {
  group('SuperEditor > composite > content deletion >', () {
    test('re-creates one paragraph with the removed id when a cross-cell deletion empties a cell', () {
      final document = paragraphThenCellsThenParagraphDoc(cellCount: 3);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 2)),
          extent: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 2)),
        ),
      );

      _opsFor(document, composer).deleteSelection(TextAffinity.downstream);

      final table = tableOf(document);
      expect(table.children.length, 3);

      final cell2 = table.getChildByNodeId('cell2') as TestCellNode;
      expect(cell2.children.length, 1);
      expect(cell2.children.first.id, 'p2');
      expect((cell2.children.first as TextNode).text.toPlainText(), '');

      expect((document.getNodeById('p1') as TextNode).text.toPlainText(), 'Ce');
      expect((document.getNodeById('p3') as TextNode).text.toPlainText(), 'll 3 text');

      expectCaretAt(composer, document, 'p1', 2);
    });

    test('empties the selected cells and keeps the composite when partially selected', () {
      final document = paragraphThenCellsThenParagraphDoc(cellCount: 3);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 11)),
        ),
      );

      _opsFor(document, composer).deleteSelection(TextAffinity.downstream);

      final table = tableOf(document);
      expect(table.children.length, 3);
      expect(((table.getChildByNodeId('cell1') as TestCellNode).children.first as TextNode).text.toPlainText(), '');
      expect(((table.getChildByNodeId('cell2') as TestCellNode).children.first as TextNode).text.toPlainText(), '');
      expect(
        ((table.getChildByNodeId('cell3') as TestCellNode).children.first as TextNode).text.toPlainText(),
        'Cell 3 text',
      );
      expectCaretAt(composer, document, 'p1', 0);
    });

    test('deletes the composite when fully selected', () {
      final document = paragraphThenCellsThenParagraphDoc(cellCount: 2);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection(
          base: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 15)),
          extent: DocumentPosition(nodeId: '3', nodePosition: TextNodePosition(offset: 0)),
        ),
      );

      _opsFor(document, composer).deleteSelection(TextAffinity.downstream);

      expect(document.getNodeById('table'), isNull);
      expect(document.nodeCount, 1);
      expect((document.first as TextNode).text.toPlainText(), 'First paragraphLast paragraph');
      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 15)),
        ),
      );
    });

    test('keeps a non-deletable leaf when the range crosses it', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('First paragraph')),
          TestTableNode(
            id: 'table',
            children: [
              TestCellNode(
                id: 'cell1',
                children: [ParagraphNode(id: 'p1', text: AttributedText('Cell 1 text'))],
              ),
              TestCellNode(
                id: 'cell2',
                children: [
                  ParagraphNode(
                    id: 'p2',
                    text: AttributedText('Cell 2 text'),
                    metadata: const {NodeMetadata.isDeletable: false},
                  ),
                ],
              ),
              TestCellNode(
                id: 'cell3',
                children: [ParagraphNode(id: 'p3', text: AttributedText('Cell 3 text'))],
              ),
            ],
          ),
          ParagraphNode(id: '3', text: AttributedText('Last paragraph')),
        ],
      );
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 2)),
          extent: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 2)),
        ),
      );

      _opsFor(document, composer).deleteSelection(TextAffinity.downstream);

      final table = tableOf(document);
      expect(table.children.length, 3);
      final cell2 = table.getChildByNodeId('cell2') as TestCellNode;
      expect(cell2.children.first.id, 'p2');
      expect((cell2.children.first as TextNode).text.toPlainText(), 'Cell 2 text');
      expectCaretAt(composer, document, 'p1', 2);
    });
  });
}
