part of 'editor.dart';

mixin _CompositeDocumentPaths implements Document {
  List<DocumentNode> get _nodes;

  Map<String, DocumentNode> get _nodesById;

  Map<String, int> get _nodeIndicesById;

  void _refreshNodeIdCaches();

  void replaceNodeById(String nodeId, DocumentNode newNode);

  final Map<String, NodePath> _nodePathById = {};

  @override
  int getNodeIndexInParent(DocumentNode node) {
    if (getNodeById(node.id) != node) {
      // We found a node by id, but it wasn't the node we expected. Therefore, we couldn't find the requested node.
      return -1;
    }
    return getNodeIndexInParentByPath(_getNodePathByIdOrThrow(node.id));
  }

  @override
  int getNodeIndexInParentById(String nodeId) {
    return getNodeIndexInParentByPath(_getNodePathByIdOrThrow(nodeId));
  }

  @override
  DocumentNode? getNodeAtPath(NodePath path) {
    // TODO: We should probably cache node per path mapping
    var node = _nodesById[path.rootNodeId];
    for (final childId in path.skip(1)) {
      if (node == null) {
        return null;
      }
      assert(
        node is CompositeNode,
        'Unable to get node at $path, when $childId is not CompositeNode (${node.runtimeType} was given)',
      );
      node = (node as CompositeNode).getChildByNodeId(childId);
    }
    return node;
  }

  @override
  NodePath? getNodePathById(String nodeId) {
    return _nodePathById[nodeId];
  }

  @override
  int getNodeIndexInParentByPath(NodePath path) {
    final parentPath = path.parent;
    if (parentPath == null) {
      return _nodeIndicesById[path.rootNodeId] ?? -1;
    }
    final parent = getNodeAtPath(parentPath) as CompositeNode;
    return parent.getChildIndexByNodeId(path.nodeId);
  }

  @override
  Iterable<(NodePath, DocumentNode)> getLeafNodes({
    bool? reversed,
    NodePath? since,
    bool? treatEmptyCompositeNodesAsLeaf,
  }) sync* {
    final iterator = _LeafNodeIterator(
      this,
      sincePath: since,
      reversed: reversed,
      treatEmptyCompositeAsLeaf: treatEmptyCompositeNodesAsLeaf,
    );
    while (iterator.moveNext()) {
      yield iterator.current;
    }
  }

  /// Returns **all leaf nodes** that lie within the range between the node with [nodeId1]
  /// and the node with [nodeId2], **inclusive** of both endpoints.
  ///
  /// The traversal is performed in document order: the method automatically determines
  /// which of the two nodes comes first and iterates from the earlier ("upstream")
  /// node to the later ("downstream") one, collecting only leaf nodes along the way.
  ///
  /// ### How partial selection inside [CompositeNode] works
  /// If the range partially covers a [CompositeNode] (e.g., both anchors are inside the same composite,
  /// or the lowest common ancestor is a composite), the method delegates to that composite node's
  /// [CompositeNode.getSelectedChildrenBetween] to filter which of its **leaf descendants**
  /// should be included. This enables smart partial selections — e.g., a table might include
  /// only cells in certain rows, not the entire structure.
  ///
  /// Intermediate composite nodes are **not** returned; only leaves are.
  ///
  /// ### Throws
  /// - [Exception] if either node ID does not exist in the document.
  /// - [Exception] if either node is a [CompositeNode] (or any non-leaf node).
  /// - [Exception] if the downstream node is not reachable after the upstream node
  ///   (indicates corrupted or unnormalized document structure).
  ///
  @override
  List<DocumentNode> getNodesInsideById(String nodeId1, String nodeId2) {
    final path1 = _nodePathById[nodeId1];
    final path2 = _nodePathById[nodeId2];

    if (path1 == null) {
      throw Exception('No such position in document: $nodeId1');
    }
    if (path2 == null) {
      throw Exception('No such position in document: $nodeId2');
    }
    if (getNodeAtPath(path1) case final node when node is CompositeNode) {
      throw Exception(
        'getNodesInsideById: nodeId1 ($nodeId1) points to a CompositeNode (${node.runtimeType}). '
        'Only leaf nodes are allowed as range anchors.',
      );
    }
    if (getNodeAtPath(path2) case final node when node is CompositeNode) {
      throw Exception(
        'getNodesInsideById: nodeId2 ($nodeId2) points to a CompositeNode (${node.runtimeType}). '
        'Only leaf nodes are allowed as range anchors.',
      );
    }

    if (path1 == path2) {
      return [getNodeAtPath(path1)!];
    }

    final (upstreamPath, downstreamPath) = _selectUpstreamDownstreamPaths(path1, path2);

    final selectedNodeIdsPerParentId = <String, List<String>>{};

    if (!upstreamPath.isRoot || !downstreamPath.isRoot) {
      // When one of nodes is inside CompositeNode, compute additional node filtering,
      // based on [getSelectedChildrenBetween] implementation of CompositeNode.
      // Here we are looking for last common parent and call [getSelectedChildrenBetween].
      // If there is no common parent - compute selection based on beginning/end position

      final (upDivergingChild, downDivergingChild) = upstreamPath.divergingChildrenWith(downstreamPath);

      void addParentSelection(String parentId, {String? from, String? to}) {
        final parent = getNodeById(parentId) as CompositeNode;
        final selection = parent.getSelectedChildrenBetween(
          from ?? parent.children.first.id,
          to ?? parent.children.last.id,
        );
        if (selection != null) {
          selectedNodeIdsPerParentId[parentId] = selection;
        }
      }

      if (upDivergingChild.parent != null && upDivergingChild.parent == downDivergingChild.parent) {
        // the difference is not since root node - we have a common CompositeNode
        addParentSelection(
          upDivergingChild.parent!.nodeId,
          from: upDivergingChild.nodeId,
          to: downDivergingChild.nodeId,
        );
      } else {
        if (!upstreamPath.isRoot) {
          addParentSelection(upstreamPath.rootNodeId, from: upstreamPath[1]);
        }
        if (!downstreamPath.isRoot) {
          addParentSelection(downstreamPath.rootNodeId, to: downstreamPath[1]);
        }
      }
    }

    var success = false;
    final result = <DocumentNode>[getNodeAtPath(upstreamPath)!];

    for (final (path, node) in getLeafNodes(since: upstreamPath)) {
      var shouldSkip = false;

      if (selectedNodeIdsPerParentId.isNotEmpty) {
        // Loop through all parents in path and check if its child conforms selection
        for (var i = 0; i < path.length - 1; i += 1) {
          final selection = selectedNodeIdsPerParentId[path[i]];
          if (selection != null) {
            shouldSkip = !selection.contains(path[i + 1]);
            // Since selectedNodeIdsPerParentId is calculated for last common parent only
            // no need to loop further
            break;
          }
        }
      }

      if (!shouldSkip) {
        result.add(node);
      }

      if (path == downstreamPath) {
        success = true;
        break;
      }
    }
    if (!success) {
      throw Exception(
        'Unable to find $downstreamPath below $upstreamPath. Make sure positions are normalized and nodes exists',
      );
    }
    return result;
  }

  bool deleteNodeAtPath(NodePath nodePath) {
    if (nodePath.isRoot) {
      final nodeToDelete = getNodeAtPath(nodePath);
      if (nodeToDelete == null) {
        throw Exception('Unable to delete node. No node at path $nodePath');
      }
      final index = getNodeIndexInParentById(nodePath.rootNodeId);
      if (index < 0) {
        return false;
      }

      _nodes.removeAt(index);
      _refreshNodeIdCaches();

      return true;
    } else {
      final parent = getNodeAtPath(nodePath.parent!) as CompositeNode;
      final nodeToDelete = parent.getChildByNodeId(nodePath.nodeId);
      if (nodeToDelete == null) {
        // child does not exists at given path
        return false;
      }
      _replaceChildrenAtPath(nodePath.parent!, (parent, children) {
        return children.where((c) => c.id != nodeToDelete.id).toList();
      });
      _refreshNodeIdCaches();
      return true;
    }
  }

  (NodePath, NodePath) _selectUpstreamDownstreamPaths(NodePath path1, NodePath path2) {
    final (baseDivergingChild, extentDivergingChild) = path1.divergingChildrenWith(path2);
    final isDownstream =
        getNodeIndexInParentByPath(baseDivergingChild) < getNodeIndexInParentByPath(extentDivergingChild);
    return isDownstream ? (path1, path2) : (path2, path1);
  }

  void _replaceChildrenAtPath(
    NodePath path,
    List<DocumentNode> Function(CompositeNode parent, List<DocumentNode>) replacer,
  ) {
    final node = getNodeById(path.rootNodeId);
    assert(node is CompositeNode);
    final replacement = (node as CompositeNode).copyAndReplaceLeafChildren(
      nodePath: path,
      childrenReplacer: replacer,
    );
    replaceNodeById(path.rootNodeId, replacement);
  }

  void _registerNodePath(DocumentNode node, NodePath path) {
    assert(!_nodePathById.containsKey(node.id),
        'Node with id "${node.id}" is already registered at ${_nodePathById[node.id]}, but tried to re-register at $path implicitly. It must be unregistered first');
    _nodePathById[node.id] = path;
    if (node is CompositeNode) {
      for (final child in node.children) {
        _registerNodePath(child, path.child(child.id));
      }
    }
  }

  void _unregisterNodePath(DocumentNode node) {
    _nodePathById.remove(node.id);
    if (node is CompositeNode) {
      for (final child in node.children) {
        _unregisterNodePath(child);
      }
    }
  }

  NodePath _getNodePathByIdOrThrow(String nodeId) {
    final path = _nodePathById[nodeId];
    if (path == null) {
      throw Exception('Unable to find node by id "$nodeId"');
    }
    return path;
  }
}

