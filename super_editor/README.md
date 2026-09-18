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

The `simpleclub-stable` branch carries a generic `CompositeNode` infrastructure that upstream does not
have: a document node that owns other nodes, so a table cell can hold real editable content. The
simpleclub app needs it for editable tables in user content. The table upstream ships allows no
selection inside a cell, so it does not fit.

This section is the only written record of that work. Read it before merging upstream, before
building on the infrastructure, and before deleting it.

It is live. The simpleclub Flutter app pins this repository by git ref and has its own table code on
top, so changes here reach a shipping product.

### Where to start if you are building on it

| Type | What it is for |
|---|---|
| `CompositeNode` | a document node that owns child nodes. Subclass this for a table, a cell, a callout |
| `CompositeComponent` | the widget-side contract for rendering one, and for finding a child's component |
| `CompositeAwareComponentBuilder` | implement this instead of `ComponentBuilder` when a builder has to build view models for children |
| `PresenterContext` | what such a builder uses to turn a child node into a child view model |
| `NodePath` | addresses a node through nesting, where a plain node index cannot |

`Document` gained `getNodeAtPath`, `getNodePathById`, `getLeafNodes`, `getNodesInsideById` and
`getNodeIndexInParentById` for traversal. Note that `getNodeIndexById` is deprecated in favour of
`getNodeIndexInParentById`, because a component's index must be its index inside its parent rather
than a global index in the document.

The public surface is the four export lines under the `// Composite nodes` comment in
`super_editor/lib/super_editor.dart`. Tests live under `super_editor/test/super_editor/composite/`
and are the best worked examples.

### Where the code came from

It is a port of an upstream pull request that never landed:

