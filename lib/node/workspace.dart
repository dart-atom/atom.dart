
import 'dart:async';
import 'dart:html' as html;
import 'dart:js';

import 'package:logging/logging.dart';

import '../src/js.dart';
import '../src/utils.dart';
import '../utils/disposable.dart';
import 'config.dart';
import 'fs.dart';
import 'node.dart';

final Logger _logger = new Logger('workspace');

/// ViewRegistry handles the association between model and view types in Atom.
/// We call this association a View Provider. As in, for a given model, this
/// class can provide a view via [getView], as long as the model/view
/// association was registered via [addViewProvider].
class ViewRegistry extends ProxyHolder {
  static ViewRegistry _instance;

  ViewRegistry(JsObject object) : super(object) {
    _instance = this;
  }

  // TODO: add modelConstructor
  Disposable addViewProvider(createView) =>
      invoke('addViewProvider', createView);

  /// Get the view associated with an object in the workspace. The result is
  /// likely an html Element.
  dynamic getView(object) => invoke('getView', object);
}

// A Change Listener for events going into Atom instead of out.
class JsChangeListener {
  List<JsFunction> _callbacks = [];

  void add(JsFunction callback) {
    _callbacks.add(callback);
    return jsify ({
      'dispose': () => _callbacks.remove(callback)
    });
  }

  void change(List parameters) {
    for (var callback in _callbacks) {
      callback?.apply(parameters);
    }
  }
}

/// The term "item" refers to anything that can be displayed
/// in a pane within the workspace, either in the {WorkspaceCenter} or in one
/// of the three {Dock}s. The workspace expects items to conform to the
/// following interface:
class Item extends ProxyHolder {

  JsChangeListener onDidChangeTitle = new JsChangeListener();

  String _title;

  Item(JsObject object) : super(object);

  Item.fromFields({element, title, uri, defaultLocation, destroy})
      : _title = title,
        super(jsify({
    'element': element,
    // Returns the URI associated with the item.
    'getURI': () => uri,
    // Tells the workspace where your item should be opened in absence of a user
    // override. Items can appear in the center or in a dock on the left, right, or
    // bottom of the workspace.
    //
    // Returns a {String} with one of the following values: `'center'`, `'left'`,
    // `'right'`, `'bottom'`. If this method is not defined, `'center'` is the
    // default.
    'getDefaultLocation': () => defaultLocation,
    // Destroys the item. This will be called when the item is removed from its
    // parent pane.
    'destroy': destroy,
  })) {
    // Returns a {String} containing the title of the item to display on its
    // associated tab.
    obj['getTitle'] = jsify(() => _title);
    // Called by the workspace so it can be notified when the item's title changes.
    // Must return a {Disposable}.
    obj['onDidChangeTitle'] = jsify(onDidChangeTitle.add);

    // Custom functions.  Used to reach original Item objects, from
    // passed in Item references.  I.e., go through item functions instead
    // of using local private fields that maybe not be an Item constructed
    // with JsObject ctor.
    obj['setTitle'] = jsify((String newTitle) {
      _title = newTitle;
      onDidChangeTitle.change([newTitle]);
    });
  }

  // Any function below must go through invoking a JsFunction, because
  // private fields might not be in this instance of Item.
  String get uri => invoke('getURI');

  String get title => invoke('getTitle');
  set title(String newTitle) => invoke('setTitle', newTitle);

