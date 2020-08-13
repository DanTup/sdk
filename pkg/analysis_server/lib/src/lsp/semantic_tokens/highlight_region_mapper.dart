// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/src/lsp/constants.dart';
import 'package:analysis_server/src/lsp/semantic_tokens/collector.dart';
import 'package:analysis_server/src/lsp/semantic_tokens/legend.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';

final highlightRegionMapper = RegionTypeMapper();

/// A mapping from [HighlightRegionType] to a set of [SemanticTokenModifiers].
final highlightRegionTokenModifiers =
    <HighlightRegionType, Set<SemanticTokenModifiers>>{
  // HighlightRegionType.ANNOTATION: {SemanticTokenModifiers.???},
  // HighlightRegionType.BUILT_IN: {SemanticTokenModifiers.???},
  // HighlightRegionType.CLASS: {SemanticTokenModifiers.???},
  // HighlightRegionType.COMMENT_BLOCK: {SemanticTokenModifiers.???},
  HighlightRegionType.COMMENT_DOCUMENTATION: {
    SemanticTokenModifiers.documentation
  },
  // HighlightRegionType.COMMENT_END_OF_LINE: {SemanticTokenModifiers.???},
  // HighlightRegionType.CONSTRUCTOR: {SemanticTokenModifiers.???},
  // HighlightRegionType.DIRECTIVE: {SemanticTokenModifiers.???},
  HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.DYNAMIC_PARAMETER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.DYNAMIC_PARAMETER_REFERENCE: {SemanticTokenModifiers.???},
  // HighlightRegionType.ENUM: {SemanticTokenModifiers.???},
  // HighlightRegionType.ENUM_CONSTANT: {SemanticTokenModifiers.???},
  // HighlightRegionType.FUNCTION_TYPE_ALIAS: {SemanticTokenModifiers.???},
  // HighlightRegionType.IDENTIFIER_DEFAULT: {SemanticTokenModifiers.???},
  // HighlightRegionType.IMPORT_PREFIX: {SemanticTokenModifiers.???},
  HighlightRegionType.INSTANCE_FIELD_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.INSTANCE_FIELD_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.INSTANCE_GETTER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.INSTANCE_GETTER_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.INSTANCE_METHOD_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.INSTANCE_METHOD_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.INSTANCE_SETTER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.INSTANCE_SETTER_REFERENCE: {SemanticTokenModifiers.???},
  // HighlightRegionType.INVALID_STRING_ESCAPE: {SemanticTokenModifiers.???},
  // HighlightRegionType.KEYWORD: {SemanticTokenModifiers.???},
  // HighlightRegionType.LABEL: {SemanticTokenModifiers.???},
  // HighlightRegionType.LIBRARY_NAME: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_BOOLEAN: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_DOUBLE: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_INTEGER: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_LIST: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_MAP: {SemanticTokenModifiers.???},
  // HighlightRegionType.LITERAL_STRING: {SemanticTokenModifiers.???},
  HighlightRegionType.LOCAL_FUNCTION_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.LOCAL_FUNCTION_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.LOCAL_VARIABLE_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.LOCAL_VARIABLE_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.PARAMETER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.PARAMETER_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.STATIC_FIELD_DECLARATION: {
    SemanticTokenModifiers.declaration,
    SemanticTokenModifiers.static,
  },
  HighlightRegionType.STATIC_GETTER_DECLARATION: {
    SemanticTokenModifiers.declaration,
    SemanticTokenModifiers.static,
  },
  HighlightRegionType.STATIC_GETTER_REFERENCE: {SemanticTokenModifiers.static},
  HighlightRegionType.STATIC_METHOD_DECLARATION: {
    SemanticTokenModifiers.declaration,
    SemanticTokenModifiers.static,
  },
  HighlightRegionType.STATIC_METHOD_REFERENCE: {SemanticTokenModifiers.static},
  HighlightRegionType.STATIC_SETTER_DECLARATION: {
    SemanticTokenModifiers.declaration,
    SemanticTokenModifiers.static,
  },
  HighlightRegionType.STATIC_SETTER_REFERENCE: {SemanticTokenModifiers.static},
  HighlightRegionType.TOP_LEVEL_FUNCTION_DECLARATION: {
    SemanticTokenModifiers.declaration,
    SemanticTokenModifiers.static,
  },
  // HighlightRegionType.TOP_LEVEL_FUNCTION_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.TOP_LEVEL_GETTER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.TOP_LEVEL_GETTER_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.TOP_LEVEL_SETTER_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.TOP_LEVEL_SETTER_REFERENCE: {SemanticTokenModifiers.???},
  HighlightRegionType.TOP_LEVEL_VARIABLE_DECLARATION: {
    SemanticTokenModifiers.declaration
  },
  // HighlightRegionType.TYPE_NAME_DYNAMIC: {SemanticTokenModifiers.???},
  // HighlightRegionType.TYPE_PARAMETER: {SemanticTokenModifiers.???},
  // HighlightRegionType.UNRESOLVED_INSTANCE_MEMBER_REFERENCE: {SemanticTokenModifiers.???},
  // HighlightRegionType.VALID_STRING_ESCAPE: {SemanticTokenModifiers.???},
};

