// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node OS APIs.
library node.os;

import '../src/js.dart';
import 'node.dart';

final OS os = new OS._();

class OS extends ProxyHolder {
  OS._() : super(require('os'));

  String tmpdir(String path) => invoke('tmpdir', path);
}
