// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' show CustomEvent, Element, HttpRequest;

import 'package:logging/logging.dart';

import 'node/notification.dart';
import 'src/js.dart';
import 'src/utils.dart';
import 'utils/disposable.dart';

// TODO(danrubel) remove this once all references have been cleaned up.
export 'node/process.dart' show BufferedProcess;

final Logger _logger = new Logger('atom');

/// The singleton instance of [Atom].
final Atom atom = new Atom();

AtomPackage _package;

/// Call this method once from the main method of your package.
///
///     main() => registerPackage(new MyFooPackage());
void registerPackage(AtomPackage package) {
  if (_package != null) {
    throw new StateError('can only register one package');
  }

  _package = package;

  final JsObject exports = context['module']['exports'];

  exports['activate'] = ([state]) {
    try {
      _package.activate(state);
    } catch (e, st) {
      print('${e}');
      print('${st}');
    }
  };
  exports['deactivate'] = () {
    try {
      _package.deactivate();
    } catch (e, st) {
      print('${e}');
      print('${st}');
    }
  };
  exports['config'] = jsify(_package.config());
  exports['serialize'] = _package.serialize;

  package._registeredMethods.forEach((methodName, f) {
    exports[methodName] = (arg) {
      var result = f(arg);
      if (result is Disposable) {
        // Convert the returned Disposable to a JS object.
        Map m = {'dispose': result.dispose};
        return jsify(m);
      } else if (result is List || result is Map) {
        return jsify(result);
      } else if (result is JsObject) {
        return result;
      } else {
        return null;
      }
    };
  });
  package._registeredMethods = null;
}

void registerPackageDDC(AtomPackage package) {
  Map packageInfo = {
    'activate': ([state]) {
      try {
        package.activate(state);
      } catch (e, st) {
        print('${e}');
        print('${st}');
      }
    },
    'deactivate': () {
      try {
        package.deactivate();
      } catch (e, st) {
        print('${e}');
        print('${st}');
      }
    },
    'config': package.config(),
    'serialize': package.serialize
  };

  context[package.id] = jsify(packageInfo);
}

abstract class AtomPackage {
  Map<String, Function> _registeredMethods = {};

  final String id;

  AtomPackage(this.id);

  void activate([dynamic state]);
  Map config() => {};
  dynamic serialize() => {};
  void deactivate() { }

  Future<Map<String, dynamic>> loadPackageJson() {
    return HttpRequest.getString('atom://${id}/package.json').then((String str) {
      return JSON.decode(str) as Map<String, dynamic>;
    }) as Future<Map<String, dynamic>>;
  }

  Future<String> getPackageVersion() {
    return loadPackageJson().then((Map map) => map['version']) as Future<String>;
  }

  // /// Register a method for a service callback (`consumedServices`).
  // void registerServiceConsumer(String methodName, Disposable callback(JsObject obj)) {
  //   if (_registeredMethods == null) {
  //     throw new StateError('method must be registered in the package ctor');
  //   }
  //   _registeredMethods[methodName] = callback;
  //   return null;
  // }
  //
  // void registerServiceProvider(String methodName, JsObject callback()) {
  //   if (_registeredMethods == null) {
  //     throw new StateError('method must be registered in the package ctor');
  //   }
  //   _registeredMethods[methodName] = callback;
  //   return null;
  // }
}

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

class Config extends ProxyHolder {
  Config(JsObject object) : super(object);

  /// [keyPath] should be in the form `pluginid.keyid` - e.g. `${pluginId}.sdkLocation`.
  dynamic getValue(String keyPath, {scope}) {
    Map options;
    if (scope != null) options = {'scope': scope};
    return invoke('get', keyPath, options);
  }

  bool getBoolValue(String keyPath, {scope}) =>
      getValue(keyPath, scope: scope) == true;

  void setValue(String keyPath, dynamic value) => invoke('set', keyPath, value);

  /// Add a listener for changes to a given key path. This will immediately call
  /// your callback with the current value of the config entry.
  Disposable observe(String keyPath, Map options, void callback(value)) {
    if (options == null) options = {};
    return new JsDisposable(invoke('observe', keyPath, options, callback));
  }

  /// This acts similarly to [observe] - it will invoke once on first call, and
  /// then subsequnetly on each config change.
  Stream<dynamic> onDidChange(String keyPath, [Map options]) {
    Disposable disposable;
    StreamController controller = new StreamController.broadcast(onCancel: () {
      disposable?.dispose();
    });
    disposable = observe(keyPath, options, (e) => controller.add(e));
    return controller.stream;
  }
}

/// ViewRegistry handles the association between model and view types in Atom.
/// We call this association a View Provider. As in, for a given model, this
/// class can provide a view via [getView], as long as the model/view
/// association was registered via [addViewProvider].
class ViewRegistry extends ProxyHolder {
    ViewRegistry(JsObject object) : super(object);