/// A mapping from [HighlightRegionType] to [SemanticTokenTypes].
final highlightRegionTokenTypes = {
  HighlightRegionType.ANNOTATION: CustomSemanticTokenTypes.annotation,
  HighlightRegionType.BUILT_IN: SemanticTokenTypes.keyword,
  HighlightRegionType.CLASS: SemanticTokenTypes.class_,
  HighlightRegionType.COMMENT_BLOCK: SemanticTokenTypes.comment,
  HighlightRegionType.COMMENT_DOCUMENTATION: SemanticTokenTypes.comment,
  HighlightRegionType.COMMENT_END_OF_LINE: SemanticTokenTypes.comment,
  HighlightRegionType.CONSTRUCTOR: SemanticTokenTypes.class_,
  // HighlightRegionType.DIRECTIVE: SemanticTokenTypes.???,
  HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_DECLARATION:
      SemanticTokenTypes.variable,
  HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_REFERENCE:
      SemanticTokenTypes.variable,
  HighlightRegionType.DYNAMIC_PARAMETER_DECLARATION:
      SemanticTokenTypes.parameter,
  HighlightRegionType.DYNAMIC_PARAMETER_REFERENCE: SemanticTokenTypes.parameter,
  HighlightRegionType.ENUM: SemanticTokenTypes.enum_,
  HighlightRegionType.ENUM_CONSTANT: SemanticTokenTypes.enumMember,
  HighlightRegionType.FUNCTION_TYPE_ALIAS: SemanticTokenTypes.type,
  // HighlightRegionType.IDENTIFIER_DEFAULT: SemanticTokenTypes.???,
  // HighlightRegionType.IMPORT_PREFIX: SemanticTokenTypes.???,
  HighlightRegionType.INSTANCE_FIELD_DECLARATION: SemanticTokenTypes.member,
  HighlightRegionType.INSTANCE_FIELD_REFERENCE: SemanticTokenTypes.member,
  HighlightRegionType.INSTANCE_GETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.INSTANCE_GETTER_REFERENCE: SemanticTokenTypes.property,
  HighlightRegionType.INSTANCE_METHOD_DECLARATION: SemanticTokenTypes.member,
  HighlightRegionType.INSTANCE_METHOD_REFERENCE: SemanticTokenTypes.member,
  HighlightRegionType.INSTANCE_SETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.INSTANCE_SETTER_REFERENCE: SemanticTokenTypes.property,
  // HighlightRegionType.INVALID_STRING_ESCAPE: SemanticTokenTypes.???,
  HighlightRegionType.KEYWORD: SemanticTokenTypes.keyword,
  // HighlightRegionType.LABEL: SemanticTokenTypes.???,
  HighlightRegionType.LIBRARY_NAME: SemanticTokenTypes.namespace,
  HighlightRegionType.LITERAL_BOOLEAN: CustomSemanticTokenTypes.boolean,
  HighlightRegionType.LITERAL_DOUBLE: SemanticTokenTypes.number,
  HighlightRegionType.LITERAL_INTEGER: SemanticTokenTypes.number,
  // HighlightRegionType.LITERAL_LIST: SemanticTokenTypes.???,
  // HighlightRegionType.LITERAL_MAP: SemanticTokenTypes.???,
  HighlightRegionType.LITERAL_STRING: SemanticTokenTypes.string,
  HighlightRegionType.LOCAL_FUNCTION_DECLARATION: SemanticTokenTypes.function,
  HighlightRegionType.LOCAL_FUNCTION_REFERENCE: SemanticTokenTypes.function,
  HighlightRegionType.LOCAL_VARIABLE_DECLARATION: SemanticTokenTypes.variable,
  HighlightRegionType.LOCAL_VARIABLE_REFERENCE: SemanticTokenTypes.variable,
  HighlightRegionType.PARAMETER_DECLARATION: SemanticTokenTypes.parameter,
  HighlightRegionType.PARAMETER_REFERENCE: SemanticTokenTypes.parameter,
  HighlightRegionType.STATIC_FIELD_DECLARATION: SemanticTokenTypes.member,
  HighlightRegionType.STATIC_GETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.STATIC_GETTER_REFERENCE: SemanticTokenTypes.property,
  HighlightRegionType.STATIC_METHOD_DECLARATION: SemanticTokenTypes.member,
  HighlightRegionType.STATIC_METHOD_REFERENCE: SemanticTokenTypes.member,
  HighlightRegionType.STATIC_SETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.STATIC_SETTER_REFERENCE: SemanticTokenTypes.property,
  HighlightRegionType.TOP_LEVEL_FUNCTION_DECLARATION:
      SemanticTokenTypes.function,
  HighlightRegionType.TOP_LEVEL_FUNCTION_REFERENCE: SemanticTokenTypes.function,
  HighlightRegionType.TOP_LEVEL_GETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.TOP_LEVEL_GETTER_REFERENCE: SemanticTokenTypes.property,
  HighlightRegionType.TOP_LEVEL_SETTER_DECLARATION: SemanticTokenTypes.property,
  HighlightRegionType.TOP_LEVEL_SETTER_REFERENCE: SemanticTokenTypes.property,
  HighlightRegionType.TOP_LEVEL_VARIABLE_DECLARATION:
      SemanticTokenTypes.variable,
  HighlightRegionType.TYPE_NAME_DYNAMIC: SemanticTokenTypes.type,
  HighlightRegionType.TYPE_PARAMETER: SemanticTokenTypes.typeParameter,
  HighlightRegionType.UNRESOLVED_INSTANCE_MEMBER_REFERENCE:
      SemanticTokenTypes.member,
  // HighlightRegionType.VALID_STRING_ESCAPE: SemanticTokenTypes.???,
};

