// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom;

import 'dart:async';

import 'package:logging/logging.dart';

import 'node/command.dart';
import 'node/config.dart';
import 'node/notification.dart';
import 'node/package.dart';
import 'node/workspace.dart';
import 'src/js.dart';

final Logger _logger = new Logger('atom');

/// The singleton instance of [Atom].
final Atom atom = new Atom();

class Atom extends ProxyHolder {
  CommandRegistry _commands;
  Config _config;
  // ContextMenuManager _contextMenu;
  GrammarRegistry _grammars;
  NotificationManager _notifications;
  PackageManager _packages;
  Project _project;
  ViewRegistry _views;
  Workspace _workspace;

  Atom() : super(context['atom']) {
    _commands = new CommandRegistry(obj['commands']);
    _config = new Config(obj['config']);
    // _contextMenu = new ContextMenuManager(obj['contextMenu']);
    _grammars = new GrammarRegistry(obj['grammars']);
    _notifications = new NotificationManager(obj['notifications']);
    _packages = new PackageManager(obj['packages']);
    _project = new Project(obj['project']);
    _views = new ViewRegistry(obj['views']);
    _workspace = new Workspace(obj['workspace']);
  }

  CommandRegistry get commands => _commands;
  Config get config => _config;
  // ContextMenuManager get contextMenu => _contextMenu;
  GrammarRegistry get grammars => _grammars;
  NotificationManager get notifications => _notifications;
  PackageManager get packages => _packages;
  Project get project => _project;
  ViewRegistry get views => _views;
  Workspace get workspace => _workspace;

  String getVersion() => invoke('getVersion');

  void beep() => invoke('beep');

  /// A flexible way to open a dialog akin to an alert dialog.
  ///
  /// Returns the chosen button index Number if the buttons option was an array.
  int confirm(String message, {String detailedMessage, List<String> buttons}) {
    Map m = {'message': message};
    if (detailedMessage != null) m['detailedMessage'] = detailedMessage;
    if (buttons != null) m['buttons'] = buttons;
    return invoke('confirm', m);
  }

  /// Reload the current window.
  void reload() => invoke('reload');

  /// Prompt the user to select one or more folders.
  Future<String> pickFolder() {
    Completer<String> completer = new Completer();
    invoke('pickFolder', (result) {
      if (result is List && result.isNotEmpty) {
        completer.complete(result.first);
      } else {
        completer.complete(null);
      }
    });
    return completer.future;
  }
}