- [#2830](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/2830) by Aleksey Garbarev is the
  code we took. It is still open and conflicting, and last saw activity on 2025-11-28. The maintainer
  asked for a far larger rewrite in one PR, so it is not landing as it stands.
- [#2765](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/2765) by Matt Carroll is the
  earlier attempt that #2830 built on.
- [#2746](https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2746) is the issue both
  answer.

Tags that anchor the port:

| Tag | Points at |
|---|---|
| `composite-port/source-7c7743ed` | the upstream commit the port was taken from |
| `composite-port/merge-base` | the last `simpleclub-stable` commit before the port arrived |
| `composite-port/1`, `/2`, ... | each state of the port the simpleclub app adopted, numbered in order |

The port is preserved as its own commit, unmodified, so `git blame` keeps the boundary between
upstream authorship and ours visible. That commit is a mechanical three-way merge and does not
compile on its own. It is attribution, not a working checkpoint.

### What this fork changed on top of the port

**Adapted it to this fork's base.** The upstream PR is built on `v0.3.0-dev.42`. This fork sits on
upstream stable from March 2025, so twelve files needed hand work where the two bases disagree.

**Fixed two defects in the port.** Replacing a composite child with a new id mid-frame threw a
null-check error in the component key provider. It now mints a fresh `GlobalKey` for an id it has not
seen. Separately, a stale lookup for a child id the composite no longer holds dereferenced null, and
now logs and returns `null`.

**Restored the upstream `ComponentBuilder` signature.** The port had added a leading
`PresenterContext` parameter to `createViewModel` on every builder, which broke every implementation
inside and outside this repository. Composite builders now go through the
`CompositeAwareComponentBuilder` marker instead. This is also what keeps `super_editor_markdown`
compiling.

**Moved the port's additions out of pre-existing files.** Only edits to files that already exist
upstream conflict at the next sync. Code in new files is free. So the port's additions were pulled
into files this fork owns:

| | Files touched in upstream code | Lines |
|---|---|---|
| Port as it arrived | 44 | +2107 -578 |
| After the rework | 25 | +968 -557 |

Standalone libraries live in `super_editor/lib/src/composite/`. Code that needs library privacy became
a `part` file named `composite_*` beside its host.

Upstream code that predates the port was deliberately left where it was. Moving it would turn a clean
three-way merge into a rename-detection gamble. The resulting conflict arrives as "deleted by us,
modified by them", and that shape is closed most often by silently dropping the upstream side.

### Why the Flutter version is pinned

`.fvmrc` pins 3.44.0, matching the simpleclub Flutter monorepo. Without it `flutter test` picks up
whatever SDK is on PATH, and the package fails to compile on `TextInputStyle` in
`ime_decoration.dart`. That looks like broken code and is not.

CI does not read `.fvmrc`. It installs the unpinned `stable` channel, so a green CI run says nothing
about the SDK this code is actually used with. Local test runs under the pinned SDK are the real gate.

### Hook sites

Every pre-existing library file the port edits is a hook site that an upstream sync has to re-resolve
by hand. There are 22 of them under `super_editor/lib`. The list is derived rather than written down,
because a written list goes stale the first time someone adds a call.

Every command in this section and the next runs from the repository root, not from `super_editor/`.

```
git diff composite-port/merge-base...simpleclub-stable --stat --diff-filter=M -- super_editor/lib
```

This is the authoritative form. It also picks up any simpleclub work landed after the port, so treat
the count as an upper bound, but it never misses a file.

Do not try to find hook sites by grepping for composite symbols. It does not work, and it fails
silently. Six of the 22 carry no composite token at all: `common_editor_operations.dart` only imports
one, `default_document_editor.dart` passes a `parentNodeId`, `document_keyboard_actions.dart` calls
`CombineParagraphsCommand.canPerform`, and `read_only_document_mouse_interactor.dart` threads a
`Document` through a signature that changed. Relaxing the pattern does not rescue it: a
case-insensitive search for `composite` still misses four of them while matching 36 files.

One of the 22 is not composite work at all. `horizontal_rule.dart` arrived with the port carrying an
unrelated background colour feature. Keep it when the port goes.

### Pricing an upstream sync before doing it

The cost of carrying the port is the number of conflicted files it adds over what this fork would
conflict on anyway. Add the upstream remote once:

```
git remote add upstream https://github.com/Flutter-Bounty-Hunters/super_editor.git
git fetch upstream
```

Then merge upstream into the fork with and without the port, and subtract:

```
BASE=$(git merge-base upstream/stable composite-port/merge-base)
git merge-tree --write-tree --merge-base=$BASE upstream/stable composite-port/merge-base
git merge-tree --write-tree --merge-base=$BASE upstream/stable simpleclub-stable
```

Count the `CONFLICT` lines in each and take the difference. Re-price before every sync rather than
quoting an old figure.

Expect real textual conflicts wherever `NodePath` was woven through existing method bodies:
`common_editor_operations.dart`, `multi_node_editing.dart`, `selection_operations.dart` and
`layout_single_column/_layout.dart`. That cost was accepted knowingly. It cannot be removed without
moving pre-existing upstream code, which is the trade described above.

### Three contracts the port relies on and does not enforce

Breaking one of these does not produce a clear error. Read them before changing composite behaviour.

**1. A composite's child ids are stable unless the child count or a child's type changes.** Swapping a
child for a same-type node with a new id still renders, but that child loses its widget state,
because `ChildrenComponentKeyProvider` keys component state by node id.

**2. A cell is never empty.** "Isolating" here means a composite whose `isIsolating` getter returns
true, which stops a selection from extending past its boundary. The getter defaults to false, so a
cell type that wants isolation has to override it. Independently of that, a cell's
`resolveWhenChildrenAffected` must re-create one paragraph carrying the removed child's id when its
last child is deleted. If it returns an empty child list instead, the next cross-cell deletion removes
the cell itself from its parent.

**3. Every id a structural request creates lives in the request, never in `execute`.** That is what
makes undo and redo replay it identically. Two related facts make this sharper. The path cache never
forgets a deleted id, and the composer never validates its selection against the document. So an edit
that removes the cell holding the caret must also move the caret, in the same `execute` list, or the
selection is left pointing at a node that no longer exists.

### How to remove the port

Deletion is the expected end, not a failure mode. Upstream's own direction is
[#2433](https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2433) (document as a tree of
nodes) and [#2278](https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2278) (documents
within documents), both open since 2024. When upstream ships either, its API will not look like this
one, and carrying two solutions to the same problem is not worth it.

The layout exists to make that day cheap:

1. Delete what this fork owns outright. Nothing else imports it except the hook sites in step 2.

   ```
   git rm -r super_editor/lib/src/composite
   git rm -r super_editor/test/super_editor/composite
   git rm super_editor/lib/src/core/composite_document_paths.dart
   git rm super_editor/lib/src/default_editor/layout_single_column/composite_selection_styler.dart
   ```

   The two files outside `composite/` are `part` files. Removing the `part` directive from each host
   belongs to step 2.

2. Unpick the 22 hook sites. Each one is an added member, an added parameter, or a `part`, `import` or
   `export` line. The compiler finds every one of them, so work from `flutter analyze` rather than
   from a list. Keep the unrelated `horizontal_rule.dart` colour feature.

3. Delete the four export lines under `// Composite nodes` in `super_editor/lib/super_editor.dart`,
   and delete this section.

Anything still failing after that is not the port. It is the simpleclub app, which has its own table
code built on this infrastructure and needs its own migration.
