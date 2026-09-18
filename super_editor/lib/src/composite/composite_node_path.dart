import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum NodeTraverseMode {
  /// Traverse all leaf nodes in depth-first manner
  allLeafs,

  /// Traverse nodes within same parent, without going inside deeper, or up outside of current parent
  sameParent,
}

/// A path of node ids that can identify a specific node in a document
/// An alternative to `nodeId` for hierarchy structure
@immutable
class NodePath with IterableMixin<String> {
  /// List of nodeIds
  final List<String> _segments;

  NodePath(Iterable<String> segments) : _segments = List.unmodifiable(segments) {
    assert(!_segments.any((s) => s.isEmpty), 'All segments of NodePath must be non-empty string');
  }

  factory NodePath.withNodeId(String nodeId) {
    return NodePath([nodeId]);
  }

  @override
  Iterator<String> get iterator => _segments.iterator;

  Iterable<String> get reversed => _segments.reversed;

  String operator [](int index) => _segments[index];

  @override
  String get first => _segments.first;

  @override
  String get last => _segments.last;

  @override
  bool get isEmpty => _segments.isEmpty;

  @override
  bool get isNotEmpty => _segments.isNotEmpty;

  @override
  int get length => _segments.length;

  bool get isRoot => length == 1;

  String get rootNodeId => first;

  /// Returns leaf node id
  String get nodeId => last;

  /// Returns leaf parent NodePath. If path is for root node, then returns null
  NodePath? get parent {
    if (isRoot) {
      return null;
    }
    return NodePath(_segments.sublist(0, length - 1));
  }

  NodePath child(String childId) {
    return NodePath([..._segments, childId]);
  }

  int indexOfNodeId(String nodeId) {
    return _segments.indexOf(nodeId);
  }

  /// Returns the deepest common ancestor path of [this] and [another].
  /// Returns `null` if the paths have no common ancestor
  /// (one or both are root, or diverge from the very beginning).
  /// When paths are identical, returns the parent of that path.
  ///
  /// The returned path is the longest prefix that is identical in both
  /// paths, excluding the last segment of this prefix — because the method
  /// returns a parent path, not the common node itself.
  ///
  /// Example: 'a/b/c' and '/a/b/d' → '/a/b'
  ///          '/a/b/c' and '/a/b/c' → '/a/b'
  ///          '/a/b'   and '/a/c'   → '/a'
  ///          '/a'     and '/b'     → null
  NodePath? deepestCommonAncestor(NodePath another) {
    if (isRoot || another.isRoot) {
      return null;
    }
    if (this == another) {
      return parent;
    }

    final commonParentIds = <String>[];
    for (var i = 0; i < min(_segments.length, another.length) - 1; i += 1) {
      if (_segments[i] != another[i]) {
        break;
      }
      commonParentIds.add(another[i]);
    }
    return commonParentIds.isEmpty ? null : NodePath(commonParentIds);
  }

  /// Returns the pair of child node paths that diverge from the deepest common ancestor
  /// of [this] and [another].
  ///
  /// In other words: finds the deepest node that is present in both paths,
  /// then returns the next segment (child) from each path.
  ///
  (NodePath, NodePath) divergingChildrenWith(NodePath another) {
    final commonParent = deepestCommonAncestor(another);
    if (commonParent == null) {
      return (NodePath([rootNodeId]), NodePath([another.rootNodeId]));
    }
    return (
      commonParent.child(this[commonParent.length]),
      commonParent.child(another[commonParent.length]),
    );
  }

  @override
  String toString() {
    return isRoot ? rootNodeId : _segments.join('/');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is NodePath && runtimeType == other.runtimeType && listEquals(_segments, other._segments));
  }

  @override
  int get hashCode => Object.hashAll(_segments);
}
