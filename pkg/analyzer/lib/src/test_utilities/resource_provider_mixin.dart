// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';

/**
 * A mixin for test classes that adds a [ResourceProvider] and utility methods
 * for manipulating the file system. The utility methods all take a posix style
 * path and convert it as appropriate for the actual platform.
 */
class ResourceProviderMixin {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();

  void deleteFile(String path) {
    String convertedPath = resourceProvider.convertPath(path);
    resourceProvider.deleteFile(convertedPath);
  }

  void deleteFolder(String path) {
    String convertedPath = resourceProvider.convertPath(path);
    resourceProvider.deleteFolder(convertedPath);
  }

  File getFile(String path) {
    String convertedPath = resourceProvider.convertPath(path);
    return resourceProvider.getFile(convertedPath);
  }

  Folder getFolder(String path) {
    String convertedPath = resourceProvider.convertPath(path);
    return resourceProvider.getFolder(convertedPath);
  }

  void modifyFile(String path, String content) {
    String convertedPath = resourceProvider.convertPath(path);
    resourceProvider.modifyFile(convertedPath, content);
  }

  File newFile(String path, {String content = ''}) {
    String convertedPath = resourceProvider.convertPath(path);
    return resourceProvider.newFile(convertedPath, content);
  }

  File newFileWithBytes(String path, List<int> bytes) {
    String convertedPath = resourceProvider.convertPath(path);
    return resourceProvider.newFileWithBytes(convertedPath, bytes);
  }

  Folder newFolder(String path) {
    String convertedPath = resourceProvider.convertPath(path);
    return resourceProvider.newFolder(convertedPath);
  }

  String join(String part1,
          [String part2,
          String part3,
          String part4,
          String part5,
          String part6,
          String part7,
          String part8]) =>
      resourceProvider.pathContext
          .join(part1, part2, part3, part4, part5, part6, part7, part8);

  String convertPath(String path) => resourceProvider.convertPath(path);

  /// Convert the given [path] to be a valid import uri for this provider's path context.
  ///
  /// Paths on Windows are normally converted to C:\file.dart however it's not
  /// valid to use a path like that in an import in Dart, you must instead do
  /// `import "/C:/file.dart"`
  String convertPathForImport(String path) {
    path = resourceProvider.convertPath(path);
    // TODO(dantup): Is there a better way to check this is Windows and absolute?
    //     absolutePathContext has an _isAbsolute method that's private.
    // Should this be pushed down into the path context? Is there
    //     already code somewhere that can convert a Windows absolute path into one
    //     valid for import?
    if (resourceProvider.absolutePathContext.isValid(path) &&
        !path.startsWith("/")) {
      path = '/${path.replaceAll('\\', '/')}';
    }

    return path;
  }
}
