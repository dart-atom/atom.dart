import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' show HttpRequest;

import '../src/js.dart';
import '../utils/disposable.dart';

AtomPackage _package;

AtomPackage get atomPackage => _package;

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
  void deactivate() {}

  Future<Map<String, dynamic>> loadPackageJson() {
    String url = 'atom://${id}/package.json';
    return HttpRequest.getString(url).then((String str) {
      return JSON.decode(str) as Map<String, dynamic>;
    });
  }

  Future<String> getPackageVersion() {
    return loadPackageJson().then((Map map) => map['version']);
  }

  /// Register a method for a service callback (`consumedServices`).
  void registerServiceConsumer(
      String methodName, Disposable callback(JsObject obj)) {
    if (_registeredMethods == null) {
      throw new StateError('method must be registered in the package ctor');
    }
    _registeredMethods[methodName] = callback;
    return null;
  }

  void registerServiceProvider(String methodName, JsObject callback()) {
    if (_registeredMethods == null) {
      throw new StateError('method must be registered in the package ctor');
    }
    _registeredMethods[methodName] = callback;
    return null;
  }
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
