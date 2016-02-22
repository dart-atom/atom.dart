// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom_utils;

import 'dart:async';
import 'dart:html' show CustomEvent, DivElement, Element, HttpRequest, Node, NodeTreeSanitizer;

import 'package:logging/logging.dart';

import 'atom.dart';
import 'src/js.dart';
import 'utils/disposable.dart';

final Logger _logger = new Logger('atom_utils');

/// Display a textual prompt to the user.
Future<String> promptUser(String prompt,
    {String defaultText, bool selectText: false, bool selectLastWord: false}) {
  if (defaultText == null) defaultText = '';

  // div, atom-text-editor.editor.mini div.message atom-text-editor[mini]
  Completer<String> completer = new Completer();
  Disposables disposables = new Disposables();

  Element element = new DivElement();
  element.setInnerHtml('''
    <label>${prompt}</label>
    <atom-text-editor mini>${defaultText}</atom-text-editor>
''',
      treeSanitizer: new TrustedHtmlTreeSanitizer());

  Element editorElement = element.querySelector('atom-text-editor');
  JsFunction editorConverter = context['getTextEditorForElement'];
  TextEditor editor = new TextEditor(editorConverter.apply([editorElement]));
  if (selectText) {
    editor.selectAll();
  } else if (selectLastWord) {
    editor.moveToEndOfLine();
    editor.selectToBeginningOfWord();
  }

  // Focus the element.
  Timer.run(() {
    try { editorElement.focus(); }
    catch (e) { _logger.warning(e); }
  });

  disposables.add(atom.commands.add('atom-workspace', 'core:confirm', (_) {
    if (!completer.isCompleted) completer.complete(editor.getText());
  }));

  disposables.add(atom.commands.add('atom-workspace', 'core:cancel', (_) {
    if (!completer.isCompleted) completer.complete(null);
  }));

  Panel panel = atom.workspace.addModalPanel(item: element, visible: true);

  completer.future.whenComplete(() {
    disposables.dispose();
    panel.destroy();
  });

  return completer.future;
}

class TrustedHtmlTreeSanitizer implements NodeTreeSanitizer {
  const TrustedHtmlTreeSanitizer();
  void sanitizeTree(Node node) { }
}
