import 'dart:math';
import 'dart:ui';

import 'package:super_editor/super_editor.dart';

extension InspectDocumentPathAffinity on Document {
  TextAffinity getAffinityBetweenPaths(NodePath basePath, NodePath extentPath) {
    final (baseDivergingChild, extentDivergingChild) = basePath.divergingChildrenWith(extentPath);

    return getNodeIndexInParentByPath(baseDivergingChild) < getNodeIndexInParentByPath(extentDivergingChild)
        ? TextAffinity.downstream
        : TextAffinity.upstream;
  }
}

extension ExpandDocumentSelection on Document {
  DocumentSelection expandSelection(DocumentSelection selection, DocumentPosition extentPosition) {
    if (selection is AdjustedDocumentSelection) {
      return DocumentSelection(
        base: selection.original.base,
        extent: extentPosition,
      );
    } else {
      return DocumentSelection(
        base: selection.base,
        extent: extentPosition,
      );
    }
  }

  /// Applies [CompositeNode]-specific adjustments to a leaf-based selection.
  ///
  /// Walks bottom-up from both anchors, lifting positions level by level into
  /// [CompositeNodePosition]. At each level, the corresponding [CompositeNode]
  /// may adjust the upstream boundary ([adjustUpstreamPosition]) and/or downstream
  /// boundary ([adjustDownstreamPosition]). If both anchors are inside the same
  /// composite node, it sees the opposing boundary and can make coordinated changes.
  ///
  /// This enables "smart" selection snapping in complex blocks like tables, banners, etc
  ///
  /// Returns an [AdjustedDocumentSelection] with possibly modified base/extent
  /// (but preserving the original for correct shift-click behavior) if any
  /// composite node performed an adjustment. Otherwise returns the input [selection]
  /// unchanged.
  ///
  /// Requires that both base and extent refer to leaf nodes with leaf positions.
  DocumentSelection refineSelectionWithCompositeNodeAdjustments(DocumentSelection selection) {
    if (selection.base.nodePosition is CompositeNodePosition ||
        selection.extent.nodePosition is CompositeNodePosition) {
      throw Exception('Both base and extent positions must be leaf positions before they can be adjusted');
    }

    final basePath = getNodePathById(selection.base.nodeId)!;
    final extentPath = getNodePathById(selection.extent.nodeId)!;
    if (basePath.isRoot && extentPath.isRoot) {
      // as both paths are for root nodes, no CompositeNode was involved
      return selection;
    }

    final isDownstream = getAffinityBetweenPaths(basePath, extentPath) == TextAffinity.downstream;

    final upstream = isDownstream ? selection.base : selection.extent;
    final downstream = isDownstream ? selection.extent : selection.base;
    final upstreamPath = isDownstream ? basePath : extentPath;
    final downstreamPath = isDownstream ? extentPath : basePath;

    final (upstreamPosition, downstreamPosition, adjusted) = _liftAndAdjustPositions(
      upstreamPath: upstreamPath,
      downstreamPath: downstreamPath,
      upstreamPosition: upstream.nodePosition,
      downstreamPosition: downstream.nodePosition,
    );

    if (adjusted) {
      return AdjustedDocumentSelection(
        base: DocumentPosition(
          nodeId: isDownstream ? upstreamPath.rootNodeId : downstreamPath.rootNodeId,
          nodePosition: isDownstream ? upstreamPosition : downstreamPosition,
        ).toLeafPosition(),
        extent: DocumentPosition(
          nodeId: isDownstream ? downstreamPath.rootNodeId : upstreamPath.rootNodeId,
          nodePosition: isDownstream ? downstreamPosition : upstreamPosition,
        ).toLeafPosition(),
        original: selection,
      );
    } else {
      return selection;
    }
  }

