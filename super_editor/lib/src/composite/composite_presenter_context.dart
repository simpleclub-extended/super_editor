import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';

/// Finds and creates the component widget that presents the given [node].
typedef ComponentWidgetBuilder = (GlobalKey<DocumentComponent>, Widget) Function(
    SingleColumnLayoutComponentViewModel viewModel);

/// A context provided to [ComponentBuilder]s when constructing view models.
class PresenterContext {
  const PresenterContext(this._document, this._componentBuilders);

  final Document _document;
  final List<ComponentBuilder> _componentBuilders;

  /// Creates a view model for [node] by trying each builder in turn, or `null` if none apply.
  SingleColumnLayoutComponentViewModel? createViewModel(DocumentNode node) {
    for (final builder in _componentBuilders) {
      final viewModel = builder is CompositeAwareComponentBuilder
          ? builder.createCompositeViewModel(this, _document, node)
          : builder.createViewModel(_document, node);
      if (viewModel != null) {
        return viewModel;
      }
    }
    return null;
  }
}

/// A [ComponentBuilder] that needs the composite [PresenterContext] to build view models
/// for nodes composed of other nodes.
///
/// Implementations get their view models from [createCompositeViewModel]; calling
/// [createViewModel] directly throws, since building the view model requires [PresenterContext].
abstract mixin class CompositeAwareComponentBuilder implements ComponentBuilder {
  /// Produces a view model for [node], using [presenterContext] to build any nested
  /// view models, or `null` if this builder doesn't apply to [node].
  SingleColumnLayoutComponentViewModel? createCompositeViewModel(
    PresenterContext presenterContext,
    Document document,
    DocumentNode node,
  );

  /// Always throws; call [createCompositeViewModel] instead, since this builder
  /// requires a [PresenterContext] to build view models.
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) =>
      throw UnsupportedError('$runtimeType builds view models through PresenterContext.');
}