/// Iterates through all Leaf Nodes of the Document (Depth-First Search)
class _LeafNodeIterator implements Iterator<(NodePath, DocumentNode)> {
  final _CompositeDocumentPaths _document;

  final _parents = <CompositeNode>[];
  final _indices = <int>[];

  final int _increment;

  final bool _treatEmptyCompositeAsLeaf;

  NodePath? _currentPath;
  DocumentNode? _currentNode;

  _LeafNodeIterator(
    this._document, {
    /// Starts iteration from path (excluding [sincePath]). Otherwise start from beginning
    NodePath? sincePath,

    /// Specifies iteration direction
    bool? reversed,

    /// when set to true, it would return empty CompositeNode as leaf
    bool? treatEmptyCompositeAsLeaf,
  })  : _increment = reversed == true ? -1 : 1,
        _treatEmptyCompositeAsLeaf = treatEmptyCompositeAsLeaf ?? false {
    if (sincePath != null) {
      var node = _document.getNodeById(sincePath.rootNodeId);
      _indices.add(_document.getNodeIndexById(sincePath.rootNodeId));
      for (final childId in sincePath.skip(1)) {
        _parents.add(node as CompositeNode);
        _indices.add(node.getChildIndexByNodeId(childId));
        node = node.getChildByNodeId(childId);
      }
      _currentNode = node;
      _currentPath = sincePath;
    }
  }