  bool shouldIsolateNodes(List<String> nodeIds) {
    final parents = <String?>{};
    var hasIsolatingParent = false;
    for (final nodeId in nodeIds) {
      final parentId = getNodePathById(nodeId)?.parent?.nodeId;
      parents.add(parentId);
      if (parentId == null) {
        continue;
      }
      final parent = getNodeById(parentId) as CompositeNode;
      if (parent.isIsolating) {
        hasIsolatingParent = true;
      }
    }
    return hasIsolatingParent && parents.length > 1;
  }

  /// Bottom-up lift + adjustment of both positions across shared ancestor levels.
  (NodePosition, NodePosition, bool) _liftAndAdjustPositions({
    required NodePosition upstreamPosition,
    required NodePosition downstreamPosition,
    required NodePath upstreamPath,
    required NodePath downstreamPath,
  }) {
    var adjusted = false;

    // Go bottom-up by both paths, and preprocess selection by each CompositeNode
    for (var i = max(upstreamPath.length, downstreamPath.length) - 1; i > 0; i -= 1) {
      final upstreamParentId = upstreamPath.length > i ? upstreamPath[i - 1] : null;
      final downstreamParentId = downstreamPath.length > i ? downstreamPath[i - 1] : null;

      if (upstreamParentId != null) {
        upstreamPosition = CompositeNodePosition(upstreamPath[i], upstreamPosition);
      }
      if (downstreamParentId != null) {
        downstreamPosition = CompositeNodePosition(downstreamPath[i], downstreamPosition);
      }
      CompositeNodePosition? adjustedUpstreamPosition;
      CompositeNodePosition? adjustedDownstreamPosition;

      if (upstreamParentId != null) {
        final upstreamParent = getNodeById(upstreamParentId) as CompositeNode;
        adjustedUpstreamPosition = upstreamParent.adjustUpstreamPosition(
          upstreamPosition: upstreamPosition as CompositeNodePosition,
          downstreamPosition:
              upstreamParentId == downstreamParentId ? downstreamPosition as CompositeNodePosition : null,
        );
      }

      if (downstreamParentId != null) {
        final downstreamParent = getNodeById(downstreamParentId) as CompositeNode;
        adjustedDownstreamPosition = downstreamParent.adjustDownstreamPosition(
          downstreamPosition: downstreamPosition as CompositeNodePosition,
          upstreamPosition: upstreamParentId == downstreamParentId ? upstreamPosition as CompositeNodePosition : null,
        );
      }
      // Writing adjusted positions after getting both upstream/downstream from CompositeNode, so
      // both adjust upstream/downstream methods takes original ones as input
      if (adjustedUpstreamPosition != null) {
        upstreamPosition = adjustedUpstreamPosition;
        adjusted = true;
      }
      if (adjustedDownstreamPosition != null) {
        downstreamPosition = adjustedDownstreamPosition;
        adjusted = true;
      }
    }

    return (upstreamPosition, downstreamPosition, adjusted);
  }
}

extension DocumentSelectionNodeLookup on Document {
  /// Returns the first [DocumentNode] after [startingNode] in [direction] whose
  /// [DocumentComponent] is visually selectable and matches [nearX]
  /// [nearX] is in document coordinate space and might be used to match correct node vertically
  /// when moving up and down (for example to get correct column in a table)
  DocumentNode? getNextSelectableNode({
    required DocumentNode startingNode,
    required DocumentLayoutResolver documentLayoutResolver,
    required DocumentNodeLookupDirection direction,
    double? nearX,
  }) {
    final layout = documentLayoutResolver();
    final iterator = _DirectionalLeafNodeIterator(
      this,
      documentLayoutResolver,
      sinceNode: startingNode,
      direction: direction,
      nearX: nearX,
    );
    while (iterator.moveNext()) {
      final current = iterator.current;
      final component = layout.getComponentByNodeId(current.id);
      if (component != null && component.isVisualSelectionSupported()) {
        return current;
      }
    }
    return null;
  }
}

