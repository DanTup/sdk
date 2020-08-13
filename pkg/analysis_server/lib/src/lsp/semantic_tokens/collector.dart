import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/src/lsp/semantic_tokens/legend.dart';

/// Collects information about Semantic Tokens using absolute line/columns and
/// token types/modifiers to produce a [SemanticTokens] using LSP-specific
/// encoding into a [List<int>].
///
/// It is the callers responsibility to ensure that tokens are not nested or
/// multiline unless the client capabilities allow this.
class SemanticTokenCollector {
  final _tokens = <_SemanticTokenInfo>[];

  void add(int line, int column, int length, SemanticTokenTypes type,
      Set<SemanticTokenModifiers> modifiers) {
    _tokens.add(_SemanticTokenInfo(line, column, length, type, modifiers));
  }

  SemanticTokens buildTokenData() {
    final encodedTokens = <int>[];
    var lastLine = 0;
    var lastColumn = 0;

    // Ensure tokens are all sorted by location in file regardless of the order
    // they were registered.
    _tokens.sort(_SemanticTokenInfo.offsetSort);

    for (final token in _tokens) {
      var relativeLine = token.line - lastLine;
      // Column is relative to last only if on the same line.
      var relativeColumn =
          relativeLine == 0 ? token.column - lastColumn : token.column;

      // The resulting array is groups of 5 items as described in the LSP spec:
      // https://github.com/microsoft/language-server-protocol/blob/e8409ea937519f263a21b907bae1fcad8e4885e7/_specifications/specification-3-16.md#textDocument_semanticTokens
      encodedTokens.addAll([
        relativeLine,
        relativeColumn,
        token.length,
        semanticTokenLegend.indexForType(token.type),
        semanticTokenLegend.bitmaskForModifiers(token.modifiers) ?? 0
      ]);

      lastLine = token.line;
      lastColumn = token.column;
    }

    return SemanticTokens(data: encodedTokens);
  }
}

class _SemanticTokenInfo {
  final int line;
  final int column;
  final int length;
  final SemanticTokenTypes type;
  final Set<SemanticTokenModifiers> modifiers;

  _SemanticTokenInfo(
      this.line, this.column, this.length, this.type, this.modifiers);

  static int offsetSort(t1, t2) => t1.line == t2.line
      ? t1.column.compareTo(t2.column)
      : t1.line.compareTo(t2.line);
}