  // Not proxied yet:
  //
  // #### `onDidDestroy(callback)`
  //
  // Called by the workspace so it can be notified when the item is destroyed.
  // Must return a {Disposable}.
  //
  // #### `serialize()`
  //
  // Serialize the state of the item. Must return an object that can be passed to
  // `JSON.stringify`. The state should include a field called `deserializer`,
  // which names a deserializer declared in your `package.json`. This method is
  // invoked on items when serializing the workspace so they can be restored to
  // the same location later.
  //
  // #### `getLongTitle()`
  //
  // Returns a {String} containing a longer version of the title to display in
  // places like the window title or on tabs their short titles are ambiguous.
  //
  // #### `getIconName()`
  //
  // Return a {String} with the name of an icon. If this method is defined and
  // returns a string, the item's tab element will be rendered with the `icon` and
  // `icon-${iconName}` CSS classes.
  //
  // ### `onDidChangeIcon(callback)`
  //
  // Called by the workspace so it can be notified when the item's icon changes.
  // Must return a {Disposable}.
  //
  // #### `getAllowedLocations()`
  //
  // Tells the workspace where this item can be moved. Returns an {Array} of one
  // or more of the following values: `'center'`, `'left'`, `'right'`, or
  // `'bottom'`.
  //
  // #### `isPermanentDockItem()`
  //
  // Tells the workspace whether or not this item can be closed by the user by
  // clicking an `x` on its tab. Use of this feature is discouraged unless there's
  // a very good reason not to allow users to close your item. Items can be made
  // permanent *only* when they are contained in docks. Center pane items can
  // always be removed. Note that it is currently still possible to close dock
  // items via the `Close Pane` option in the context menu and via Atom APIs, so
  // you should still be prepared to handle your dock items being destroyed by the
  // user even if you implement this method.
  //
  // #### `save()`
  //
  // Saves the item.
  //
  // #### `saveAs(path)`
  //
  // Saves the item to the specified path.
  //
  // #### `getPath()`
  //
  // Returns the local path associated with this item. This is only used to set
  // the initial location of the "save as" dialog.
  //
  // #### `isModified()`
  //
  // Returns whether or not the item is modified to reflect modification in the
  // UI.
  //
  // #### `onDidChangeModified()`
  //
  // Called by the workspace so it can be notified when item's modified status
  // changes. Must return a {Disposable}.
  //
  // #### `copy()`
  //
  // Create a copy of the item. If defined, the workspace will call this method to
  // duplicate the item when splitting panes via certain split commands.
  //
  // #### `getPreferredHeight()`
  //
  // If this item is displayed in the bottom {Dock}, called by the workspace when
  // initially displaying the dock to set its height. Once the dock has been
  // resized by the user, their height will override this value.
  //
  // Returns a {Number}.
  //
  // #### `getPreferredWidth()`
  //
  // If this item is displayed in the left or right {Dock}, called by the
  // workspace when initially displaying the dock to set its width. Once the dock
  // has been resized by the user, their width will override this value.
  //
  // Returns a {Number}.
  //
  // #### `onDidTerminatePendingState(callback)`
  //
  // If the workspace is configured to use *pending pane items*, the workspace
  // will subscribe to this method to terminate the pending state of the item.
  // Must return a {Disposable}.
  //
  // #### `shouldPromptToSave()`
  //
  // This method indicates whether Atom should prompt the user to save this item
  // when the user closes or reloads the window. Returns a boolean.
}

/// Represents the state of the user interface for the entire window. Interact
/// with this object to open files, be notified of current and future editors,
/// and manipulate panes.
class Workspace extends ProxyHolder {
  FutureSerializer<TextEditor> _openSerializer = new FutureSerializer();

  Workspace(JsObject object) : super(object);

  /// Returns a list of [TextEditor]s.
  List<TextEditor> getTextEditors() =>
      new List.from(invoke('getTextEditors').map((e) => new TextEditor(e)));

  /// Get the active item if it is a [TextEditor].
  TextEditor getActiveTextEditor() {
    var result = invoke('getActiveTextEditor');
    return result == null ? null : new TextEditor(result);
  }

  /// Invoke the given callback with all current and future text editors in the
  /// workspace.
  Disposable observeTextEditors(void callback(TextEditor editor)) {
    var disposable = invoke('observeTextEditors', (ed) => callback(new TextEditor(ed)));
    return new JsDisposable(disposable);
  }

  Disposable observeActivePaneItem(void callback(dynamic item)) {
    // TODO: What type is the item?
    var disposable = invoke('observeActivePaneItem', (item) => callback(item));
    return new JsDisposable(disposable);
  }

  Panel addModalPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addModalPanel', _panelOptions(item, visible, priority)));

  Panel addTopPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addTopPanel', _panelOptions(item, visible, priority)));

  Panel addBottomPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addBottomPanel', _panelOptions(item, visible, priority)));

  Panel addLeftPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addLeftPanel', _panelOptions(item, visible, priority)));

  Panel addRightPanel({dynamic item, bool visible, int priority}) =>
      new Panel(invoke('addRightPanel', _panelOptions(item, visible, priority)));

  /// Get the Pane containing the given item.
  Pane paneForItem(dynamic item) => new Pane(invoke('paneForItem', item));

