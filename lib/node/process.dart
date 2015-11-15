// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node process APIs.
library node.process;

import 'node.dart';

final Process process = new Process._();

class Process {
  final dynamic _process;

  Process._() : _process = require('process');

  /// 'darwin', 'freebsd', 'linux', 'sunos' or 'win32'.
  String get platform => _process['platform'];

  String get chromeVersion => _process['versions']['chrome'];

  /// Get the value of an environment variable. This is often not accurate on the
  /// mac since mac apps are launched in a different shell then the terminal
  /// default.
  String env(String key) => _process['env'][key];
}
