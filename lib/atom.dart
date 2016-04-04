// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom;

import 'dart:async';
import 'dart:html' show CustomEvent, Element, HttpRequest;

import 'package:logging/logging.dart';

import 'node/config.dart';
import 'node/notification.dart';
import 'node/package.dart';
import 'node/workspace.dart';
import 'src/js.dart';
import 'utils/disposable.dart';

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

class CommandRegistry extends ProxyHolder {
  StreamController<String> _dispatchedController = new StreamController.broadcast();

  CommandRegistry(JsObject object) : super(object);

  Stream<String> get onDidDispatch => _dispatchedController.stream;

  /// Add one or more command listeners associated with a selector.
  ///
  /// [target] can be a String - a css selector - or an Html Element.
  Disposable add(dynamic target, String commandName, void callback(AtomEvent event)) {
    return new JsDisposable(invoke('add', target, commandName, (e) {
      _dispatchedController.add(commandName);
      callback(new AtomEvent(e));
    }));
  }

  /// Simulate the dispatch of a command on a DOM node.
  void dispatch(Element target, String commandName, {Map options}) =>
      invoke('dispatch', target, commandName, options);
}

class AtomEvent extends ProxyHolder {
  // With dart2js, this gets passed in as a JsObject (most times?). With DDC,
  // it's passed in as a CustomEvent.
  factory AtomEvent(dynamic object) {
    if (object is JsObject) {
      return new AtomEvent._fromJsObject(object);
    } else {
      return new _AtomEventCustomEvent(object);
    }
  }

  AtomEvent._fromJsObject(JsObject object) : super(_cvt(object));

  dynamic get currentTarget => obj['currentTarget'];

  // /// Return the editor that is the target of this event. Note, this is _only_
  // /// available if an editor is the target of an event; calling this otherwise
  // /// will return an invalid [TextEditor].
  // TextEditor get editor {
  //   TextEditorView view = new TextEditorView(currentTarget);
  //   return view.getModel();
  // }

  // /// Return the currently selected file path. This call will only be meaningful
  // /// if the event target is the Tree View.
  // String get targetFilePath {
  //   try {
  //     var target = obj['target'];
  //
  //     // Target is an Element or a JsObject. JS interop is a mess.
  //     if (target is Element) {
  //       if (target.getAttribute('data-path') != null) {
  //         return target.getAttribute('data-path');
  //       }
  //       if (target.children.isEmpty) return null;
  //       Element child = target.children.first;
  //       return child.getAttribute('data-path');
  //     } else if (target is JsObject) {
  //       JsObject obj = target.callMethod('querySelector', ['span']);
  //       if (obj == null) return null;
  //       obj = new JsObject.fromBrowserObject(obj);
  //       return obj.callMethod('getAttribute', ['data-path']);
  //     } else {
  //       return null;
  //     }
  //   } catch (e, st) {
  //     _logger.info('exception while handling context menu', e, st);
  //     return null;
  //   }
  // }

  void abortKeyBinding() => invoke('abortKeyBinding');

  bool get keyBindingAborted => obj['keyBindingAborted'];

  void preventDefault() => invoke('preventDefault');

  bool get defaultPrevented => obj['defaultPrevented'];

  void stopPropagation() => invoke('stopPropagation');
  void stopImmediatePropagation() => invoke('stopImmediatePropagation');

  bool get propagationStopped => obj['propagationStopped'];
}

/// An AtomEvent that wraps a CustomEvent.
class _AtomEventCustomEvent implements AtomEvent {
  final CustomEvent event;

  _AtomEventCustomEvent(this.event);

  void abortKeyBinding() => (event as dynamic).abortKeyBinding();

  dynamic get currentTarget => event.currentTarget;

  bool get defaultPrevented => event.defaultPrevented;

  Stream eventStream(String eventName) {
    throw 'unimplemented';
  }

  invoke(String method, [arg1, arg2, arg3]) {
    throw 'unimplemented';
  }

  bool get keyBindingAborted => (event as dynamic).keyBindingAborted;

  JsObject get obj {
    throw 'unimplemented';
  }

  void preventDefault() => event.preventDefault();

  bool get propagationStopped => (event as dynamic).propagationStopped;

  void stopImmediatePropagation() => event.stopImmediatePropagation();

  void stopPropagation() => event.stopPropagation();
}

JsObject _cvt(JsObject object) {
  if (object == null) return null;
  if (object is JsObject) return object;

  // We really shouldn't have to be wrapping objects we've already gotten from
  // JS interop.
  return new JsObject.fromBrowserObject(object);
}
