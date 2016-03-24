// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom_utils;

import 'dart:async';
import 'dart:html' show CustomEvent, DivElement, Element, HttpRequest, Node, NodeTreeSanitizer;

import 'package:atom/node/process.dart';
import 'package:logging/logging.dart';

// TODO(danrubel) remove this once references have been updated
export 'node/notification.dart' show promptUser;

final Logger _logger = new Logger('atom_utils');

class TrustedHtmlTreeSanitizer implements NodeTreeSanitizer {
  const TrustedHtmlTreeSanitizer();
  void sanitizeTree(Node node) { }
}

MacShellWrangler _shellWrangler;

/// Look for the given executable; throw an error if we can't find it.
///
/// Note: on Windows, this assumes that we're looking for an `.exe` unless
/// `isBatchScript` is specified.
Future<String> which(String execName, {bool isBatchScript: false}) {
  if (isMac) {
    if (_shellWrangler == null) _shellWrangler = new MacShellWrangler();

    return exec('which', [execName], _shellWrangler.env).then((String result) {
      result = result.trim();
      if (result.contains('\n')) result = result.split('\n').first;
      return result;
    }) as Future<String>;
  } else if (isWindows) {
    String ext = isBatchScript ? 'bat' : 'exe';
    return exec('where', ['${execName}.${ext}']).then((String result) {
      result = result.trim();
      if (result.contains('\n')) result = result.split('\n').first;
      return result;
    }) as Future<String>;
  } else {
    return exec('which', [execName]).then((String result) {
      result = result.trim();
      if (result.contains('\n')) result = result.split('\n').first;
      return result;
    }) as Future<String>;
  }
}
