// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'node.dart';

final OS os = new OS._();

class OS {
  OS._();

  String tmpdir(String path) => require('os').tmpdir(path);
}
