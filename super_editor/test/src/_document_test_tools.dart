import 'package:mockito/mockito.dart';
import 'package:super_editor/super_editor.dart';

/// Fake [DocumentLayout], intended for tests that interact with
/// a logical [DocumentLayout] but do not depend upon a real
/// widget tree with a real [DocumentLayout] implementation.
class FakeDocumentLayout with Mock implements DocumentLayout {}

SuperEditorContext createEditContext({
  required MutableDocument document,
  Editor? documentEditor,
  DocumentLayout? documentLayout,
  MutableDocumentComposer? documentComposer,
  CommonEditorOperations? commonOps,
}) {
  final composer = documentComposer ?? MutableDocumentComposer();
  final editor = documentEditor ?? createDefaultDocumentEditor(document: document, composer: composer);
  DocumentLayout layoutResolver() => documentLayout ?? FakeDocumentLayout();

  return SuperEditorContext(
    editor: editor,
    document: document,
    getDocumentLayout: layoutResolver,
    composer: composer,
    commonOps: commonOps ??
        CommonEditorOperations(
          editor: editor,
          document: document,
          composer: composer,
          documentLayoutResolver: layoutResolver,
        ),
  );
}

MutableDocument createExampleDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Example Document',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      HorizontalRuleNode(id: Editor.createNodeId()),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            text:
                'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
        ),
      ),
    ],
  );
}