  /// Opens the given URI in Atom asynchronously. If the URI is already open,
  /// the existing item for that URI will be activated. If no URI is given, or
  /// no registered opener can open the URI, a new empty TextEditor will be
  /// created.
  ///
  /// [options] can include initialLine, initialColumn, split, activePane,
  /// searchAllPanes, and pending.
  Future<TextEditor> open(String url, {Map options}) {
    return _openSerializer.perform(() {
      Future future = promiseToFuture(invoke('open', url, options));
      return future.then((result) {
        if (result == null) throw 'unable to open ${url}';
        if (url.startsWith('atom://dartlang')) return null;
        TextEditor editor = new TextEditor(result);
        return editor.isValid() ? editor : null;
      });
    });
  }

  /// Call the `workspace.open` call with `pending` set to true; this will open
  /// the tab in a preview mode.
  Future<TextEditor> openPending(String url, {Map options}) {
    if (options == null) {
      options = {'pending': true};
    } else {
      options['pending'] = true;
    }

    return open(url, options: options);
  }

  /// Open the settings view. Optionally open it to the settings for a particular
  /// plugin.
  Future<TextEditor> openConfigPage({String packageID}) {
    if (packageID == null) {
      return open('atom://config');
    } else {
      return open('atom://config/packages/${packageID}');
    }
  }

  /// Register an opener for a uri.
  ///
  /// An [TextEditor] will be used if no openers return a value.
  Disposable addOpener(dynamic opener(String url, Map options)) {
    return new JsDisposable(invoke('addOpener', (url, options) {
      Map m = options == null ? {} : jsObjectToDart(options);
      return opener(url, m);
    }));
  }

  Stream<JsObject> get onDidDestroyPaneItem => eventStream('onDidDestroyPaneItem');

  /// Save all dirty editors.
  void saveAll() {
    try {
      invoke('saveAll');
    } catch (e) {
      _logger.info('exception calling saveAll', e);
    }
  }

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

  List<Directory> getDirectories() {
    return new List.from(invoke('getDirectories').map((dir) => new Directory(dir)));
  }

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

class Panel extends ProxyHolder {
  Panel(JsObject object) : super(object);

  Stream<bool> get onDidChangeVisible => eventStream('onDidChangeVisible') as Stream<bool>;
  Stream<Panel> get onDidDestroy => eventStream('onDidDestroy').map((obj) => new Panel(obj));

  bool isVisible() => invoke('isVisible');
  void show() => invoke('show');
  void hide() => invoke('hide');
  void destroy() => invoke('destroy');
}

class Pane extends ProxyHolder {
  factory Pane(JsObject object) => object == null ? null : new Pane._(object);

  Pane._(JsObject object) : super(object);

  /// Make the given item active, causing it to be displayed by the pane's view.
  void activateItem(dynamic item) => invoke('activateItem', item);

  bool destroyItem(dynamic item) => invoke('destroyItem', item);
}

class Gutter extends ProxyHolder {
  Gutter(JsObject object) : super(_cvt(object));

  String get name => obj['name'];

  void hide() => invoke('hide');

  void show() => invoke('show');

  bool isVisible() => invoke('isVisible');

  /// Calls your callback when the gutter is destroyed.
  Disposable onDidDestroy(void callback()) {
    return new JsDisposable(invoke('onDidDestroy', callback));
  }

  String toString() => '[Gutter ${name}]';
}

/// Represents a buffer annotation that remains logically stationary even as the
/// buffer changes. This is used to represent cursors, folds, snippet targets,
/// misspelled words, and anything else that needs to track a logical location
/// in the buffer over time.
class Marker extends ProxyHolder {
  Marker(JsObject object) : super(_cvt(object));

  /// Invoke the given callback when the state of the marker changes.
  Stream<dynamic> get onDidChange => eventStream('onDidChange');

  /// Invoke the given callback when the marker is destroyed.
  Stream get onDidDestroy => eventStream('onDidDestroy');

  /// Returns a Boolean indicating whether the marker is valid. Markers can be
  /// invalidated when a region surrounding them in the buffer is changed.
  bool isValid() => invoke('isValid');

  /// Returns a Boolean indicating whether the marker has been destroyed. A
  /// marker can be invalid without being destroyed, in which case undoing the
  /// invalidating operation would restore the marker. Once a marker is
  /// destroyed by calling Marker::destroy, no undo/redo operation can ever
  /// bring it back.
  void isDestroyed() => invoke('isDestroyed');

