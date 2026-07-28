// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/lsp_protocol/protocol.dart' hide Element;
import 'package:analysis_server/src/lsp/constants.dart';
import 'package:analysis_server/src/lsp/error_or.dart';
import 'package:analysis_server/src/lsp/handlers/handlers.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analyzer/instrumentation/service.dart';

class WorkspaceAnalysisCompleteHandler
    extends SharedMessageHandler<void, void> {
  new(super.server);

  @override
  Method get handlesMessage => CustomMethods.workspaceAnalysisComplete;

  InstrumentationService get instrumentationService =>
      server.instrumentationService;

  @override
  LspJsonHandler<void> get jsonHandler => nullJsonHandler;

  @override
  bool get requiresTrustedCaller => false;

  @override
  Future<ErrorOr<void>> handle(
    void params,
    MessageInfo message,
    CancellationToken token,
  ) async {
    // LSP Workspace Folder updates can trigger async work before the analysis
    // context rebuilds start.
    if (server case LspAnalysisServer server) {
      instrumentationService.logInfo(
        'analysis/complete: waiting for workspaceFolderUpdate',
      );
      await server.workspaceFolderUpdate;
    }

    // Wait for any in-progress analysis context builds. The driver scheduler
    // might appear idle while these are still in progress before work begins.
    instrumentationService.logInfo(
      'analysis/complete: waiting for analysisContextsRebuilt',
    );
    await server.analysisContextsRebuilt;

    // Wait for server to become idle.
    instrumentationService.logInfo('analysis/complete: waiting for idle');
    await server.analysisDriverScheduler.waitForIdle();

    // Wait for plugins to initialize (which happens either as they start
    // analyzing, or if the plugin manager knows there are not any plugins).
    instrumentationService.logInfo(
      'analysis/complete: waiting for pluginManager.initialized',
    );
    await server.pluginManager.initializedCompleter.future;

    // Now if plugins are analyzing, wait for them to complete.
    if (server.notificationManager.pluginStatusAnalyzing) {
      instrumentationService.logInfo(
        'analysis/complete: waiting for plugins to stop analyzing',
      );
      await server.notificationManager.pluginAnalysisStatusChanges.firstWhere(
        (isAnalyzing) => !isAnalyzing,
      );
    } else {
      instrumentationService.logInfo(
        'analysis/complete: plugins are not analyzing',
      );
    }

    instrumentationService.logInfo('analysis/complete: done!');

    return success(null);
  }
}
