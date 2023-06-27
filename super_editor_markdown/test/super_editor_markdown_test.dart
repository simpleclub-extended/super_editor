import 'package:super_editor/super_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

void main() {
  group('Markdown', () {
    group('serialization', () {
      test('headers', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'My Header'),
          ),
        ]);

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header1Attribution);
        expect(serializeDocumentToMarkdown(doc), '# My Header');

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header2Attribution);
        expect(serializeDocumentToMarkdown(doc), '## My Header');

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header3Attribution);
        expect(serializeDocumentToMarkdown(doc), '### My Header');

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header4Attribution);
        expect(serializeDocumentToMarkdown(doc), '#### My Header');

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header5Attribution);
        expect(serializeDocumentToMarkdown(doc), '##### My Header');

        (doc.nodes[0] as ParagraphNode).putMetadataValue('blockType', header6Attribution);
        expect(serializeDocumentToMarkdown(doc), '###### My Header');
      });

      test('header with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'My Header',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 3, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            metadata: {'blockType': header1Attribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '# My **Header**');
      });

      test('blockquote', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is a blockquote'),
            metadata: {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> This is a blockquote');
      });

      test('blockquote with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a blockquote',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 10, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 19, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            metadata: {'blockType': blockquoteAttribution},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '> This is a **blockquote**');
      });

      test('code', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is some code'),
            metadata: {'blockType': codeAttribution},
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
```
This is some code
```''',
        );
      });

      test('paragraph', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is a paragraph.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a paragraph.');
      });

      test('paragraph with one inline style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This **is a** paragraph.');
      });

      test('paragraph with overlapping bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: italicsAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: italicsAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This ***is a*** paragraph.');
      });

      test('paragraph with non-overlapping bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: italicsAttribution, offset: 8, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: italicsAttribution, offset: 19, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '**This is** *a paragraph.*');
      });

      test('paragraph with intersecting bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: italicsAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This ***is a** paragraph*.');
      });

      test('paragraph with overlapping code and bold', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: codeAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: codeAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This `**is a**` paragraph.');
      });

      test('paragraph with link', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 10,
                      markerType: SpanMarkerType.start),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 18,
                      markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a [paragraph](https://example.org).');
      });

      test('paragraph with link overlapping style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 10,
                      markerType: SpanMarkerType.start),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 18,
                      markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: boldAttribution, offset: 10, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a [**paragraph**](https://example.org).');
      });

      test('paragraph with link intersecting style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 0,
                      markerType: SpanMarkerType.start),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 18,
                      markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: boldAttribution, offset: 5, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '[This **is a** paragraph](https://example.org).');
      });

      test('paragraph with underline', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: underlineAttribution, offset: 10, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: underlineAttribution, offset: 18, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a ¬paragraph¬.');
      });

      test('paragraph with strikethrough', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: strikethroughAttribution, offset: 10, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: strikethroughAttribution, offset: 18, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), 'This is a ~paragraph~.');
      });

      test('paragraph with consecutive links', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'First LinkSecond Link',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 0,
                      markerType: SpanMarkerType.start),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('example.org', '')),
                      offset: 9,
                      markerType: SpanMarkerType.end),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('github.com', '')),
                      offset: 10,
                      markerType: SpanMarkerType.start),
                  SpanMarker(
                      attribution: LinkAttribution(url: Uri.https('github.com', '')),
                      offset: 20,
                      markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '[First Link](https://example.org)[Second Link](https://github.com)');
      });

      test('paragraph with left alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'Paragraph1'),
            metadata: {
              'textAlign': 'left',
            },
          ),
        ]);

        // Even when using superEditor markdown syntax, which has support
        // for text alignment, we don't add an alignment token when
        // the paragraph is left-aligned.
        // Paragraphs are left-aligned by default, so it isn't necessary
        // to serialize the alignment token.
        expect(serializeDocumentToMarkdown(doc), 'Paragraph1');
      });

      test('paragraph with center alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'Paragraph1'),
            metadata: {
              'textAlign': 'center',
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), ':---:\nParagraph1');
      });

      test('paragraph with right alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'Paragraph1'),
            metadata: {
              'textAlign': 'right',
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '---:\nParagraph1');
      });

      test('paragraph with justify alignment', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'Paragraph1'),
            metadata: {
              'textAlign': 'justify',
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '-::-\nParagraph1');
      });

      test("doesn't serialize text alignment when not using supereditor syntax", () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'Paragraph1'),
            metadata: {
              'textAlign': 'center',
            },
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc, syntax: MarkdownSyntax.normal), 'Paragraph1');
      });

      test('empty paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'Paragraph1')),
            ParagraphNode(id: '2', text: AttributedText(text: '')),
            ParagraphNode(id: '3', text: AttributedText(text: 'Paragraph3')),
          ]),
        );

        expect(serialized, """Paragraph1



Paragraph3""");
      });

      test('separates multiple paragraphs with blank lines', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'Paragraph1')),
            ParagraphNode(id: '2', text: AttributedText(text: 'Paragraph2')),
            ParagraphNode(id: '3', text: AttributedText(text: 'Paragraph3')),
          ]),
        );

        expect(serialized, """Paragraph1

Paragraph2

Paragraph3""");
      });

      test('separates paragraph from other blocks with blank lines', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'First Paragraph')),
            HorizontalRuleNode(id: '2'),
          ]),
        );

        expect(serialized, 'First Paragraph\n\n---');
      });

      test('preserves linebreaks at the end of a paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'Paragraph1\n\n')),
            ParagraphNode(id: '2', text: AttributedText(text: 'Paragraph2')),
          ]),
        );

        expect(serialized, 'Paragraph1  \n  \n\n\nParagraph2');
      });

      test('preserves linebreaks within a paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'Line1\n\nLine2')),
          ]),
        );

        expect(serialized, 'Line1  \n  \nLine2');
      });

      test('preserves linebreaks at the beginning of a paragraph', () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: '\n\nParagraph1')),
            ParagraphNode(id: '2', text: AttributedText(text: 'Paragraph2')),
          ]),
        );

        expect(serialized, '  \n  \nParagraph1\n\nParagraph2');
      });

      test('image', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '![some alt text](https://someimage.com/the/image.png)');
      });

      test('horizontal rule', () {
        final doc = MutableDocument(nodes: [
          HorizontalRuleNode(
            id: '1',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '---');
      });

      test('unordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText(text: 'Unordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText(text: 'Unordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 3'),
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
  * Unordered 1
  * Unordered 2
    * Unordered 2.1
    * Unordered 2.2
  * Unordered 3''',
        );
      });

      test('unordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: AttributedText(
              text: 'Unordered 1',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '  * **Unordered** 1');
      });

      test('ordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText(text: 'Ordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText(text: 'Ordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 3'),
          ),
        ]);

        expect(
          serializeDocumentToMarkdown(doc),
          '''
  1. Ordered 1
  1. Ordered 2
    1. Ordered 2.1
    1. Ordered 2.2
  1. Ordered 3''',
        );
      });

      test('ordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: AttributedText(
              text: 'Ordered 1',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc), '  1. **Ordered** 1');
      });

      test('example doc', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: Editor.createNodeId(),
            imageUrl: 'https://someimage.com/the/image.png',
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'Example Doc'),
            metadata: {'blockType': header1Attribution},
          ),
          HorizontalRuleNode(id: Editor.createNodeId()),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'Unordered list:'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 1'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 2'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'Ordered list:'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 1'),
          ),
          ListItemNode(
            id: Editor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 2'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'A blockquote:'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'This is a blockquote.'),
            metadata: {'blockType': blockquoteAttribution},
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: 'Some code:'),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(text: '{\n  // This is some code.\n}'),
            metadata: {'blockType': codeAttribution},
          ),
        ]);

        // Ensure that the document serializes. We don't bother with
        // validating the output because other tests should validate
        // the per-node serializations.

        // ignore: unused_local_variable
        final markdown = serializeDocumentToMarkdown(doc);
      });

      test("doesn't add empty lines at the end of the document", () {
        final serialized = serializeDocumentToMarkdown(
          MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(text: 'Paragraph1')),
          ]),
        );

        expect(serialized, 'Paragraph1');
      });
    });

    group('deserialization', () {
      test('headers', () {
        final header1Doc = deserializeMarkdownToDocument('# Header 1');
        expect((header1Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header1Attribution);

        final header2Doc = deserializeMarkdownToDocument('## Header 2');
        expect((header2Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header2Attribution);

        final header3Doc = deserializeMarkdownToDocument('### Header 3');
        expect((header3Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header3Attribution);

        final header4Doc = deserializeMarkdownToDocument('#### Header 4');
        expect((header4Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header4Attribution);

        final header5Doc = deserializeMarkdownToDocument('##### Header 5');
        expect((header5Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header5Attribution);

        final header6Doc = deserializeMarkdownToDocument('###### Header 6');
        expect((header6Doc.nodes.first as ParagraphNode).getMetadataValue('blockType'), header6Attribution);
      });

      test('blockquote', () {
        final blockquoteDoc = deserializeMarkdownToDocument('> This is a blockquote');

        final blockquote = blockquoteDoc.nodes.first as ParagraphNode;
        expect(blockquote.getMetadataValue('blockType'), blockquoteAttribution);
        expect(blockquote.text.text, 'This is a blockquote');
      });

      test('code block', () {
        final codeBlockDoc = deserializeMarkdownToDocument('''
```
This is some code
```''');

        final code = codeBlockDoc.nodes.first as ParagraphNode;
        expect(code.getMetadataValue('blockType'), codeAttribution);
        expect(code.text.text, 'This is some code\n');
      });

      test('image', () {
        final codeBlockDoc = deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png)');

        final image = codeBlockDoc.nodes.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
      });

      test('single unstyled paragraph', () {
        const markdown = 'This is some unstyled text to parse as markdown';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        expect(paragraph.text.text, 'This is some unstyled text to parse as markdown');
      });

      test('single styled paragraph', () {
        const markdown = 'This is **some *styled*** text to parse as [markdown](https://example.org)';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This is some styled text to parse as markdown');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(styledText.getAllAttributionsAt(13).containsAll([boldAttribution, italicsAttribution]), true);
        expect(styledText.getAllAttributionsAt(19).isEmpty, true);
        expect(styledText.getAllAttributionsAt(40).single, LinkAttribution(url: Uri.https('example.org', '')));
      });

      test('link within multiple styles', () {
        const markdown = 'This is **some *styled [link](https://example.org) text***';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This is some styled link text');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(styledText.getAllAttributionsAt(13).containsAll([boldAttribution, italicsAttribution]), true);
        expect(
            styledText
                .getAllAttributionsAt(20)
                .containsAll([boldAttribution, italicsAttribution, LinkAttribution(url: Uri.https('example.org', ''))]),
            true);
        expect(styledText.getAllAttributionsAt(25).containsAll([boldAttribution, italicsAttribution]), true);
      });

      test('completely overlapping link and style', () {
        const markdown = 'This is **[a test](https://example.org)**';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This is a test');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains(boldAttribution), true);
        expect(
            styledText
                .getAllAttributionsAt(13)
                .containsAll([boldAttribution, LinkAttribution(url: Uri.https('example.org', ''))]),
            true);
      });

      test('single style intersecting link', () {
        // This isn't necessarily the behavior that you would expect, but it has been tested against multiple Markdown
        // renderers (such as VS Code) and it matches their behaviour.
        const markdown = 'This **is [a** link](https://example.org) test';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This **is a** link test');

        expect(styledText.getAllAttributionsAt(9).isEmpty, true);
        expect(styledText.getAllAttributionsAt(12).single, LinkAttribution(url: Uri.https('example.org', '')));
      });

      test('empty link', () {
        // This isn't necessarily the behavior that you would expect, but it has been tested against multiple Markdown
        // renderers (such as VS Code) and it matches their behaviour.
        const markdown = 'This is [a link]() test';
        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This is a link test');

        expect(styledText.getAllAttributionsAt(12).single, LinkAttribution(url: Uri.parse('')));
      });

      test('unordered list', () {
        const markdown = '''
 * list item 1
 * list item 2
   * list item 2.1
   * list item 2.2
 * list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 5);
        for (final node in document.nodes) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.unordered);
        }

        expect((document.nodes[0] as ListItemNode).indent, 0);
        expect((document.nodes[1] as ListItemNode).indent, 0);
        expect((document.nodes[2] as ListItemNode).indent, 1);
        expect((document.nodes[3] as ListItemNode).indent, 1);
        expect((document.nodes[4] as ListItemNode).indent, 0);
      });

      test('ordered list', () {
        const markdown = '''
 1. list item 1
 1. list item 2
    1. list item 2.1
    1. list item 2.2
 1. list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 5);
        for (final node in document.nodes) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.ordered);
        }

        expect((document.nodes[0] as ListItemNode).indent, 0);
        expect((document.nodes[1] as ListItemNode).indent, 0);
        expect((document.nodes[2] as ListItemNode).indent, 1);
        expect((document.nodes[3] as ListItemNode).indent, 1);
        expect((document.nodes[4] as ListItemNode).indent, 0);
      });

      test('example doc 1', () {
        final document = deserializeMarkdownToDocument(exampleMarkdownDoc1);

        expect(document.nodes.length, 18);

        expect(document.nodes[0], isA<ParagraphNode>());
        expect((document.nodes[0] as ParagraphNode).getMetadataValue('blockType'), header1Attribution);

        expect(document.nodes[1], isA<HorizontalRuleNode>());

        expect(document.nodes[2], isA<ParagraphNode>());

        expect(document.nodes[3], isA<ParagraphNode>());

        for (int i = 4; i < 9; ++i) {
          expect(document.nodes[i], isA<ListItemNode>());
        }

        expect(document.nodes[9], isA<HorizontalRuleNode>());

        for (int i = 10; i < 15; ++i) {
          expect(document.nodes[i], isA<ListItemNode>());
        }

        expect(document.nodes[15], isA<HorizontalRuleNode>());

        expect(document.nodes[16], isA<ImageNode>());

        expect(document.nodes[17], isA<ParagraphNode>());
      });

      test('paragraph with strikethrough', () {
        final doc = deserializeMarkdownToDocument('~This is~ a paragraph.');
        final styledText = (doc.nodes[0] as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(strikethroughAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(strikethroughAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(strikethroughAttribution), false);
      });

      test('paragraph with underline', () {
        final doc = deserializeMarkdownToDocument('¬This is¬ a paragraph.');
        final styledText = (doc.nodes[0] as ParagraphNode).text;

        // Ensure text within the range is attributed.
        expect(styledText.getAllAttributionsAt(0).contains(underlineAttribution), true);
        expect(styledText.getAllAttributionsAt(6).contains(underlineAttribution), true);

        // Ensure text outside the range isn't attributed.
        expect(styledText.getAllAttributionsAt(7).contains(underlineAttribution), false);
      });

      test('paragraph with left alignment', () {
        final doc = deserializeMarkdownToDocument(':---\nParagraph1');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), 'left');
        expect(paragraph.text.text, 'Paragraph1');
      });

      test('paragraph with center alignment', () {
        final doc = deserializeMarkdownToDocument(':---:\nParagraph1');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), 'center');
        expect(paragraph.text.text, 'Paragraph1');
      });

      test('paragraph with right alignment', () {
        final doc = deserializeMarkdownToDocument('---:\nParagraph1');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), 'right');
        expect(paragraph.text.text, 'Paragraph1');
      });

      test('paragraph with justify alignment', () {
        final doc = deserializeMarkdownToDocument('-::-\nParagraph1');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), 'justify');
        expect(paragraph.text.text, 'Paragraph1');
      });

      test('treats alignment token as text at the end of the document', () {
        final doc = deserializeMarkdownToDocument('---:');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), isNull);
        expect(paragraph.text.text, '---:');
      });

      test('treats alignment token as text when not followed by a paragraph', () {
        final doc = deserializeMarkdownToDocument('---:\n - - -');

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), isNull);
        expect(paragraph.text.text, '---:');

        // Ensure the horizontal rule is parsed.
        expect(doc.nodes[1], isA<HorizontalRuleNode>());
      });

      test('treats alignment token as text when not using supereditor syntax', () {
        final doc = deserializeMarkdownToDocument(':---\nParagraph1', syntax: MarkdownSyntax.normal);

        final paragraph = doc.nodes.first as ParagraphNode;
        expect(paragraph.getMetadataValue('textAlign'), isNull);
        expect(paragraph.text.text, ':---\nParagraph1');
      });

      test('multiple paragraphs', () {
        final input = """Paragraph1

Paragraph2""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodes.length, 2);
        expect((doc.nodes[0] as ParagraphNode).text.text, 'Paragraph1');
        expect((doc.nodes[1] as ParagraphNode).text.text, 'Paragraph2');
      });

      test('empty paragraph between paragraphs', () {
        final input = """Paragraph1



Paragraph3""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodes.length, 3);
        expect((doc.nodes[0] as ParagraphNode).text.text, 'Paragraph1');
        expect((doc.nodes[1] as ParagraphNode).text.text, '');
        expect((doc.nodes[2] as ParagraphNode).text.text, 'Paragraph3');
      });

      test('multiple empty paragraph between paragraphs', () {
        final input = """Paragraph1





Paragraph4""";
        final doc = deserializeMarkdownToDocument(input);

        expect(doc.nodes.length, 4);
        expect((doc.nodes[0] as ParagraphNode).text.text, 'Paragraph1');
        expect((doc.nodes[1] as ParagraphNode).text.text, '');
        expect((doc.nodes[2] as ParagraphNode).text.text, '');
        expect((doc.nodes[3] as ParagraphNode).text.text, 'Paragraph4');
      });

      test('paragraph ending with one blank line', () {
        final doc = deserializeMarkdownToDocument('First Paragraph.  \n\n\nSecond Paragraph');
        expect(doc.nodes.length, 2);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, 'First Paragraph.\n');

        expect(doc.nodes.last, isA<ParagraphNode>());
        expect((doc.nodes.last as ParagraphNode).text.text, 'Second Paragraph');
      });

      test('paragraph ending with multiple blank lines', () {
        final doc = deserializeMarkdownToDocument('First Paragraph.  \n  \n  \n\n\nSecond Paragraph');

        expect(doc.nodes.length, 2);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, 'First Paragraph.\n\n\n');

        expect(doc.nodes.last, isA<ParagraphNode>());
        expect((doc.nodes.last as ParagraphNode).text.text, 'Second Paragraph');
      });

      test('paragraph with multiple blank lines at the middle', () {
        final doc =
            deserializeMarkdownToDocument('First Paragraph.  \n  \n  \nStill First Paragraph\n\nSecond Paragraph');

        expect(doc.nodes.length, 2);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, 'First Paragraph.\n\n\nStill First Paragraph');

        expect(doc.nodes.last, isA<ParagraphNode>());
        expect((doc.nodes.last as ParagraphNode).text.text, 'Second Paragraph');
      });

      test('paragraph beginning with multiple blank lines', () {
        final doc = deserializeMarkdownToDocument('  \n  \nFirst Paragraph.\n\nSecond Paragraph');

        expect(doc.nodes.length, 2);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, '\n\nFirst Paragraph.');

        expect(doc.nodes.last, isA<ParagraphNode>());
        expect((doc.nodes.last as ParagraphNode).text.text, 'Second Paragraph');
      });

      test('document ending with an empty paragraph', () {
        final doc = deserializeMarkdownToDocument("""
First Paragraph.


""");

        expect(doc.nodes.length, 2);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, 'First Paragraph.');

        expect(doc.nodes.last, isA<ParagraphNode>());
        expect((doc.nodes.last as ParagraphNode).text.text, '');
      });

      test('empty markdown produces an empty paragraph', () {
        final doc = deserializeMarkdownToDocument('');

        expect(doc.nodes.length, 1);

        expect(doc.nodes.first, isA<ParagraphNode>());
        expect((doc.nodes.first as ParagraphNode).text.text, '');
      });
    });
  });
}

const exampleMarkdownDoc1 = '''
# Example 1
---
This is an example doc that has various types of nodes, like [links](https://example.org).

It includes multiple paragraphs, ordered list items, unordered list items, images, and HRs.

 * unordered item 1
 * unordered item 2
   * unordered item 2.1
   * unordered item 2.2
 * unordered item 3

---

 1. ordered item 1
 2. ordered item 2
   1. ordered item 2.1
   2. ordered item 2.2
 3. ordered item 3

---

![Image alt text](https://images.com/some/image.png)

The end!
''';