/// A [DocumentSelection] that preserves the **original** user-intended
/// selection alongside a possibly **adjusted** (snapped, refined) version.
///
/// This is critical for correct **Shift+Click** behavior:
/// - When extending selection with Shift, the editor must use the **original** base
///   (where the user first clicked), not the one that was silently moved by a
///   [CompositeNode] (e.g. table snapping the cursor to the start of a cell).
/// - But visually and for operations, we want to use the **adjusted** positions.
///
/// Without this distinction, Shift+Click selection grows unpredictably.
///
/// Use [original] when computing new selection range on Shift+Click.
/// Use [base]/[extent] (inherited) for rendering and actual operations.
class AdjustedDocumentSelection extends DocumentSelection {
  AdjustedDocumentSelection({
    required super.base,
    required super.extent,
    required this.original,
  });

  final DocumentSelection original;
}

enum DocumentNodeLookupDirection { up, down, left, right }

/// Similar DeepFirstSearch to _LeafNodeIterator, but:
/// - follows direction with [getFirstChildInDirection] and [getNextChildInDirection] calls
/// - uses nearX for up/down directions (so when you jump down from paragraph to table, it can go to correct column)
class _DirectionalLeafNodeIterator implements Iterator<DocumentNode> {
  final Document _document;
  final DocumentLayoutResolver _layoutResolver;

  final _path = <String>[];
  final _parentComponents = <CompositeComponent>[];

  final DocumentNodeLookupDirection _direction;
  final double? nearX;

  DocumentNode? _currentNode;

  _DirectionalLeafNodeIterator(
    this._document,
    this._layoutResolver, {
    required DocumentNode sinceNode,
    required DocumentNodeLookupDirection direction,
    this.nearX,
  }) : _direction = direction {
    final path = _document.getNodePathById(sinceNode.id)!;
    final layout = _layoutResolver();
    for (var i = 0; i < path.length - 1; i += 1) {
      final parentId = path[i];
      _parentComponents.add(layout.getComponentByNodeId(parentId) as CompositeComponent);
      _path.add(parentId);
    }
    _path.add(path.nodeId);
    _currentNode = sinceNode;
  }

  @override
  get current => _currentNode!;

  @override
  bool moveNext() {
    return _moveWithinCurrentParent();
  }

  bool _moveWithinCurrentParent() {
    final nodeId = _path.last;
    final nextNodeId = _nextNodeId(nodeId);

    if (nextNodeId != null) {
      _path[_path.length - 1] = nextNodeId;
      return _fallToLeaf();
    } else {
      if (_parentComponents.isNotEmpty) {
        // moving up
        _parentComponents.removeLast();
        _path.removeLast();
        return _moveWithinCurrentParent();
      } else {
        // we reached end of document
        return false;
      }
    }
  }

  bool _fallToLeaf() {
    final nodeId = _path.last;
    final component = _layoutResolver().getComponentByNodeId(nodeId);
    final node = _document.getNodeById(nodeId);

    if (node is CompositeNode) {
      // current node is a CompositeNode, go deeper
      _parentComponents.add(component as CompositeComponent);

      double? offsetInComponent;
      if (nearX != null) {
        offsetInComponent = _layoutResolver()
            .getAncestorOffsetFromDocumentOffset(Offset(nearX!, 0), component.context.findRenderObject())
            .dx;
      }
      _path.add(component.getFirstChildInDirection(_direction, nearX: offsetInComponent).nodeId);
      return _fallToLeaf();
    } else {
      // leaf node found, finish search
      _currentNode = node;
      return true;
    }
  }

  String? _nextNodeId(String sinceNodeId) {
    if (_parentComponents.isEmpty) {
      final goForward =
          _direction == DocumentNodeLookupDirection.right || _direction == DocumentNodeLookupDirection.down;
      return goForward
          ? _document.getNodeAfterById(sinceNodeId, mode: NodeTraverseMode.sameParent)?.id
          : _document.getNodeBeforeById(sinceNodeId, mode: NodeTraverseMode.sameParent)?.id;
    } else {
      return _parentComponents.last.getNextChildInDirection(sinceNodeId, _direction)?.nodeId;
    }
  }
}
