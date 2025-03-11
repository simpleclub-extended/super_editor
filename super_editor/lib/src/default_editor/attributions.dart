import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';

/// Header 1 style block attribution.
const header1Attribution = NamedAttribution('header1');

/// Header 2 style block attribution.
const header2Attribution = NamedAttribution('header2');

/// Header 3 style block attribution.
const header3Attribution = NamedAttribution('header3');

/// Header 4 style block attribution.
const header4Attribution = NamedAttribution('header4');

/// Header 5 style block attribution.
const header5Attribution = NamedAttribution('header5');

/// Header 6 style block attribution.
const header6Attribution = NamedAttribution('header6');

/// Plain paragraph block attribution.
const paragraphAttribution = NamedAttribution('paragraph');

/// Blockquote attribution
const blockquoteAttribution = NamedAttribution('blockquote');

/// Bold style attribution.
const boldAttribution = NamedAttribution('bold');

/// Italics style attribution.
const italicsAttribution = NamedAttribution('italics');

/// Underline style attribution.
const underlineAttribution = NamedAttribution('underline');

/// Strikethrough style attribution.
const strikethroughAttribution = NamedAttribution('strikethrough');

/// Superscript style attribution.
const superscriptAttribution = ScriptAttribution.superscript();

/// Subscript style attribution.
const subscriptAttribution = ScriptAttribution.subscript();

/// Code style attribution.
const codeAttribution = NamedAttribution('code');

/// Spelling error attribution.
const spellingErrorAttribution = NamedAttribution('spelling-error');

/// Grammar error attribution.
const grammarErrorAttribution = NamedAttribution('grammar-error');

/// An attribution for superscript and subscript text.
class ScriptAttribution implements Attribution {
  static const typeSuper = "superscript";
  static const typeSub = "subscript";

  const ScriptAttribution.superscript() : type = typeSuper;

  const ScriptAttribution.subscript() : type = typeSub;

  @override
  String get id => "script";

  final String type;

  @override
  bool canMergeWith(Attribution other) {
    return other is ScriptAttribution && type == other.type;
  }
}

/// TeX attribution.
///
/// This is a custom simpleclub attribution.
/// Its styling must be handled on the package user level.
///
/// In case of simpleclub, styling of TeX is handled in "shared".
const simpleclubTeXAttribution = NamedAttribution('simpleclubTeX');

/// Color attribution.
///
/// This is a custom simpleclub attribution.
/// Its styling must be handled on the package user level.
///
/// See: [ContentColorScheme] in simpleclub shared.
class SimpleclubColorAttribution implements Attribution {
  SimpleclubColorAttribution({
    required this.colorIndex,
  });

  @override
  String get id => 'simpleclubColor$colorIndex';

  /// Index of the color from 1 to 9.
  final int colorIndex;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleclubColorAttribution && runtimeType == other.runtimeType && colorIndex == other.colorIndex;

  @override
  int get hashCode => colorIndex.hashCode;