  // TODO: expose addViewProvider(providerSpec)

  /// Get the view associated with an object in the workspace. The result is
  /// likely an html Element.
  dynamic getView(object) => invoke('getView', object);
}

/// Represents the state of the user interface for the entire window. Interact
/// with this object to open files, be notified of current and future editors,
/// and manipulate panes.
class Workspace extends ProxyHolder {
  FutureSerializer<TextEditor> _openSerializer = new FutureSerializer<TextEditor>();

  Workspace(JsObject object) : super(object);

  /// Returns a list of [TextEditor]s.
  List<TextEditor> getTextEditors() =>
      new List.from(invoke('getTextEditors').map((e) => new TextEditor(e)));

  /// Get the active item if it is a [TextEditor].
  TextEditor getActiveTextEditor() {
    var result = invoke('getActiveTextEditor');
    return result == null ? null : new TextEditor(result);
  }

  // /// Invoke the given callback with all current and future text editors in the
  // /// workspace.
  // Disposable observeTextEditors(void callback(TextEditor editor)) {
  //   var disposable = invoke('observeTextEditors', (ed) => callback(new TextEditor(ed)));
  //   return new JsDisposable(disposable);
  // }
  //
  // Disposable observeActivePaneItem(void callback(dynamic item)) {
  //   // TODO: What type is the item?
  //   var disposable = invoke('observeActivePaneItem', (item) => callback(item));
  //   return new JsDisposable(disposable);
  // }

  Panel addModalPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addModalPanel', _panelOptions(item, visible, priority)));

  // Panel addTopPanel({dynamic item, bool visible, int priority}) =>
  //     new Panel(invoke('addTopPanel', _panelOptions(item, visible, priority)));
  //
  // Panel addBottomPanel({dynamic item, bool visible, int priority}) =>
  //     new Panel(invoke('addBottomPanel', _panelOptions(item, visible, priority)));
  //
  // Panel addLeftPanel({dynamic item, bool visible, int priority}) =>
  //     new Panel(invoke('addLeftPanel', _panelOptions(item, visible, priority)));
  //
  // Panel addRightPanel({dynamic item, bool visible, int priority}) =>
  //     new Panel(invoke('addRightPanel', _panelOptions(item, visible, priority)));
  //
  // /// Get the Pane containing the given item.
  // Pane paneForItem(dynamic item) => new Pane(invoke('paneForItem', item));

  /// Opens the given URI in Atom asynchronously. If the URI is already open,
  /// the existing item for that URI will be activated. If no URI is given, or
  /// no registered opener can open the URI, a new empty TextEditor will be
  /// created.
  ///
  /// [options] can include initialLine, initialColumn, split, activePane, and
  /// searchAllPanes.
  Future<TextEditor> open(String url, {Map options}) {
    return _openSerializer.perform(() {
      Future future = promiseToFuture(invoke('open', url, options));
      return future.then((result) {
        if (result == null) throw 'unable to open ${url}';
        TextEditor editor = new TextEditor(result);
        return editor.isValid() ? editor : null;
      });
    });
  }

  // /// Register an opener for a uri.
  // ///
  // /// An [TextEditor] will be used if no openers return a value.
  // Disposable addOpener(dynamic opener(String url, Map options)) {
  //   return new JsDisposable(invoke('addOpener', (url, options) {
  //     Map m = options == null ? {} : jsObjectToDart(options);
  //     return opener(url, m);
  //   }));
  // }
  //
  // /// Save all dirty editors.
  // void saveAll() {
  //   try {
  //     invoke('saveAll');
  //   } catch (e) {
  //     _logger.info('exception calling saveAll', e);
  //   }
  // }

  Map _panelOptions(dynamic item, bool visible, int priority) {
    Map options = {'item': item};
    if (visible != null) options['visible'] = visible;
    if (priority != null) options['priority'] = priority;
    return options;
  }
}

/// Represents a project that's opened in Atom.
class Project extends ProxyHolder {
  Project(JsObject object) : super(object);

  /// Fire an event when the project paths change. Each event is an list of
  /// project paths.
  Stream<List<String>> get onDidChangePaths => eventStream('onDidChangePaths')
      as Stream<List<String>>;

  List<String> getPaths() => new List.from(invoke('getPaths'));

  // List<Directory> getDirectories() {
  //   return new List.from(invoke('getDirectories').map((dir) => new Directory(dir)));
  // }

  /// Add a path to the project's list of root paths.
  void addPath(String path) => invoke('addPath', path);

  /// Remove a path from the project's list of root paths.
  void removePath(String path) => invoke('removePath', path);

