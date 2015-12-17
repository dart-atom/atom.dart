// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node process APIs.
library node.process;

import '../src/js.dart';
import 'node.dart';

final Process process = new Process._();

class Process extends ProxyHolder {
  Process._() : super(require('process'));

  /// 'darwin', 'freebsd', 'linux', 'sunos' or 'win32'.
  String get platform => obj['platform'];

  String get chromeVersion => obj['versions']['chrome'];

  /// Get the value of an environment variable. This is often not accurate on
  /// the mac since mac apps are launched in a different shell then the terminal
  /// default.
  String env(String key) => obj['env'][key];
}
