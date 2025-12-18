// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analyzer/src/dart/analysis/status.dart';

/// Invalidates client state (such as Semantic Tokens) when the server detects
/// that the client may have stale data.
///
/// For example, if file A is modified and causes resolution/analysis of file B,
/// the client needs to be notified to re-request pulled state for file B
/// (unless file B has also been modified).
class ClientStateInvalidator {
  final LspAnalysisServer server;

  /// Files that are open and have been modified by the client since the last
  /// analysis completion.
  final Set<String> _openModifiedFiles = {};

  /// Files that are open and have been resolved during the current analysis.
  final Set<String> _openResolvedFiles = {};

  ClientStateInvalidator(this.server);

  void didChange(String path) {
    // Modified files are always open.
    _openModifiedFiles.add(path);
  }

  void didClose(String path) {
    _openModifiedFiles.remove(path);
    _openResolvedFiles.remove(path);
  }

  void didOpen(String path) {
    // Opened files can be treated as modified even if they didn't actually
    // change the state, because the client will not have any state for them
    // yet.
    _openModifiedFiles.add(path);
  }

  void didResolve(String path) {
    if (isOpen(path)) {
      server.instrumentationService.logInfo('$path was resolved!');
      _openResolvedFiles.add(path);
    }
  }

  bool isOpen(String path) => server.priorityFiles.contains(path);

  void onAnalysisStatusChange(AnalysisStatus status) {
    if (status.isWorking) return;

    var resolvedButNotModified = _openResolvedFiles.difference(
      _openModifiedFiles,
    );

    // If no files were modified, this is initial analysis and there's nothing
    // to invalidate, so require open modified files and resolved (but not
    // modified) files to trigger refresh.
    if (_openModifiedFiles.isNotEmpty && resolvedButNotModified.isNotEmpty) {
      // TODO(dantup): Sending this refresh will also invalidate the "current"
      //  file, since it invalidates all.
      //
      // This means, if you have two files open, but only one is visible (but
      // the hidden tab depends on it), then every modification:
      // - triggers textDocument/didChange
      // - triggers semantic tokens
      // - (server sends refresh because there's an open - albeit hidden - file)
      // - client now triggers semantic tokens again for the active file
      //
      // This means that in the common case of a single visible file, but other
      // open files and one of them depends on the active file, we will double
      // all semantic token requests.

      server.sendLspRequest(Method.workspace_semanticTokens_refresh, null);
      server.sendLspRequest(Method.workspace_codeLens_refresh, null);
      server.sendLspRequest(Method.workspace_inlayHint_refresh, null);
      server.sendLspRequest(Method.workspace_inlineValue_refresh, null);
    }

    // Clear sets for next round of analysis.
    _openModifiedFiles.clear();
    _openResolvedFiles.clear();
    server.instrumentationService.logInfo('cleared!');
  }
}
