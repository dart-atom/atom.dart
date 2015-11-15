// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

class JsName {
  /// The JavaScript name - used for classes and libraries. Note that this could
  /// be an expression, e.g. `lib.TypeName` in JS, but it should be kept simple,
  /// as it will be generated directly into the code.
  final String name;

  const JsName([this.name]);
}

@JsName()
external get global;