/// A helper for converting from Server highlight regions to LSP semantic tokens.
class RegionTypeMapper {
  /// A map to get the [SemanticTokenTypes] index directly from a [HighlightRegionType].
  final Map<HighlightRegionType, int> _tokenTypeIndexForHighlightRegion = {};

  /// A map to get the [SemanticTokenModifiers] bitmask directly from a [HighlightRegionType].
  final Map<HighlightRegionType, int> _tokenModifierBitmaskForHighlightRegion =
      {};

  RegionTypeMapper() {
    // Build mappings that go directly from [HighlightRegionType] to index/bitmask
    // for faster lookups.
    for (final regionType in highlightRegionTokenTypes.keys) {
      _tokenTypeIndexForHighlightRegion[regionType] = semanticTokenLegend
          .indexForType(highlightRegionTokenTypes[regionType]);
    }

    for (final regionType in highlightRegionTokenTypes.keys) {
      _tokenModifierBitmaskForHighlightRegion[regionType] = semanticTokenLegend
          .bitmaskForModifiers(highlightRegionTokenModifiers[regionType]);
    }
  }

  /// Gets the [SemanticTokenModifiers] bitmask for a [HighlightRegionType]. Returns
  /// null if the region type has not been mapped.
  int bitmaskForModifier(HighlightRegionType type) =>
      _tokenModifierBitmaskForHighlightRegion[type];

  /// Gets the [SemanticTokenTypes] index for a [HighlightRegionType]. Returns
  /// null if the region type has not been mapped.
  int indexForToken(HighlightRegionType type) =>
      _tokenTypeIndexForHighlightRegion[type];
}

