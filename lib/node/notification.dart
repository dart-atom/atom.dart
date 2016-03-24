import 'dart:async';
import 'dart:html';

import 'package:atom/atom_utils.dart';
import 'package:atom/utils/disposable.dart';
import 'package:logging/logging.dart';

import '../atom.dart';
import '../src/js.dart';
import 'process.dart';

final Logger _logger = new Logger('notification');

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

  void setRunning() {
    try {
      // TODO: We can't actually get an html element for the `atom-notification`
      // custom element, because Dart and custom elements.
      _classList.callMethod('remove', ['icon-info']);
      _classList.callMethod('add', ['icon-running']);
    } catch (e) {
      print(e);
    }
  }

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

/// A helper class to visualize a running process.
class ProcessNotifier {
  final String title;

  Notification _notification;
  NotificationHelper _helper;

  ProcessNotifier(this.title) {
    _notification = atom.notifications
        .addInfo(title, detail: '', description: 'Running…', dismissable: true);

    _helper = new NotificationHelper(_notification.view);
    _helper.setNoWrap();
    _helper.setRunning();
  }

  /// Visualize the running process; watch the stdout and stderr streams.
  /// Complete the returned future when the process completes. Note that errors
  /// from the process are not propagated through to the returned Future.
  Future<int> watch(ProcessRunner runner) {
    runner.onStdout.listen((str) => _helper.appendText(str));
    runner.onStderr.listen((str) => _helper.appendText(str, stderr: true));

    _notification.onDidDismiss.listen((_) {
      // If the process has not already exited, kill it.
      if (runner.exit == null) runner.kill();
    });

    return runner.onExit.then((int result) {
      if (result == 0) {
        _helper.showSuccess();
        _helper.setSummary('Finished.');
      } else {
        _helper.showError();
        _helper.setSummary('Finished with exit code ${result}.');
      }
      return result;
    });
  }
}

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