  /// Returns an Object containing any custom properties associated with the marker.
  Map<String, dynamic> getProperties() => invoke('getProperties') as Map<String, dynamic>;

  /// Gets the buffer range of the display marker.
  Range getBufferRange() => new Range(invoke('getBufferRange'));

  /// Destroys the marker, causing it to emit the 'destroyed' event. Once
  /// destroyed, a marker cannot be restored by undo/redo operations.
  void destroy() => invoke('destroy');
}

/// Represents a decoration that follows a Marker. A decoration is basically a
/// visual representation of a marker. It allows you to add CSS classes to line
/// numbers in the gutter, lines, and add selection-line regions around marked
/// ranges of text.
class Decoration extends ProxyHolder {
  Decoration(JsObject object) : super(_cvt(object));

  /// An id unique across all Decoration objects
  num getId() => invoke('getId');

  /// Returns the Decoration's properties.
  Map<String, dynamic> getProperties() => invoke('getProperties') as Map<String, dynamic>;

  /// Update the marker with new Properties. Allows you to change the
  /// decoration's class. E.g. `{type: 'line-number', class: 'my-new-class'}`.
  void setProperties(Map<String, dynamic> properties) =>
      invoke('setProperties', properties);
}

/// Represents a point in a buffer in row / column coordinates.
class Point extends ProxyHolder {
  Point(JsObject object) : super(_cvt(object));
  Point.coords(int row, int column) : super(_create('Point', row, column));

  /// A zero-indexed Number representing the row of the Point.
  int get row => obj['row'];
  /// A zero-indexed Number representing the column of the Point.
  int get column => obj['column'];

  operator==(other) => other is Point && row == other.row && column == other.column;
  int get hashCode => (row << 4) ^ column;

  String toString() => invoke('toString');
}

/// Represents a region in a buffer in row / column coordinates.
class Range extends ProxyHolder {
  factory Range(JsObject object) => object == null ? null : new Range._(object);
  Range.fromPoints(Point start, Point end) : super(_create('Range', start.obj, end.obj));
  Range._(JsObject object) : super(_cvt(object));

  bool isEmpty() => invoke('isEmpty');
  bool isNotEmpty() => !isEmpty();
  bool isSingleLine() => invoke('isSingleLine');
  int getRowCount() => invoke('getRowCount');

  Point get start => new Point(obj['start']);
  Point get end => new Point(obj['end']);

  operator==(other) => other is Range && start == other.start && end == other.end;
  int get hashCode => start.hashCode ^ end.hashCode;

  String toString() => invoke('toString');
}

class TextBuffer extends ProxyHolder {
  TextBuffer(JsObject object) : super(_cvt(object));

  String getPath() => invoke('getPath');

  int characterIndexForPosition(Point position) =>
      invoke('characterIndexForPosition', position);
  Point positionForCharacterIndex(int offset) =>
      new Point(invoke('positionForCharacterIndex', offset));

  /// Set the text in the given range. Returns the Range of the inserted text.
  Range setTextInRange(Range range, String text) =>
      new Range(invoke('setTextInRange', range, text));

  /// Create a pointer to the current state of the buffer for use with
  /// [groupChangesSinceCheckpoint] and [revertToCheckpoint].
  dynamic createCheckpoint() => invoke('createCheckpoint');
  /// Group all changes since the given checkpoint into a single transaction for
  /// purposes of undo/redo. If the given checkpoint is no longer present in the
  /// undo history, no grouping will be performed and this method will return
  /// false.
  bool groupChangesSinceCheckpoint(checkpoint) => invoke('groupChangesSinceCheckpoint', checkpoint);
  /// Revert the buffer to the state it was in when the given checkpoint was
  /// created. The redo stack will be empty following this operation, so changes
  /// since the checkpoint will be lost. If the given checkpoint is no longer
  /// present in the undo history, no changes will be made to the buffer and
  /// this method will return false.
  bool revertToCheckpoint(checkpoint) => invoke('revertToCheckpoint', checkpoint);