/// Converts [HighlightRegionType]s from original server protocol and plugins to
/// LSP SemanticTokens.
void collectSemanticTokensFromHighlights(SemanticTokenCollector collector,
    List<HighlightRegion> regions, LineInfo lineInfo, String fileContent) {
  // LSP is zero-based but server is 1-based.
  const lspPositionOffset = -1;

  // TODO(dantup): Switch to using clientCapability when this is supported by LSP.
  const clientSupportsMultilineTokens = false;
  const clientSupportsNestedTokens = false;

  Iterable<HighlightRegion> translatedRegions = regions;

  if (!clientSupportsMultilineTokens) {
    translatedRegions = translatedRegions.expand(
        (region) => _splitMultilineRegions(region, lineInfo, fileContent));
  }
  if (!clientSupportsNestedTokens) {
    translatedRegions = _splitNestedTokens(translatedRegions);
  }

  for (final region in translatedRegions) {
    final tokenType = highlightRegionTokenTypes[region.type];
    if (tokenType == null) {
      // Skip over tokens we don't have mappings for.
      continue;
    }

    final start = lineInfo.getLocation(region.offset);

    // TODO(dantup): handle overlapping tokens.

    collector.add(
      start.lineNumber + lspPositionOffset,
      start.columnNumber + lspPositionOffset,
      region.length,
      tokenType,
      highlightRegionTokenModifiers[region.type],
    );
  }
}

Iterable<HighlightRegion> _splitNestedTokens(
    Iterable<HighlightRegion> regions) sync* {
  if (regions.isEmpty) {
    return;
  }

  final sortedRegions = regions.toList()
    ..sort((r1, r2) => r1.offset.compareTo(r2.offset));

  final firstRegion = sortedRegions.first;
  final stack = ListQueue<HighlightRegion>()..add(firstRegion);
  var pos = firstRegion.offset;

  for (final current in sortedRegions.skip(1)) {
    if (stack.last != null) {
      final last = stack.last;
      final newPos = current.offset;
      if (newPos - pos > 0) {
        // The previous region ends at either its original end or
        // the position of this next region, whichever is shorter.
        final end = math.min(last.offset + last.length, newPos);
        final length = end - pos;
        yield HighlightRegion(last.type, pos, length);
        pos = newPos;
      }
    }

    stack.addLast(current);
  }

  // Process any remaining stack after the last region.
  while (stack.isNotEmpty) {
    final last = stack.removeLast();
    final newPos = last.offset + last.length;
    final length = newPos - pos;
    if (length > 0) {
      yield HighlightRegion(last.type, pos, length);
      pos = newPos;
    }
  }
}

/// Splits multiline regions into multiple regions for con
Iterable<HighlightRegion> _splitMultilineRegions(
    HighlightRegion region, LineInfo lineInfo, String fileContent) sync* {
  final start = lineInfo.getLocation(region.offset);
  final end = lineInfo.getLocation(region.offset + region.length);

  // Create a region for each line in the original region.
  for (var lineNumber = start.lineNumber;
      lineNumber <= end.lineNumber;
      lineNumber++) {
    final isFirstLine = lineNumber == start.lineNumber;
    final isLastLine = lineNumber == end.lineNumber;
    final isSingleLine = start.lineNumber == end.lineNumber;
    final lineOffset = lineInfo.getOffsetOfLine(lineNumber - 1);

    var startOffset = isFirstLine ? start.columnNumber - 1 : 0;
    var endOffset = isLastLine
        ? end.columnNumber - 1
        : lineInfo.getOffsetOfLine(lineNumber) - lineOffset;
    var length = endOffset - startOffset;

    // When we split multiline tokens, we may end up with leading/trailing
    // whitespace which doesn't make sense to include in the token. Examine
    // the content to remove this.
    if (!isSingleLine) {
      final tokenContent = fileContent.substring(
          lineOffset + startOffset, lineOffset + endOffset);
      final leadingWhitespaceCount =
          tokenContent.length - tokenContent.trimLeft().length;
      final trailingWhitespaceCount =
          tokenContent.length - tokenContent.trimRight().length;

      startOffset += leadingWhitespaceCount;
      endOffset -= trailingWhitespaceCount;
      length = endOffset - startOffset;
    }

    yield HighlightRegion(region.type, lineOffset + startOffset, length);
  }
}
