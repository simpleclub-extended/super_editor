import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'example_document.dart';

class SuperReaderDemo extends StatefulWidget {
  const SuperReaderDemo({Key? key}) : super(key: key);

  @override
  State<SuperReaderDemo> createState() => _SuperReaderDemoState();
}

class _SuperReaderDemoState extends State<SuperReaderDemo> {
  late final Document _document;
  final _selection = ValueNotifier<DocumentSelection?>(null);
  final _selectionLayerLinks = SelectionLayerLinks();
  late MagnifierAndToolbarController _overlayController;
  late final SuperReaderIosControlsController _iosReaderControlsController;

  @override
  void initState() {
    super.initState();
    _document = createInitialDocument();
    _overlayController = MagnifierAndToolbarController();
    _iosReaderControlsController = SuperReaderIosControlsController(
      toolbarBuilder: _buildToolbar,
    );
  }

  @override
  void dispose() {
    _iosReaderControlsController.dispose();
    super.dispose();
  }

  void _copy() {
    if (_selection.value == null) {
      return;
    }

    final textToCopy = extractTextFromSelection(
      document: _document,
      documentSelection: _selection.value!,
    );
    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    _saveToClipboard(textToCopy);
  }

  Future<void> _saveToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  void _selectAll() {
    if (_document.isEmpty) {
      return;
    }

    _selection.value = DocumentSelection(
      base: DocumentPosition(
        nodeId: _document.first.id,
        nodePosition: _document.first.beginningPosition,
      ),
      extent: DocumentPosition(
        nodeId: _document.last.id,
        nodePosition: _document.last.endPosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperReaderIosControlsScope(
      controller: _iosReaderControlsController,
      child: SuperReader(
        document: _document,
        selection: _selection,
        overlayController: _overlayController,
        selectionLayerLinks: _selectionLayerLinks,
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: [
            taskStyles,
          ],
        ),
        androidToolbarBuilder: (_) => AndroidTextEditingFloatingToolbar(
          onCopyPressed: _copy,
          onSelectAllPressed: _selectAll,
        ),
      ),
    );
  }

  Widget _buildToolbar(context, mobileToolbarKey, focalPoint) {
    return IOSTextEditingFloatingToolbar(
      key: mobileToolbarKey,
      focalPoint: focalPoint,
      onCopyPressed: _copy,
    );
  }
}
