// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' show CustomEvent, Element, HttpRequest;

import 'package:logging/logging.dart';

import '../src/js.dart';
import '../utils/disposable.dart';
import 'workspace.dart';

final Logger _logger = new Logger('command');

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

/// Provides a registry for commands that you'd like to appear in the context
/// menu.
class ContextMenuManager extends ProxyHolder {
  ContextMenuManager(JsObject obj) : super(obj);

  /// Add context menu items scoped by CSS selectors.
  Disposable add(String selector, List<ContextMenuItem> items) {
    Map m = {selector: items.map((item) => item.toJs()).toList()};
    return new JsDisposable(invoke('add', m));
  }
}

abstract class ContextMenuItem {
  static final ContextMenuItem separator = new _SeparatorMenuItem();

  final String label;
  final String command;

  ContextMenuItem(this.label, this.command);

  bool shouldDisplay(AtomEvent event);

  JsObject toJs() {
    Map m = {
      'label': label,
      'command': command,
      'shouldDisplay': (e) => shouldDisplay(new AtomEvent(e))
    };
    return jsify(m);
  }
}

abstract class ContextMenuContributor {
  List<ContextMenuItem> getTreeViewContributions();
}

class _SeparatorMenuItem extends ContextMenuItem {
  _SeparatorMenuItem() : super('', '');
  bool shouldDisplay(AtomEvent event) => true;
  JsObject toJs() => jsify({'type': 'separator'});
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

  /// Return the editor that is the target of this event. Note, this is _only_
  /// available if an editor is the target of an event; calling this otherwise
  /// will return an invalid [TextEditor].
  TextEditor get editor {
    TextEditorElement view = new TextEditorElement(currentTarget);
    return view.getModel();
  }

  // /// Return the currently selected file item. This call will only be meaningful
  // /// if the event target is the Tree View.
  // Element get selectedFileItem {
  //   Element element = currentTarget;
  //   return element.querySelector('li[is=tree-view-file].selected span.name');
  // }
  //
  // /// Return the currently selected file path. This call will only be meaningful
  // /// if the event target is the Tree View.
  // String get selectedFilePath {
  //   Element element = selectedFileItem;
  //   return element == null ? null : element.getAttribute('data-path');
  // }

  /// Return the currently selected file path. This call will only be meaningful
  /// if the event target is the Tree View.
  String get targetFilePath {
    try {
      var target = obj['target'];

      // Target is an Element or a JsObject. JS interop is a mess.
      if (target is Element) {
        if (target.getAttribute('data-path') != null) {
          return target.getAttribute('data-path');
        }
        if (target.children.isEmpty) return null;
        Element child = target.children.first;
        return child.getAttribute('data-path');
      } else if (target is JsObject) {
        JsObject obj = target.callMethod('querySelector', ['span']);
        if (obj == null) return null;
        obj = new JsObject.fromBrowserObject(obj);
        return obj.callMethod('getAttribute', ['data-path']);
      } else {
        return null;
      }
    } catch (e, st) {
      _logger.info('exception while handling context menu', e, st);
      return null;
    }
  }

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

  TextEditor get editor {
    throw 'unimplemented';
  }

  String get targetFilePath {
    throw 'unimplemented';
  }

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
