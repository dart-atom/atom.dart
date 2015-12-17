// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node fs APIs.
library node.fs;

import '../src/js.dart';
import 'node.dart';

final FS fs = new FS._();

class FS extends ProxyHolder {
  FS._() : super(require('fs'));

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