  /// Perform the [fn] in one atomic, undoable transaction.
  void atomic(void fn()) {
    var checkpoint = createCheckpoint();
    try {
      fn();
      groupChangesSinceCheckpoint(checkpoint);
    } catch (e) {
      revertToCheckpoint(checkpoint);
      _logger.warning('transaction failed: ${e}');
    }
  }

  /// Get the range for the given row. [row] is a number representing a
  /// 0-indexed row. [includeNewline] is a bool indicating whether or not to
  /// include the newline, which results in a range that extends to the start of
  /// the next line.
  Range rangeForRow(int row, bool includeNewline) =>
      new Range(invoke('rangeForRow', row, includeNewline));

  /// Invoke the given callback before the buffer is saved to disk.
  Stream get onWillSave => eventStream('onWillSave');
}

/// This cooresponds to an `atom-text-editor` custom element.
class TextEditorElement extends ProxyHolder {
  TextEditorElement(JsObject object) : super(_cvt(object));

  TextEditor getModel() => new TextEditor(invoke('getModel'));

  TextEditorComponent getComponent() =>
      new TextEditorComponent(obj['component']);

  void focused() => invoke('focused');
}

class TextEditorComponent extends ProxyHolder {
  TextEditorComponent(JsObject object) : super(_cvt(object));

  Point screenPositionForMouseEvent(html.MouseEvent e) =>
      new Point(invoke('screenPositionForMouseEvent', e));

  html.Point pixelPositionForScreenPosition(Point screen) {
    JsObject pt = invoke('pixelPositionForScreenPosition', screen.obj);
    return new html.Point<num>(pt['left'], pt['top']);
  }

  num get scrollTop => invoke('getScrollTop');
  num get scrollLeft => invoke('getScrollLeft');
  num get gutterWidth => invoke('getGutterWidth');
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

  TextBuffer getBuffer() => new TextBuffer(invoke('getBuffer'));

  String getTitle() => invoke('getTitle');
  String getLongTitle() => invoke('getLongTitle');
  String getPath() => invoke('getPath');
  bool isModified() => invoke('isModified');
  bool isEmpty() => invoke('isEmpty');
  bool isNotEmpty() => !isEmpty();

  void insertNewline() => invoke('insertNewline');

  void backspace() => invoke('backspace');

  /// Replaces the entire contents of the buffer with the given String.
  void setText(String text) => invoke('setText', text);

  /// Returns a [Range] when the text has been inserted. Returns a `bool`
  /// (`false`) when the text has not been inserted.
  ///
  /// For [options]: `select` if true, selects the newly added text.
  /// `autoIndent` if true, indents all inserted text appropriately.
  /// `autoIndentNewline` if true, indent newline appropriately.
  /// `autoDecreaseIndent` if true, decreases indent level appropriately (for
  /// example, when a closing bracket is inserted). `normalizeLineEndings`
  /// (optional) bool (default: true). `undo` if skip, skips the undo stack for
  /// this operation.
  dynamic insertText(String text, {Map options}) {
    var result = invoke('insertText', text, options);
    return result is bool ? result : new Range(result);
  }

  String selectAll() => invoke('selectAll');

  dynamic getRootScopeDescriptor() => invoke('getRootScopeDescriptor');

  /// Get the syntactic scopeDescriptor for the given position in buffer
  /// coordinates.
  ScopeDescriptor scopeDescriptorForBufferPosition(Point bufferPosition) =>
      new ScopeDescriptor(invoke('scopeDescriptorForBufferPosition', bufferPosition));

  String getText() => invoke('getText');
  String getSelectedText() => invoke('getSelectedText');
  String getTextInBufferRange(Range range) => invoke('getTextInBufferRange', range);
  /// Get the [Range] of the most recently added selection in buffer coordinates.
  Range getSelectedBufferRange() => new Range(invoke('getSelectedBufferRange'));

  /// Set the selected range in buffer coordinates. If there are multiple
  /// selections, they are reduced to a single selection with the given range.
  void setSelectedBufferRange(Range bufferRange) =>
      invoke('setSelectedBufferRange', bufferRange);
  /// Set the selected ranges in buffer coordinates. If there are multiple
  /// selections, they are replaced by new selections with the given ranges.
  void setSelectedBufferRanges(List<Range> ranges) =>
      invoke('setSelectedBufferRanges', ranges.map((Range r) => r.obj).toList());