  /// Get the path to the project directory that contains the given path, and
  /// the relative path from that project directory to the given path. Returns
  /// an array with two elements: `projectPath` - the string path to the project
  /// directory that contains the given path, or `null` if none is found.
  /// `relativePath` - the relative path from the project directory to the given
  /// path.
  List<String> relativizePath(String fullPath) =>
      new List.from(invoke('relativizePath', fullPath));

  /// Determines whether the given path (real or symbolic) is inside the
  /// project's directory. This method does not actually check if the path
  /// exists, it just checks their locations relative to each other.
  bool contains(String pathToCheck) => invoke('contains', pathToCheck);
}

/// Package manager for coordinating the lifecycle of Atom packages. Packages
/// can be loaded, activated, and deactivated, and unloaded.
class PackageManager extends ProxyHolder {
  PackageManager(JsObject object) : super(object);

  /// Get the path to the apm command.
  ///
  /// Return a String file path to apm.
  String getApmPath() => invoke('getApmPath');

  /// Get the paths being used to look for packages.
  List<String> getPackageDirPaths() => new List.from(invoke('getPackageDirPaths'));

  /// Is the package with the given name bundled with Atom?
  bool isBundledPackage(name) => invoke('isBundledPackage', name);

  bool isPackageLoaded(String name) => invoke('isPackageLoaded', name);

  bool isPackageDisabled(String name) => invoke('isPackageDisabled', name);

  bool isPackageActive(String name) => invoke('isPackageActive', name);

  List<String> getAvailablePackageNames() =>
      new List.from(invoke('getAvailablePackageNames'));

  /// Activate a single package by name.
  Future activatePackage(String name) {
    return promiseToFuture(invoke('activatePackage', name));
  }
}

class Panel extends ProxyHolder {
  Panel(JsObject object) : super(object);

  Stream<bool> get onDidChangeVisible => eventStream('onDidChangeVisible') as Stream<bool>;
  Stream<Panel> get onDidDestroy =>
      eventStream('onDidDestroy').map((obj) => new Panel(obj)) as Stream<Panel>;

  bool isVisible() => invoke('isVisible');
  void show() => invoke('show');
  void hide() => invoke('hide');
  void destroy() => invoke('destroy');
}

/// This cooresponds to an `atom-text-editor` custom element.
class TextEditorElement extends ProxyHolder {
  TextEditorElement(JsObject object) : super(_cvt(object));

  TextEditor getModel() => new TextEditor(invoke('getModel'));

  bool get focusOnAttach => obj['focusOnAttach'];

  set focusOnAttach(bool value) {
    obj['focusOnAttach'] = value;
  }

  void focused() => invoke('focused');
}

class TextEditor extends ProxyHolder {
  TextEditor(JsObject object) : super(_cvt(object));

  TextEditorElement getElement() => new TextEditorElement(invoke('getElement'));

  /// Return whether this editor is a valid object. We sometimes create them
  /// from JS objects w/o knowning if they are editors for certain.
  bool isValid() {
    try {
      getTitle();
      getLongTitle();
      getPath();
      return true;
    } catch (e) {
      return false;
    }
  }

  String getTitle() => invoke('getTitle');
  String getLongTitle() => invoke('getLongTitle');
  String getPath() => invoke('getPath');
  String getText() => invoke('getText');
  bool isModified() => invoke('isModified');
  bool isEmpty() => invoke('isEmpty');
  bool isNotEmpty() => !isEmpty();
  void moveToEndOfLine() => invoke('moveToEndOfLine');
  String selectAll() => invoke('selectAll');
  void selectToBeginningOfWord() => invoke('selectToBeginningOfWord');
  void save() => invoke('save');

  /// Get the current Grammar of this editor.
  Grammar getGrammar() => new Grammar(invoke('getGrammar'));

  /// Set the current Grammar of this editor.
  ///
  /// Assigning a grammar will cause the editor to re-tokenize based on the new
  /// grammar.
  void setGrammar(Grammar grammar) {
    invoke('setGrammar', grammar);
  }

  int get hashCode => obj.hashCode;
  bool operator ==(other) => other is TextEditor && obj == other.obj;
}

/// Grammar that tokenizes lines of text.
class Grammar extends ProxyHolder {
  factory Grammar(JsObject object) => object == null ? null : new Grammar._(object);
  Grammar._(JsObject object) : super(_cvt(object));
}

/// Registry containing one or more grammars.
class GrammarRegistry extends ProxyHolder {
  GrammarRegistry(JsObject object) : super(_cvt(object));

  /// Get a grammar with the given scope name. [scopeName] should be a string
  /// such as "source.js".
  Grammar grammarForScopeName(String scopeName) {
    return new Grammar(invoke('grammarForScopeName', scopeName));
  }
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
