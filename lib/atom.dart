// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom;

import 'src/js.dart';

void registerPackage(AtomPackage package) {
  Map packageInfo = {
    'activate': package.activate,
    'deactivate': package.deactivate,
    'config': package.config(),
    'serialize': package.serialize
  };

  global[package.id] = packageInfo;
}

abstract class AtomPackage {
  final String id;

  AtomPackage(this.id);

  void activate([dynamic state]);
  Map config() => {};
  dynamic serialize() => {};
  void deactivate() { }
}
