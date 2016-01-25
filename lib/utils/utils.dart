// Copyright (c) 2016, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// TODO: This is a workaround for the fact that typed arrays are not yet supported
// by DDC.
String uriEncodeComponent(String str) {
  // TODO: improve this

  return str.replaceAll(' ', '%20');

  // return Uri.encodeComponent(component);
}