  Range getCurrentParagraphBufferRange() =>
      new Range(invoke('getCurrentParagraphBufferRange'));
  Range setTextInBufferRange(Range range, String text) =>
      new Range(invoke('setTextInBufferRange', range, text));

  /// Move the cursor to the given position in buffer coordinates.
  void setCursorBufferPosition(Point point) =>
      invoke('setCursorBufferPosition', point);
  void selectRight(columnCount) => invoke('selectRight', columnCount);

  void moveUp(int lineCount) => invoke('moveUp', lineCount);
  void moveDown(int lineCount) => invoke('moveDown', lineCount);
  void moveLeft(int rowCount) => invoke('moveLeft', rowCount);
  void moveRight(int rowCount) => invoke('moveRight', rowCount);
  void moveToBeginningOfLine() => invoke('moveToBeginningOfLine');
  void moveToBeginningOfScreenLine() => invoke('moveToBeginningOfScreenLine');
  void moveToFirstCharacterOfLine() => invoke('moveToFirstCharacterOfLine');
  void moveToEndOfLine() => invoke('moveToEndOfLine');
  void moveToEndOfScreenLine() => invoke('moveToEndOfScreenLine');
  void moveToBeginningOfWord() => invoke('moveToBeginningOfWord');
  void moveToEndOfWord() => invoke('moveToEndOfWord');

  String lineTextForBufferRow(int bufferRow) =>
      invoke('lineTextForBufferRow', bufferRow);

  /// Create a marker with the given range in buffer coordinates. This marker
  /// will maintain its logical location as the buffer is changed, so if you
  /// mark a particular word, the marker will remain over that word even if the
  /// word's location in the buffer changes.
  Marker markBufferRange(Range range, {
    Map<String, dynamic> properties, bool persistent
  }) {
    if (properties == null && persistent != null) {
      properties = {'persistent': persistent};
    } else if (persistent != null) {
      properties['persistent'] = persistent;
    }

    return new Marker(invoke('markBufferRange', range, properties));
  }

  /// Adds a decoration that tracks a Marker. When the marker moves, is
  /// invalidated, or is destroyed, the decoration will be updated to reflect
  /// the marker's state.
  ///
  /// [decorationParams] is an object representing the decoration e.g.
  /// `{type: 'line-number', class: 'linter-error'}`.
  Decoration decorateMarker(Marker marker, Map<String, dynamic> decorationParams) {
    return new Decoration(invoke('decorateMarker', marker, decorationParams));
  }

  /// Get the current Grammar of this editor.
  Grammar getGrammar() => new Grammar(invoke('getGrammar'));

  /// Set the current Grammar of this editor.
  ///
  /// Assigning a grammar will cause the editor to re-tokenize based on the new
  /// grammar.
  void setGrammar(Grammar grammar) {
    invoke('setGrammar', grammar);
  }

  void undo() => invoke('undo');
  void redo() => invoke('redo');

  dynamic createCheckpoint() => invoke('createCheckpoint');
  bool groupChangesSinceCheckpoint(checkpoint) => invoke('groupChangesSinceCheckpoint', checkpoint);
  bool revertToCheckpoint(checkpoint) => invoke('revertToCheckpoint', checkpoint);

  /// Perform the [fn] in one atomic, undoable transaction.
  void atomic(void fn()) {
    var checkpoint = createCheckpoint();
    try {
      fn();
      groupChangesSinceCheckpoint(checkpoint);
    } catch (e) {
      revertToCheckpoint(checkpoint);
      _logger.warning('transaction failed: ${e}');
    }
  }

  void save() => invoke('save');

  /// Calls your callback when the grammar that interprets and colorizes the
  /// text has been changed. Immediately calls your callback with the current
  /// grammar.
  Disposable observeGrammar(void callback(Grammar grammar)) {
    var disposable = invoke('observeGrammar', (g) => callback(new Grammar(g)));
    return new JsDisposable(disposable);
  }

  /// Determine if the given row is entirely a comment.
  bool isBufferRowCommented(int bufferRow) =>
      invoke('isBufferRowCommented', bufferRow);

  Point screenPositionForPixelPosition(Point position) =>
      invoke('screenPositionForPixelPosition', position);

  Point pixelPositionForScreenPosition(Point position) =>
      invoke('pixelPositionForScreenPosition', position);

