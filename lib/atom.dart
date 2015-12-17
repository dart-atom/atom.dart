// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Atom APIs for Dart.
library atom;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' show Element, DivElement, HttpRequest, ScrollAlignment;

import 'src/js.dart';

/// The singleton instance of [Atom].
final Atom atom = new Atom();

void registerPackage(AtomPackage package) {
  Map packageInfo = {
    'activate': package.activate,
    'deactivate': package.deactivate,
    'config': package.config(),
    'serialize': package.serialize
  };

  context[package.id] = jsify(packageInfo);
}

abstract class AtomPackage {
  final String id;

  AtomPackage(this.id);

  void activate([dynamic state]);
  Map config() => {};
  dynamic serialize() => {};
  void deactivate() { }

  Future<Map<String, dynamic>> loadPackageJson() {
    return HttpRequest.getString('atom://${id}/package.json').then((String str) {
      return JSON.decode(str);
    }) as Future<Map>;
  }

  Future<String> getPackageVersion() {
    return loadPackageJson().then((Map map) => map['version']) as Future<String>;
  }
}

class Atom extends ProxyHolder {
  // CommandRegistry _commands;
  // Config _config;
  // ContextMenuManager _contextMenu;
  // GrammarRegistry _grammars;
  NotificationManager _notifications;
  PackageManager _packages;
  // Project _project;
  ViewRegistry _views;
  // Workspace _workspace;

  Atom() : super(context['atom']) {
    // _commands = new CommandRegistry(obj['commands']);
    // _config = new Config(obj['config']);
    // _contextMenu = new ContextMenuManager(obj['contextMenu']);
    // _grammars = new GrammarRegistry(obj['grammars']);
    _notifications = new NotificationManager(obj['notifications']);
    _packages = new PackageManager(obj['packages']);
    // _project = new Project(obj['project']);
    _views = new ViewRegistry(obj['views']);
    // _workspace = new Workspace(obj['workspace']);
  }

  // CommandRegistry get commands => _commands;
  // Config get config => _config;
  // ContextMenuManager get contextMenu => _contextMenu;
  // GrammarRegistry get grammars => _grammars;
  NotificationManager get notifications => _notifications;
  PackageManager get packages => _packages;
  // Project get project => _project;
  ViewRegistry get views => _views;
  // Workspace get workspace => _workspace;

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

/// A notification manager used to create notifications to be shown to the user.
class NotificationManager extends ProxyHolder {
  NotificationManager(JsObject object) : super(object);

  /// Add an success notification. If [dismissable] is `true`, the notification
  /// is rendered with a close button and does not auto-close.
  Notification addSuccess(String message, {String detail, String description,
      bool dismissable, String icon, List<NotificationButton> buttons}) {
    return new Notification(invoke('addSuccess', message, _options(detail: detail,
      description: description, dismissable: dismissable, icon: icon, buttons: buttons)));
  }

  /// Add an informational notification.
  Notification addInfo(String message, {String detail, String description,
      bool dismissable, String icon, List<NotificationButton> buttons}) {
    return new Notification(invoke('addInfo', message, _options(detail: detail,
      description: description, dismissable: dismissable, icon: icon, buttons: buttons)));
  }

  /// Add an warning notification.
  Notification addWarning(String message, {String detail, String description,
      bool dismissable, String icon, List<NotificationButton> buttons}) {
    return new Notification(invoke('addWarning', message, _options(detail: detail,
      description: description, dismissable: dismissable, icon: icon, buttons: buttons)));
  }

  /// Add an error notification.
  Notification addError(String message, {String detail, String description,
      bool dismissable, String icon, List<NotificationButton> buttons}) {
    return new Notification(invoke('addError', message, _options(detail: detail,
      description: description, dismissable: dismissable, icon: icon, buttons: buttons)));
  }

  /// Add an fatal error notification.
  Notification addFatalError(String message, {String detail, String description,
      bool dismissable, String icon, List<NotificationButton> buttons}) {
    return new Notification(invoke('addFatalError', message, _options(detail: detail,
      description: description, dismissable: dismissable, icon: icon, buttons: buttons)));
  }

