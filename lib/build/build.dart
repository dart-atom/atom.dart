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
self.getTextEditorForElement = function(element) { return element.o.getModel(); };
self.uncrackDart2js = function(obj) { return obj.o; };

self._domHoist = function(element, targetQuery) {
  var target = document.querySelector(targetQuery);
  target.appendChild(element);
};

self._domRemove = function(element) {
  element.parentNode.removeChild(element);
};
""";

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
  return _jsPrefix + input;
}
