// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/lsp_protocol/protocol_special.dart';
import 'package:analysis_server/src/computer/computer_highlights2.dart';
import 'package:analysis_server/src/lsp/handlers/handlers.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analysis_server/src/lsp/mapping.dart';
import 'package:analysis_server/src/lsp/semantic_tokens/collector.dart';
import 'package:analysis_server/src/lsp/semantic_tokens/highlight_region_mapper.dart';
import 'package:analysis_server/src/plugin/result_merger.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';

// TODO(dantup): Consider supporting textDocument/semanticTokens/full/delta and
// textDocument/semanticTokens/range

class SemanticTokensHandler
    extends MessageHandler<SemanticTokensParams, SemanticTokens>
    with LspPluginRequestHandlerMixin {
  SemanticTokensHandler(LspAnalysisServer server) : super(server);

  @override
  Method get handlesMessage => Method.textDocument_semanticTokens_full;

  @override
  LspJsonHandler<SemanticTokensParams> get jsonHandler =>
      SemanticTokensParams.jsonHandler;

  List<List<HighlightRegion>> getPluginResults(String path) {
    final notificationManager = server.notificationManager;
    return notificationManager.highlights.getResults(path);
  }

  Future<List<HighlightRegion>> getServerResult(String path) async {
    final result = await server.getResolvedUnit(path);
    if (result?.state == ResultState.VALID) {
      // TODO(dantup): Switch to a more specific computer for LSP that can handle
      // nesting/multilines better for LSPs requirements.
      final computer = DartUnitHighlightsComputer2(result.unit);
      return computer.compute();
    }
    return [];
  }

  @override
  Future<ErrorOr<SemanticTokens>> handle(
      SemanticTokensParams params, CancellationToken token) async {
    final path = pathOfDoc(params.textDocument);

    return path.mapResult((path) async {
      final lineInfo = server.getLineInfo(path);
      // If there is no lineInfo, the request cannot be translated from LSP
      // line/col to server offset/length.
      if (lineInfo == null) {
        return success(null);
      }

      // LSP does not currently support multiline tokens (and when it does, it
      // will be client-dependent) so we need to be able to split multiline tokens
      // up. Doing this correctly requires access to the line endings and indenting
      // so we must take a copy of the file contents.
      // TODO(dantup): There could be a race here if the async computing below
      // runs after a file update.
      final fileContents =
          server.resourceProvider.getFile(path).readAsStringSync();

      final allResults = [
        await getServerResult(path),
        ...await getPluginResults(path),
      ];

      final merger = ResultMerger();
      final mergedResults = merger.mergeHighlightRegions(allResults);

      final collector = SemanticTokenCollector();
      collectSemanticTokensFromHighlights(
          collector, mergedResults, lineInfo, fileContents);

      final semanticTokens = collector.buildTokenData();
      return success(semanticTokens);
    });
  }
}
