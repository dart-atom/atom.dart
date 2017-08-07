// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Utiliy methods for use when compiling Atom plugins written in Dart.
library atom.build;

final String _jsPrefix = """
var self = Object.create(this);
self.require = require;
self.module = module;
self.window = window;
self.atom = atom;
self.exports = exports;
self.Object = Object;
self.Promise = Promise;
self.setTimeout = function(f, millis) { return window.setTimeout(f, millis); };
self.clearTimeout = function(id) { window.clearTimeout(id); };
self.setInterval = function(f, millis) { return window.setInterval(f, millis); };
self.clearInterval = function(id) { window.clearInterval(id); };

// Work around interop issues.
self.getTextEditorForElement = function(element) { return element.getModel(); };

self._domHoist = function(element, targetQuery) {
  var target = document.querySelector(targetQuery);
  target.appendChild(element);
};

self._domRemove = function(element) {
  element.parentNode.removeChild(element);
};
""";

/// The dart2js generated code is not expecting the Atom runtime
/// because it's neither vanilla Chrome, nor a web-worker.
/// This patches the generated JS to
/// * get basic things like futures and streams to work
/// * work around JS interop issues where we really can't access JS custom elements well
String patchDart2JSOutput(String input) {
  final String from_1 = 'if (document.currentScript) {';
  final String from_2 = "if (typeof document.currentScript != 'undefined') {";
  final String to = 'if (true) {';

  int index = input.lastIndexOf(from_1);
  if (index != -1) {
    input =
        input.substring(0, index) + to + input.substring(index + from_1.length);
  } else {
    index = input.lastIndexOf(from_2);
    input =
        input.substring(0, index) + to + input.substring(index + from_2.length);
  }
  if (index == -1) throw 'failed to patch JS';

  return _jsPrefix + input;
}
