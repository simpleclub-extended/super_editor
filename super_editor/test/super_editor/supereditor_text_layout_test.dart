import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout_inspector.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnAllPlatforms('respects the OS text scaling preference', (tester) async {
      // Pump an editor with a custom textScaleFactor.
      await tester
          .createDocument()
          .withSingleParagraph()
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(textScaleFactor: 1.5),
                  child: superEditor,
                ),
              ),
            ),
          )
          .pump();

      // Ensure the configure textScaleFactor was applied.
      expect(SuperTextInspector.findTextScaleFactor(), 1.5);
    });
  });
}
