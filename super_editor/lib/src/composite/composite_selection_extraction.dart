import 'dart:ui';

import 'package:super_editor/src/composite/composite_nodes.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';

NodePosition projectPositionToParentIfNeeded(String rootNodeId, NodePath path, NodePosition position) {
  if (path.nodeId == rootNodeId) {
    return position;
  } else {
    return CompositeNodePosition.projectPositionIntoParent(rootNodeId, path, position);
  }
}

List<DocumentNode> getRootNodesInSelection(Document doc, DocumentSelection selection) {
  final basePath = doc.getNodePathById(selection.base.nodeId)!;
  final extentPath = doc.getNodePathById(selection.extent.nodeId)!;

  final result = <DocumentNode>[];
  final isDownstream = doc.getAffinityBetweenPaths(basePath, extentPath) == TextAffinity.downstream;
  String? nodeId = isDownstream ? basePath.rootNodeId : extentPath.rootNodeId;
  final untilNodeId = isDownstream ? extentPath.rootNodeId : basePath.rootNodeId;

  result.add(doc.getNodeById(nodeId)!);

  while (nodeId != null && nodeId != untilNodeId) {
    final node = doc.getNodeAfterById(nodeId, mode: NodeTraverseMode.sameParent);
    if (node != null) {
      result.add(node);
    }
    nodeId = node?.id;
  }

  return result;
}
