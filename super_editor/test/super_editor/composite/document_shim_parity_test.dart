// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'composite_test_tools.dart';

void main() {
  group('SuperEditor > composite > document shims >', () {
    test('agree with their replacements on a flat document', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('one')),
          ParagraphNode(id: '2', text: AttributedText('two')),
          ParagraphNode(id: '3', text: AttributedText('three')),
        ],
      );

      for (final (index, nodeId) in ['1', '2', '3'].indexed) {
        final node = document.getNodeById(nodeId)!;
        expect(document.getNodeIndex(node), document.getNodeIndexInParent(node));
        expect(document.getNodeIndex(node), index);
        expect(document.getNodeIndexById(nodeId), document.getNodeIndexInParentById(nodeId));
        expect(document.getNodeIndexById(nodeId), index);
      }
    });

    test('agree with their replacements on a nested leaf', () {
      final document = paragraphThenCellsThenParagraphDoc(cellCount: 2);

      expect(document.getNodeIndexById('p2'), document.getNodeIndexInParentById('p2'));
      expect(document.getNodeIndexById('p2'), 0);
      expect(document.getNodeIndexById('table'), 1);
      expect(document.getNodeIndexById('cell2'), document.getNodeIndexInParentById('cell2'));
      expect(document.getNodeIndexById('cell2'), 1);
    });
  });
}