  @override
  get current => (_currentPath!, _currentNode!);

  @override
  bool moveNext() {
    if (_currentNode == null) {
      _addStartIndexForCurrentParent();
    }
    if (_moveWithinCurrentParent()) {
      _currentPath = NodePath([..._parents.map((p) => p.id), _currentNode!.id]);
      return true;
    }
    return false;
  }

  bool _moveWithinCurrentParent() {
    final index = _indices.last;
    final newIndex = index + _increment;

    if (newIndex >= 0 && newIndex < _currentChildren.length) {
      // Moving within current parent
      _indices[_indices.length - 1] = newIndex;
      return _fallToLeaf();
    } else {
      if (_parents.isNotEmpty) {
        // Moving up
        _parents.removeLast();
        _indices.removeLast();
        // Going next within new parent
        return _moveWithinCurrentParent();
      } else {
        // We reached end of document
        return false;
      }
    }
  }

  bool _fallToLeaf() {
    var index = _indices.last;
    final node = _currentChildren.elementAt(index);

    if (node is CompositeNode && (!_treatEmptyCompositeAsLeaf || node.children.isNotEmpty)) {
      // current node is a CompositeNode, go deeper
      _parents.add(node);
      _addStartIndexForCurrentParent();
      return _moveWithinCurrentParent();
    } else {
      // leaf node found, finish search
      _currentNode = node;
      return true;
    }
  }

  void _addStartIndexForCurrentParent() {
    if (_increment > 0) {
      _indices.add(-_increment);
    } else {
      _indices.add(_currentChildren.length - _increment - 1);
    }
  }

  Iterable<DocumentNode> get _currentChildren {
    return _parents.isNotEmpty ? _parents.last.children : _document._nodes;
  }
}
