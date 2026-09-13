import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const testTableBlockType = NamedAttribution('testTable');

const testCellBlockType = NamedAttribution('testCell');

class TestTableNode extends CompositeNode {
  TestTableNode({
    required super.id,
    required this.children,
    Map<String, dynamic>? metadata,
  }) : super(
          metadata: {
            if (metadata != null) //
              ...metadata,
            NodeMetadata.blockType: testTableBlockType,
          },
        );

  @override
  final List<DocumentNode> children;

  @override
  CompositeNode copyWithChildren(List<DocumentNode> newChildren) {
    return TestTableNode(id: id, children: newChildren, metadata: metadata);
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return TestTableNode(id: id, children: children, metadata: newMetadata);
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return TestTableNode(id: id, children: children, metadata: {...metadata, ...newProperties});
  }

  @override
  CompositeNode? resolveWhenChildrenAffected({
    required List<String> removedChildIds,
    required List<String> emptiedChildIds,
    required bool selectionFlowedThrough,
  }) {
    if (children.isEmpty || emptiedChildIds.length == children.length) {
      return null;
    }
    return this;
  }
}

class TestCellNode extends CompositeNode {
  TestCellNode({
    required super.id,
    required this.children,
    this.isIsolating = true,
    Map<String, dynamic>? metadata,
  }) : super(
          metadata: {
            if (metadata != null) //
              ...metadata,
            NodeMetadata.blockType: testCellBlockType,
          },
        );

  @override
  final List<DocumentNode> children;

  @override
  final bool isIsolating;

  @override
  CompositeNode copyWithChildren(List<DocumentNode> newChildren) {
    return TestCellNode(id: id, children: newChildren, isIsolating: isIsolating, metadata: metadata);
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return TestCellNode(id: id, children: children, isIsolating: isIsolating, metadata: newMetadata);
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return TestCellNode(
      id: id,
      children: children,
      isIsolating: isIsolating,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  CompositeNode? resolveWhenChildrenAffected({
    required List<String> removedChildIds,
    required List<String> emptiedChildIds,
    required bool selectionFlowedThrough,
  }) {
    if (children.isEmpty) {
      final replacedId = (removedChildIds.isNotEmpty ? removedChildIds : emptiedChildIds).last;
      return copyWithChildren([ParagraphNode(id: replacedId, text: AttributedText())]);
    }
    return this;
  }
}

class TestCompositeNodeViewModel extends CompositeNodeViewModel {
  TestCompositeNodeViewModel({
    required super.nodeId,
    required super.children,
  });

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return internalCopy(
      TestCompositeNodeViewModel(nodeId: nodeId, children: children),
    );
  }
}

class TestCompositeComponentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    PresenterContext presenterContext,
    Document document,
    DocumentNode node,
  ) {
    if (node is! TestTableNode && node is! TestCellNode) {
      return null;
    }
    return TestCompositeNodeViewModel(
      nodeId: node.id,
      children: (node as CompositeNode).children.map((child) => presenterContext.createViewModel(child)!),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TestCompositeNodeViewModel) {
      return null;
    }
    return ColumnDocumentComponent(
      key: componentContext.componentKey,
      children: componentViewModel.children.map((childViewModel) {
        final (componentKey, component) = componentContext.buildChildComponent(childViewModel);
        return CompositeComponentChild(
          nodeId: childViewModel.nodeId,
          componentKey: componentKey,
          widget: component,
        );
      }).toList(),
    );
  }
}

MutableDocument paragraphThenCellsThenParagraphDoc({
  required int cellCount,
  bool isIsolating = true,
}) {
  return MutableDocument(
    nodes: [
      ParagraphNode(id: '1', text: AttributedText('First paragraph')),
      TestTableNode(
        id: 'table',
        children: [
          for (var i = 1; i <= cellCount; i += 1)
            TestCellNode(
              id: 'cell$i',
              isIsolating: isIsolating,
              children: [ParagraphNode(id: 'p$i', text: AttributedText('Cell $i text'))],
            ),
        ],
      ),
      ParagraphNode(id: '3', text: AttributedText('Last paragraph')),
    ],
  );
}
