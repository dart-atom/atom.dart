// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import '../src/js.dart';
import 'node.dart';

final FS fs = new FS._();

class FS {
  final FS _fs;

  FS._() : _fs = require('fs');

  /// Relative path entries are removed and symlinks are resolved to their final
  /// destination.
  String realpathSync(String path) => _fs.realpathSync(path);

  Stats statSync(String path) => _fs.statSync(path);

  bool existsSync(String path) => _fs.existsSync(path);
}

@JsName()
abstract class Stats {
  bool isFile();
  bool isDirectory();

  // The last modified time (`2015-10-08 17:48:42.000`).
  String get mtime;
}
