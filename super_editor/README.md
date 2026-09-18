<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845431-e83699df-5c6c-4e9c-90fc-c12277cc2f48.png" width="300" alt="Super Editor"><br>
  <span><b>Open source, configurable, extensible text editor and document renderer for Flutter.</b></span><br><br>
</p>

<p align="center"><b>Super Editor works with any backend. Plug yours in and go!</b></p><br>

<img src="https://raw.githubusercontent.com/superlistapp/super_editor/main/super_editor/doc/marketing/readme-header.png" width="100%" alt="Super Editor">
<br> 

`super_editor` was initiated by [Superlist](https://superlist.com) and is being implemented and maintained by the [Flutter Bounty Hunters](https://flutterbountyhunters.com), Superlist, and the contributors.

## Supported Platforms

Super Editor aims to support all platforms. For now, Super Editor supports the following:

**Supported**

Super Editor is actively developed against these platforms.

 * Mac OS
 * Web
 * Android
 * iOS

**Unverified**

These platforms probably work, but our verification on these platforms is spotty.

 * Windows
 * Linux

## Run the example implementation

Super Editor comes with an example implementation to showcase the core functionality. It also exposes example UI elements on how to interact with the Editor.
The example app should build and run on any platform. You can run the example editor from the example directory:

```bash
cd example
flutter run -d macos
```

The example implementation is only a proof of concept. Expect separate packages to implement various UIs on top of the editor.


## Display an editor

Display a default text editor with the `SuperEditor` widget:

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        // Display a visual, editable document.
        //
        // SuperEditor includes default magnifiers and popover toolbars for
        // iOS and Android, but does not include any popovers on desktop.
        // You can add your own, if desired.
        //
        // The standard editor displays and styles headers, paragraphs,
        // ordered and unordered lists, images, and horizontal rules. 
        // Paragraphs know how to display bold, italics, and strikethrough.
        // Key combinations are provided for bold (cmd+b) and italics (cmd+i).
        return SuperEditor.standard(
            editor: _myDocumentEditor,
        );
    }
}
```

A `SuperEditor` widget requires an `Editor`, which is a pure-Dart class that's responsible for 
applying changes to a `Document`. An `Editor`, in turn, requires a reference to the `Document` that 
it will alter. Specifically, a `Editor` requires a `MutableDocument`.

```dart
// A MutableDocument is an in-memory Document. Create the starting
// content that you want your editor to display.
//
// Your MutableDocument does not need to contain any content/nodes.
// In that case, your editor will initially display nothing.
final myDoc = MutableDocument(
  nodes: [
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is a header'),
      metadata: {
        'blockType': header1Attribution,
      },
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text:'This is the first paragraph'),
    ),
  ],
);

// A DocumentComposer holds the user's selection. Your editor will likely want
// to observe, and possibly change the user's selection. Therefore, you should
// hold onto your own DocumentComposer and pass it to your Editor.
final myComposer = MutableDocumentComposer();

// With a MutableDocument, create an Editor, which knows how to apply changes 
// to the MutableDocument.
final editor = createDefaultDocumentEditor(document: myDoc, composer: myComposer);

// Next: pass the editor to your SuperEditor widget.
```

The `SuperEditor` widget can be customized.

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        return SuperEditor(
            editor: _myDocumentEditor,
            selectionStyle: /** INSERT CUSTOMIZATION **/ null,
            stylesheet: defaultStylesheet.copyWith(
                addRulesAfter: [
                    // Add any custom document styles, for example, you might
                    // apply styles to a custom Task node type.
                    StyleRule(
                        const BlockSelector("task"),
                        (document, node) {
                            if (node is! TaskNode) {
                                return {};
                            }

                            return {
                                Styles.padding: const CascadingPadding.only(top: 24),
                            };
                        },
                    )
                ],
            ),
            componentBuilders: [
              ...defaultComponentBuilders,
              // Add any of your own custom builders for document
              // components, e.g., paragraphs, images, list items.
            ],
        );
    }
}
```

If your app requires deeper customization than `SuperEditor` provides, you can construct your own 
version of the `SuperEditor` widget by using lower level tools within the `super_editor` package.

See the wiki for more information about how to customize an editor experience.

## Composite nodes (simpleclub fork)

The branch `feat/SC-22570-composite-tables` carries the generic `CompositeNode` infrastructure from
upstream PR #2830 by Aleksey Garbarev, which builds on Matt Carroll's PR #2765. It landed as a single
port commit and was adapted to this fork's older base in the commits after it. The exact upstream
state the port came from is reachable as the tag `composite-port/source-7c7743ed`, and every state of
this branch that the app adopts gets a `composite-port/<n>` tag.

### Hook sites

Every existing library file the port edits is a hook site that a future upstream sync has to
re-resolve by hand. The list is derived, never written down, because a written list goes stale the
first time someone adds a call. Either command produces it, run from `super_editor/`:

```
git diff simpleclub-stable...feat/SC-22570-composite-tables --stat -- super_editor/lib
grep -rlE 'CompositeNode|NodePath|PresenterContext' lib --include='*.dart'
```

The grep needs all three tokens. The port's inline edits insert three unrelated symbol families, and
five files carry only `PresenterContext`, so a two-token pattern silently misses them.

### Sync tax

The cost of carrying the port is the number of conflicted files this branch adds over the fork's own
base when upstream is merged. Price both halves with the same command and subtract:

```
git merge-tree --write-tree --merge-base=$(git merge-base upstream/stable simpleclub-stable) upstream/stable simpleclub-stable
git merge-tree --write-tree --merge-base=$(git merge-base upstream/stable simpleclub-stable) upstream/stable feat/SC-22570-composite-tables
```

Count the `CONFLICT` lines in each and take the difference. Re-price it before every sync rather than
quoting an old figure.

### Three contracts the port relies on and does not state in code

1. A composite's child ids are stable unless the child count or a child's type changes. A child
   swapped for a same-type node with a new id keeps working, but it loses that child's widget state,
   because `ChildrenComponentKeyProvider` keys component state by node id.
2. A cell is isolating and never empty. Its `resolveWhenChildrenAffected` re-creates one paragraph
   carrying the removed child's id. A cell that returns no children instead is removed from its
   parent by the next cross-cell deletion.
3. Every id a structural request creates lives in the request, never in `execute`, so undo and redo
   replay it identically. The path cache never forgets a deleted id and the composer never validates
   its selection against the document, so an edit that removes the cell holding the caret has to move
   the caret in the same `execute` list.

The tests that pin these live under `test/super_editor/composite/`.
