
import 'dart:async';

import '../src/js.dart';
import '../utils/disposable.dart';

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
      if (disposable != null) disposable.dispose();
    });
    disposable = observe(keyPath, options, (e) => controller.add(e));
    return controller.stream;
  }
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

class ScopeDescriptor extends ProxyHolder {
  factory ScopeDescriptor(JsObject object) {
    return object == null ? null : new ScopeDescriptor._(object);
  }
  ScopeDescriptor._(JsObject object) : super(object);

  List<String> get scopes => new List.from(obj['scopes']);

  List<String> getScopesArray() => new List.from(invoke('getScopesArray'));
}

JsObject _cvt(JsObject object) {
  if (object == null) return null;
  if (object is JsObject) return object;

  // We really shouldn't have to be wrapping objects we've already gotten from
  // JS interop.
  return new JsObject.fromBrowserObject(object);
}
