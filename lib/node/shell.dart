// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node shell APIs (https://github.com/nwjs/nw.js/wiki/Shell).
library node.shell;

import '../src/js.dart';
import 'node.dart';

final Shell shell = new Shell._();

class Shell extends ProxyHolder {
  Shell._() : super(require('shell'));

  /// Open the given path in the desktop's default manner.
  openItem(String path) => invoke('openItem', path);

  /// Show the given path in a file manager. If possible, select the file.
  showItemInFolder(String path) => invoke('showItemInFolder', path);

  /// Open the given external protocol URI in the desktop's default manner. (For
  /// example, mailto: URLs in the default mail user agent.)
  openExternal(String url) => invoke('openExternal', url);
}
