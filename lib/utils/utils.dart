// Copyright (c) 2016, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// This is a workaround for the fact that typed arrays are not yet supported
// by DDC (https://github.com/dart-lang/dev_compiler/issues/413).
String uriEncodeComponent(String str) {
  return str.replaceAll(' ', '%20');
}
