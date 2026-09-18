part of '_styler_user_selection.dart';

mixin _CompositeSelectionStyler {
  Document get _document;

  DocumentNodeSelection? _computeCompositeNodeSelection({
    required DocumentSelection documentSelection,
    required List<DocumentNode> selectedNodes,
    required CompositeNode node,
  }) {
    final basePath = _document.getNodePathById(documentSelection.base.nodeId)!;
    final extentPath = _document.getNodePathById(documentSelection.extent.nodeId)!;
    if (basePath.contains(node.id) && extentPath.contains(node.id)) {
      // If the selection is fully within this CompositeNode

      final compositeBasePosition = CompositeNodePosition.projectPositionIntoParent(
        node.id,
        basePath,
        documentSelection.base.nodePosition,
      );
      final compositeExtentPosition = CompositeNodePosition.projectPositionIntoParent(
        node.id,
        extentPath,
        documentSelection.extent.nodePosition,
      );
      final nodeSelection = node.computeSelection(base: compositeBasePosition, extent: compositeExtentPosition);

      return DocumentNodeSelection(
        nodeId: node.id,
        nodeSelection: nodeSelection,
        isBase: true,
        isExtent: true,
      );
    } else {
      final selectedNodePaths = selectedNodes.map((node) => _document.getNodePathById(node.id)!).toList();
      if (selectedNodePaths.every((path) => !path.contains(node.id))) {
        // No leaf of this CompositeNode is selected
        return null;
      }
      bool isBase = false, isExtent = false;
      NodePosition basePosition;
      NodePosition extentPosition;

      final affinity = _document.getAffinityBetweenPaths(basePath, extentPath);
      final isDownstream = affinity == TextAffinity.downstream;

      if (basePath.contains(node.id)) {
        // Selection starts inside CompositeNode, but ends outside
        basePosition = CompositeNodePosition.projectPositionIntoParent(
          node.id,
          basePath,
          documentSelection.base.nodePosition,
        );
        extentPosition = isDownstream ? node.endPosition : node.beginningPosition;
        isBase = true;
      } else if (extentPath.contains(node.id)) {
        // Selection starts outside CompositeNode, but ends inside
        basePosition = isDownstream ? node.beginningPosition : node.endPosition;
        extentPosition = CompositeNodePosition.projectPositionIntoParent(
          node.id,
          extentPath,
          documentSelection.extent.nodePosition,
        );
        isExtent = true;
      } else {
        // Whole CompositeNode is inside selection
        basePosition = isDownstream ? node.beginningPosition : node.endPosition;
        extentPosition = isDownstream ? node.endPosition : node.beginningPosition;
      }

      final nodeSelection = node.computeSelection(base: basePosition, extent: extentPosition);
      return DocumentNodeSelection(
        nodeId: node.id,
        nodeSelection: nodeSelection,
        isBase: isBase,
        isExtent: isExtent,
      );
    }
  }
}
