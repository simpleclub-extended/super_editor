import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/composite/composite_nodes.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

class ChildrenComponentKeyProvider {
  ChildrenComponentKeyProvider(this._existing);

  final Map<String, Map<String, GlobalKey<DocumentComponent>>> _existing;
  final _new = <String, Map<String, GlobalKey<DocumentComponent>>>{};

  /// Returns a [GlobalKey] for the component at [nodeId] within [rootNodeId].
  /// Reuses existing keys when possible, otherwise creates and registers a new one.
  void createKeyForNode(String rootNodeId, String nodeId) {
    // 1. Reuse from previous render
    // 2. Reuse from current render
    // 3. Create new if not found
    final key = _existing[rootNodeId]?[nodeId] ?? GlobalKey<DocumentComponent>();

    // 4. Register it in _new
    final rootMap = _new.putIfAbsent(rootNodeId, () => <String, GlobalKey<DocumentComponent>>{});
    rootMap[nodeId] = key;
  }

  GlobalKey<DocumentComponent> getKey(String rootNodeId, String nodeId) {
    return _existing[rootNodeId]?[nodeId] ?? _new[rootNodeId]?[nodeId] ?? _registerMissingKey(rootNodeId, nodeId);
  }

  GlobalKey<DocumentComponent> _registerMissingKey(String rootNodeId, String nodeId) {
    editorLayoutLog.info('WARNING: no component key was registered for node ID: $nodeId, creating one');
    final key = GlobalKey<DocumentComponent>();
    _existing.putIfAbsent(rootNodeId, () => <String, GlobalKey<DocumentComponent>>{})[nodeId] = key;
    _new.putIfAbsent(rootNodeId, () => <String, GlobalKey<DocumentComponent>>{})[nodeId] = key;
    return key;
  }

  void registerComponentKeysForChildren(String rootNodeId, SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is CompositeNodeViewModel) {
      for (final child in viewModel.children) {
        createKeyForNode(rootNodeId, child.nodeId);
        registerComponentKeysForChildren(rootNodeId, child);
      }
    }
  }

  void replaceExisting() {
    _existing.clear();
    _existing.addAll(_new);
    _new.clear();
  }
}
