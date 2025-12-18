// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/lsp_protocol/protocol.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'server_abstract.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RefreshTest);
  });
}

@reflectiveTest
class RefreshTest extends AbstractLspAnalysisServerTest {
  static const baseFileContent = 'class Base {}';

  static const unrelatedFileContent = 'class Unrelated {}';

  static const derivedFileContent = '''
import 'base.dart';
class Derived extends Base {}
''';

  /// Content that can be appended to a file to trigger analysis.
  static const appendedContent = '''
var a = 1;
''';

  late var baseFilePath = join(projectFolderPath, 'lib', 'base.dart');
  late var derivedFilePath = join(projectFolderPath, 'lib', 'derived.dart');
  late var unrelatedFilePath = join(projectFolderPath, 'lib', 'unrelated.dart');

  late var baseFileUri = Uri.file(baseFilePath);
  late var derivedFileUri = Uri.file(derivedFilePath);
  late var unrelatedFileUri = Uri.file(unrelatedFilePath);

  Future<List<Method>> captureRefreshes(Future<void> Function() func) async {
    var refreshes = <Method>[];
    var subscription = serverToClient.listen((message) {
      if (message is RequestMessage &&
          message.method.toString().endsWith('/refresh')) {
        refreshes.add(message.method);
      }
    });

    await func();
    await currentAnalysis;
    await subscription.cancel();

    return refreshes;
  }

  @override
  void setUp() {
    super.setUp();

    newFile(baseFilePath, baseFileContent);
    newFile(derivedFilePath, derivedFileContent);
    newFile(unrelatedFilePath, unrelatedFileContent);
  }

  Future<void> test_noRefresh_onlyResolvedFileIsModified() async {
    await initialize();
    await openFile(unrelatedFileUri, unrelatedFileContent);
    await currentAnalysis;

    // Modify a solo open file. Only it will be resolved, so no refresh is
    // needed.
    var refreshes = await captureRefreshes(
      () => replaceFile(
        2,
        unrelatedFileUri,
        unrelatedFileContent + appendedContent,
      ),
    );
    expect(refreshes, isEmpty);
  }

  Future<void> test_noRefresh_resolvedRelatedFileIsAlsoModified() async {
    await initialize();
    await openFile(baseFileUri, baseFileContent);
    await openFile(derivedFileUri, derivedFileContent);
    await currentAnalysis;

    // Modify both files synchronously. They should both be analyzed in the same
    // pass, so no refresh is required.
    var refreshes = await captureRefreshes(
      () => Future.wait([
        replaceFile(2, baseFileUri, baseFileContent + appendedContent),
        replaceFile(2, derivedFileUri, derivedFileContent + appendedContent),
      ]),
    );
    expect(refreshes, isEmpty);
  }

  Future<void> test_noRefresh_resolvedRelatedFileIsNotOpen() async {
    await initialize();
    await openFile(baseFileUri, baseFileContent);
    await currentAnalysis;

    // Modify the base file. The derived file is not open, so it won't need
    // refreshing.
    var refreshes = await captureRefreshes(
      () => replaceFile(2, baseFileUri, baseFileContent + appendedContent),
    );
    expect(refreshes, isEmpty);
  }

  Future<void> test_refresh_resolvedFileIsOpenAndUnmodified() async {
    await initialize();
    await openFile(baseFileUri, baseFileContent);
    await openFile(derivedFileUri, derivedFileContent);
    await currentAnalysis;

    // Modify the base file, which will re-resolve the derived file which is
    // open but was not modified, so needs refreshing.
    var refreshes = await captureRefreshes(
      () => replaceFile(2, baseFileUri, baseFileContent + appendedContent),
    );

    expect(
      refreshes,
      unorderedEquals([
        Method.workspace_semanticTokens_refresh,
        Method.workspace_codeLens_refresh,
        Method.workspace_inlayHint_refresh,
        Method.workspace_inlineValue_refresh,
      ]),
    );
  }
}
