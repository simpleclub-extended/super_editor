import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_runners.dart';
import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

void main() {
  group('SuperEditor > composite > typing >', () {
    testAllInputsOnDesktop('types into a leaf inside a composite', (tester, {required inputSource}) async {
      await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .forDesktop(inputSource: inputSource)
          .pump();

      await tester.placeCaretInParagraph('p1', 11);
      if (inputSource == TextInputSource.ime) {
        await tester.typeImeText('Zn');
      } else {
        await tester.typeKeyboardText('Zn');
      }

      expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), 'Cell 1 textZn');
      expect(SuperEditorInspector.findTextInComponent('p2').toPlainText(), 'Cell 2 text');
      expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'First paragraph');
      expect(SuperEditorInspector.findTextInComponent('3').toPlainText(), 'Last paragraph');
    });

    testAllInputsOnDesktop('splits the leaf inside its cell on ENTER', (tester, {required inputSource}) async {
      final context = await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .forDesktop(inputSource: inputSource)
          .pump();

      await tester.placeCaretInParagraph('p1', 6);
      await tester.pressEnter();

      final cell1 = (context.document.getNodeById('table') as TestTableNode).getChildByNodeId('cell1') as TestCellNode;
      expect(cell1.children.length, 2);
      expect((cell1.children.first as TextNode).text.toPlainText(), 'Cell 1');
      expect((cell1.children.last as TextNode).text.toPlainText(), ' text');
      expect(context.document.nodeCount, 3);

      final newNodeId = cell1.children.last.id;
      expect(['1', 'table', 'cell1', 'cell2', 'p1', 'p2', '3'].contains(newNodeId), isFalse);
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: newNodeId, nodePosition: const TextNodePosition(offset: 0)),
        ),
      );
    });
  });
}