  @override
  String toString() {
    return '[ColorAttribution]: $colorIndex';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a text color change.
///
/// Every [ColorAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [ColorAttribution]s
/// from overlapping.
class ColorAttribution implements Attribution {
  const ColorAttribution(this.color);

  @override
  String get id => 'color';

  final Color color;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ColorAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() {
    return '[ColorAttribution]: $color';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a backgrounnd color change.
///
/// Every [BackgroundColorAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [BackgroundColorAttribution]s
/// from overlapping.
class BackgroundColorAttribution implements Attribution {
  const BackgroundColorAttribution(this.color);

  @override
  String get id => 'background_color';

  final Color color;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundColorAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() {
    return '[BackgroundColorAttribution]: $color';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a font size change.
///
/// Every [FontSizeAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [FontSizeAttribution]s
/// from overlapping.
class FontSizeAttribution implements Attribution {
  const FontSizeAttribution(this.fontSize);

  @override
  String get id => 'font_size';

  final double fontSize;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontSizeAttribution && runtimeType == other.runtimeType && fontSize == other.fontSize;

  @override
  int get hashCode => fontSize.hashCode;

  @override
  String toString() {
    return '[FontSizeAttribution]: $fontSize';
  }
}

/// Attribution that says the text within it should use the given
/// [fontFamily].
///
/// Every [FontFamilyAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [FontFamilyAttribution]s
/// from overlapping.
class FontFamilyAttribution implements Attribution {
  const FontFamilyAttribution(this.fontFamily);

  @override
  String get id => 'font_family';

  final String fontFamily;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamilyAttribution && runtimeType == other.runtimeType && fontFamily == other.fontFamily;

  @override
  int get hashCode => fontFamily.hashCode;

  @override
  String toString() {
    return '[FontFamilyAttribution]: $fontFamily';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent a link.
///
/// A link might be a URL or a URI. URLs are a subset of URIs.
/// A URL begins with a scheme and "://", e.g., "https://" or
/// "obsidian://". A URI begins with a scheme and a ":", e.g.,
/// "mailto:" or "spotify:".
///
/// Every [LinkAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [LinkAttribution]s
/// from overlapping.
///
/// If [LinkAttribution] does not meet your development needs,
/// a different class or value can be used to implement links
/// within [AttributedText]. This class doesn't have a special
/// relationship with [AttributedText].
class LinkAttribution implements Attribution {
  /// Creates a [LinkAttribution] from a structured [URI] (instead of plain text).
  ///
  /// The [plainTextUri] for the returned [LinkAttribution] is set to
  /// the [uri]'s `toString()` value.
  factory LinkAttribution.fromUri(Uri uri) {
    if (!uri.hasScheme) {
      // Without a scheme, a URI is fairly useless. We can't be sure
      // that any other part of the URI was parsed correctly if it
      // didn't begin with a scheme. Fallback to a plain text-only
      // attribution.
      return LinkAttribution(uri.toString());
    }

    return LinkAttribution(uri.toString(), uri);
  }

  /// Create a [LinkAttribution] based on a given [email] address.
  ///
  /// This factory is equivalent to calling [LinkAttribution.fromUri]
  /// with a [Uri] whose `scheme` is "mailto" and whose `path` is [email].
  factory LinkAttribution.fromEmail(String email) {
    return LinkAttribution.fromUri(
      Uri(
        scheme: "mailto",
        path: email,
      ),
    );
  }

  /// Creates a [LinkAttribution] whose plain-text URI is [plainTextUri], and
  /// which (optionally) includes a structured [Uri] version of the
  /// same URI.
  ///
  /// [LinkAttribution] allows for text only creation because there may
  /// be situations where apps must apply link attributions to invalid
  /// URIs, such as when loading documents created elsewhere.
  const LinkAttribution(this.plainTextUri, [this.uri]);

  @override
  String get id => 'link';

  @Deprecated("Use plainTextUri instead. The term 'url' was a lie - it could always have been a URI.")
  String get url => plainTextUri;

  /// The URI associated with the attributed text, as a `String`.
  final String plainTextUri;

  /// Returns `true` if this [LinkAttribution] has [uri], which is
  /// a structured representation of the associated URI.
  bool get hasStructuredUri => uri != null;

  /// The structured [Uri] associated with this attribution's [plainTextUri].
  ///
  /// In the nominal case, this [uri] has the same value as the [plainTextUri].
  /// However, in some cases, linkified text may have a [plainTextUri] that isn't
  /// a valid [Uri]. This can happen when an app creates or loads documents from
  /// other sources - one wants to retain link attributions, even if they're invalid.
  final Uri? uri;

  /// Returns a best-guess version of this URI that an operating system can launch.
  ///
  /// In the nominal case, this value is the same as [uri] and [plainTextUri].
  ///
  /// When no [uri] is available, this property either returns [plainTextUri] as-is,
  /// or inserts a best-guess scheme.
  Uri get launchableUri {
    if (hasStructuredUri) {
      return uri!;
    }

    if (plainTextUri.contains("://")) {
      // It looks like the plain text URI has URL scheme. Return it as-is.
      return Uri.parse(plainTextUri);
    }

    if (plainTextUri.contains("@")) {
      // Our best guess is that this is a URL.
      return Uri.parse("mailto:$plainTextUri");
    }

    // Our best guess is that this is a web URL.
    return Uri.parse("https://$plainTextUri");
  }

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkAttribution && runtimeType == other.runtimeType && plainTextUri == other.plainTextUri;

  @override
  int get hashCode => plainTextUri.hashCode;

  @override
  String toString() {
    return '[LinkAttribution]: $plainTextUri${hasStructuredUri ? ' ($uri)' : ''}';
  }
}
