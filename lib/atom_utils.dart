// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom_utils;

import 'dart:async';
import 'dart:html' show Node, NodeTreeSanitizer;

import 'package:atom/node/process.dart';
import 'package:logging/logging.dart';

final Logger _logger = new Logger('atom_utils');

class TrustedHtmlTreeSanitizer implements NodeTreeSanitizer {
  const TrustedHtmlTreeSanitizer();
  void sanitizeTree(Node node) { }
}

ShellWrangler _shellWrangler;

/// Look for the given executable; throw an error if we can't find it.
///
/// Note: on Windows, this assumes that we're looking for an `.exe` unless
/// `isBatchScript` is specified.
Future<String> which(String execName, {bool isBatchScript: false}) {
  if (isWindows) {
    String ext = isBatchScript ? 'bat' : 'exe';
    return exec('where', ['${execName}.${ext}']).then((String result) {
      result = result.trim();
      if (result.contains('\n')) result = result.split('\n').first;
      return result;
    });
  } else {
    // posix - linux and mac
    if (_shellWrangler == null) _shellWrangler = new ShellWrangler();

    return exec('which', [execName], _shellWrangler.env).then((String result) {
      result = result.trim();
      if (result.contains('\n')) result = result.split('\n').first;
      return result;
    });
  }
}
