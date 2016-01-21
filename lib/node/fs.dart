// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node fs APIs.
library node.fs;

import '../src/js.dart';
import 'node.dart';
import 'process.dart';

final FS fs = new FS._();

class FS extends ProxyHolder {
  FS._() : super(require('fs'));

  final String separator = isWindows ? r'\' : '/';

  String join(dir, String arg1, [String arg2, String arg3]) {
    //if (dir is Directory) dir = dir.path;
    String path = '${dir}${separator}${arg1}';
    if (arg2 != null) {
      path = '${path}${separator}${arg2}';
      if (arg3 != null) path = '${path}${separator}${arg3}';
    }
    return path;
  }

  /// Relative path entries are removed and symlinks are resolved to their final
  /// destination.
  String realpathSync(String path) => invoke('realpathSync', path);

  Stats statSync(String path) => new Stats._(invoke('statSync', path));

  bool existsSync(String path) => invoke('existsSync', path);
}

class Stats extends ProxyHolder {
  Stats._(JsObject obj) : super(obj);

  bool isFile() => invoke('isFile');
  bool isDirectory() => invoke('isDirectory');

  // The last modified time (`2015-10-08 17:48:42.000`).
  String get mtime => obj['mtime'];
}