  /// Convert a position in buffer-coordinates to screen-coordinates.
  Point screenPositionForBufferPosition(Point position) =>
      invoke('screenPositionForBufferPosition', position);

  /// Convert a position in screen-coordinates to buffer-coordinates.
  Point bufferPositionForScreenPosition(position) =>
      invoke('bufferPositionForScreenPosition', position);

  /// Scrolls the editor to the given buffer position.
  void scrollToBufferPosition(Point bufferPosition, {bool center}) {
    Map options;
    if (center != null) options = {'center': center};
    invoke('scrollToBufferPosition', bufferPosition, options);
  }

  /// For each cursor, select the containing line. This method merges selections
  /// on successive lines.
  void selectLinesContainingCursors() => invoke('selectLinesContainingCursors');

  /// Invoke the given callback synchronously when the content of the buffer
  /// changes. Because observers are invoked synchronously, it's important not
  /// to perform any expensive operations via this method. Consider
  /// [onDidStopChanging] to delay expensive operations until after changes stop
  /// occurring.
  Stream get onDidChange => eventStream('onDidChange');

  /// Fire an event when the buffer's contents change. It is emitted
  /// asynchronously 300ms after the last buffer change. This is a good place to
  /// handle changes to the buffer without compromising typing performance.
  Stream get onDidStopChanging => eventStream('onDidStopChanging');

  Stream get onDidChangeTitle => eventStream('onDidChangeTitle');

  /// Invoke the given callback when the editor is destroyed.
  Stream get onDidDestroy => eventStream('onDidDestroy');

  /// Invoke the given callback after the buffer is saved to disk.
  Stream get onDidSave => eventStream('onDidSave');

  /// Calls your callback when a Cursor is moved. If there are multiple cursors,
  /// your callback will be called for each cursor.
  ///
  /// Returns the new buffer position.
  Stream get onDidChangeCursorPosition {
    return eventStream('onDidChangeCursorPosition').map(
      (e) => new Point(e['newBufferPosition']));
  }

  // Return the editor's TextEditorView / <text-editor-view> / HtmlElement. This
  // view is an HtmlElement, but we can't use it as one. We need to access it
  // through JS interop.
  dynamic get view => ViewRegistry._instance.getView(obj);

  void selectToBeginningOfWord() => invoke('selectToBeginningOfWord');

  /// Get the position of the most recently added cursor in buffer coordinates.
  Point getCursorBufferPosition() => new Point(invoke('getCursorBufferPosition'));

  /// Get the position of all the cursor positions in buffer coordinates.
  /// Returns Array of Points in the order they were added
  //List<Point> getCursorBufferPositions() =>

  /// Set the greyed out placeholder of a mini editor. Placeholder text will be
  /// displayed when the editor has no content.
  void setPlaceholderText(String placeholderText) => invoke('setPlaceholderText', placeholderText);

  /// Get this editor's gutters.
  List<Gutter> getGutters() => new List.from(invoke('getGutters').map((g) => new Gutter(g)));

  /// Get the gutter with the given name.
  Gutter gutterWithName(String name) {
    var result = invoke('gutterWithName', name);
    return result == null ? null : new Gutter(result);
  }

  /// Calls your callback when a Gutter is added to the editor. Immediately
  /// calls your callback for each existing gutter.
  Disposable observeGutters(void callback(Gutter gutter)) {
    var disposable = invoke('observeGutters', (obj) {
      callback(new Gutter(obj));
    });
    return new JsDisposable(disposable);
  }

  Stream<Gutter> get onDidAddGutter => eventStream('onDidAddGutter').map((g) => new Gutter(g));

  Stream<Gutter> get onDidRemoveGutter => eventStream('onDidRemoveGutter').map((g) => new Gutter(g));

  int get hashCode => obj.hashCode;

  bool operator ==(other) => other is TextEditor && obj == other.obj;

  @override String toString() => getTitle();
}

JsObject _create(String className, dynamic arg1, [dynamic arg2]) {
  if (arg2 != null) {
    return new JsObject(require('atom')[className], [arg1, arg2]);
  } else {
    return new JsObject(require('atom')[className], [arg1]);
  }
}

JsObject _cvt(JsObject object) {
  if (object == null) return null;
  if (object is JsObject) return object;

  // We really shouldn't have to be wrapping objects we've already gotten from
  // JS interop.
  return new JsObject.fromBrowserObject(object);
}