  /// Get all the notifications.
  List<Notification> getNotifications() =>
      new List.from(invoke('getNotifications').map((n) => new Notification(n)));

  Map _options({String detail, String description, bool dismissable, String icon,
      List<NotificationButton> buttons}) {
    if (detail == null && description == null && dismissable == null &&
        icon == null && buttons == null) {
      return null;
    }

    Map m = {};
    if (detail != null) m['detail'] = detail;
    if (description != null) m['description'] = description;
    if (dismissable != null) m['dismissable'] = dismissable;
    if (icon != null) m['icon'] = icon;
    if (buttons != null) {
      m['buttons'] = jsify(buttons.map((NotificationButton nb) => nb.toProxy()).toList());
    }
    return m;
  }
}

/// A notification to the user containing a message and type.
class Notification extends ProxyHolder {
  Notification(JsObject object) : super(object);

  /// Return the associated `atom-notification` custom element.
  dynamic get view => atom.views.getView(obj);

  /// Invoke the given callback when the notification is dismissed.
  Stream get onDidDismiss => eventStream('onDidDismiss');

  bool get dismissed => obj['dismissed'];
  bool get displayed => obj['displayed'];

  /// Invoke the given callback when the notification is displayed.
  //onDidDisplay(callback)

  String getType() => invoke('getType');

  String getMessage() => invoke('getMessage');

  /// Dismisses the notification, removing it from the UI. Calling this
  /// programmatically will call all callbacks added via `onDidDismiss`.
  void dismiss() => invoke('dismiss');
}

class NotificationButton {
  final String text;
  final Function onDidClick;

  NotificationButton(this.text, this.onDidClick);

  JsObject toProxy() => jsify({'text': text, 'onDidClick': (_) => onDidClick()});
}

/// A helper class to manipulate the UI of [Notification]s.
class NotificationHelper {
  JsObject _view;
  var _classList;
  Element _content;
  Element _titleElement;
  Element _detailContent;
  Element _description;

  NotificationHelper(this._view) {
    _classList = _view['classList'];
    _content = _view.callMethod('querySelector', ['div.content']);
    _titleElement = _content.querySelector('div.message p');
    _detailContent = _content.querySelector('div.detail-content');
    _description = _content.querySelector('div.meta div.description');
    // _classList.callMethod('add', ['dartlang']);
  }

  void setNoWrap() {
    _detailContent.classes.toggle('detail-content-no-wrap');
  }

  // void setRunning() {
  //   try {
  //     // TODO: We can't actually get an html element for the `atom-notification`
  //     // custom element, because Dart and custom elements.
  //     _classList.callMethod('remove', ['icon-info']);
  //     _classList.callMethod('add', ['icon-running']);
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  Element get titleElement => _titleElement;
  Element get detailContent => _detailContent;

  String get title => _titleElement.text;
  set title(String value) {
    _titleElement.text = value;
  }

  void appendText(String text, {bool stderr: false}) {
    _classList.callMethod('toggle', ['has-detail', true]);

    List<Element> elements = new List.from(text.split('\n').map((line) {
      DivElement div = new DivElement()..text = line;
      div.classes.toggle('line');
      if (stderr) div.classes.toggle('text-error');
      return div;
    }));

    _detailContent.children.addAll(elements);
    if (elements.isNotEmpty) elements.last.scrollIntoView(ScrollAlignment.BOTTOM);
  }

  void setSummary(String text) {
    _description.text = text;
  }

  void showSuccess() {
    try {
      _classList.callMethod('remove', ['info', 'icon-info', 'icon-running']);
      _classList.callMethod('add', ['success', 'icon-check']);
    } catch (e) {
      print(e);
    }
  }

  void showError() {
    try {
      _classList.callMethod('remove', ['info', 'icon-info', 'icon-running']);
      _classList.callMethod('add', ['error', 'icon-flame']);
    } catch (e) {
      print(e);
    }
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
