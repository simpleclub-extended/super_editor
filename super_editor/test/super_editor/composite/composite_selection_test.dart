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
  });
}
