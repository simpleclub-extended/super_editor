import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';
import 'composite_test_tools.dart';

Future<TestDocumentContext> _pump(WidgetTester tester, {required bool isIsolating, DocumentSelection? selection}) {
  return tester
      .createDocument()
      .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 2, isIsolating: isIsolating))
      .withAddedComponents([TestCompositeComponentBuilder()])
      .withSelection(selection)
      .autoFocus(selection != null)
      .forDesktop(inputSource: TextInputSource.keyboard)
      .pump();
}

void expectExtentAt(DocumentSelection? selection, String nodeId, int offset) {
  expect(selection, isNotNull);
  expect(selection!.extent.nodeId, nodeId);
  expect((selection.extent.nodePosition as TextNodePosition).offset, offset);
}

void main() {
  group('SuperEditor > composite > selection >', () {
    testWidgetsOnDesktop('extends into a composite with SHIFT + RIGHT_ARROW when cells are not isolating',
        (tester) async {
      final context = await _pump(tester, isIsolating: false);

      await tester.placeCaretInParagraph('1', 15);
      await tester.pressShiftRightArrow();

      expectExtentAt(context.composer.selection, 'p1', 0);
      expect(context.composer.selection!.base.nodeId, '1');
    });

    testWidgetsOnDesktop('extends across cells with SHIFT + RIGHT_ARROW when cells are not isolating', (tester) async {
      final context = await _pump(tester, isIsolating: false);

      await tester.placeCaretInParagraph('p1', 11);
      await tester.pressShiftRightArrow();

      expectExtentAt(context.composer.selection, 'p2', 0);
    });

    testWidgetsOnDesktop('extends out of a composite with SHIFT + RIGHT_ARROW when cells are not isolating',
        (tester) async {
      final context = await _pump(tester, isIsolating: false);

      await tester.placeCaretInParagraph('p2', 11);
      await tester.pressShiftRightArrow();

      expectExtentAt(context.composer.selection, '3', 0);
    });

    testWidgetsOnDesktop('refuses to extend across an isolating boundary with SHIFT + RIGHT_ARROW', (tester) async {
      final context = await _pump(tester, isIsolating: true);

      await tester.placeCaretInParagraph('1', 15);
      await tester.pressShiftRightArrow();
      expectExtentAt(context.composer.selection, '1', 15);

      await tester.placeCaretInParagraph('p1', 11);
      await tester.pressShiftRightArrow();
      expectExtentAt(context.composer.selection, 'p1', 11);
    });

    testWidgetsOnDesktop('extends back out with SHIFT + LEFT_ARROW when cells are not isolating', (tester) async {
      final context = await _pump(
        tester,
        isIsolating: false,
        selection: const DocumentSelection(
          base: DocumentPosition(nodeId: '3', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 11)),
        ),
      );

      for (var i = 0; i < 12; i += 1) {
        await tester.pressShiftLeftArrow();
      }

      expectExtentAt(context.composer.selection, 'p1', 11);
      expect(context.composer.selection!.base.nodeId, '3');
    });

    testWidgetsOnMac('expands the selection into a composite child created in the same frame', (tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(paragraphThenCellsThenParagraphDoc(cellCount: 1))
          .withAddedComponents([_LayoutTimeCompositeComponentBuilder()])
          .forDesktop(inputSource: TextInputSource.keyboard)
          .pump();
      await tester.placeCaretInParagraph('p1', 0);

      final table = context.document.getNodeById('table') as TestTableNode;
      context.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: 'table',
          newNode: table.copyWithChildren([
            ...table.children,
            TestCellNode(id: 'cell3', children: [ParagraphNode(id: 'p3', text: AttributedText('Cell 3 text'))]),
          ]),
        ),
        const ChangeSelectionRequest(
          DocumentSelection(
            base: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 0)),
            extent: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 4)),
          ),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expectExtentAt(context.composer.selection, 'p3', 4);
    });

    testWidgetsOnMac('selects all with CMD + A when composites are the first and last nodes', (tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(MutableDocument(nodes: [
            TestTableNode(id: 'table1', children: [
              TestCellNode(id: 'cell1', children: [ParagraphNode(id: 'p1', text: AttributedText('First'))]),
            ]),
            TestTableNode(id: 'table2', children: [
              TestCellNode(id: 'cell2', children: [ParagraphNode(id: 'p2', text: AttributedText('Last'))]),
            ]),
          ]))
          .withAddedComponents([TestCompositeComponentBuilder()])
          .autoFocus(true)
          .forDesktop(inputSource: TextInputSource.keyboard)
          .pump();

      await tester.placeCaretInParagraph('p1', 0);
      await tester.pressCmdA();

      final selection = context.composer.selection!;
      expect(selection.base, const DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)));
      expect(selection.extent, const DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 4)));
      expect(tester.takeException(), isNull);
    });
  });
}

class _LayoutTimeCompositeComponentBuilder extends TestCompositeComponentBuilder {
  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    final component = super.createComponent(componentContext, componentViewModel);
    return component == null ? null : LayoutBuilder(builder: (_, __) => component);
  }
}
