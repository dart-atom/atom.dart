// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node fs APIs.
library node.fs;

import 'dart:async';

import '../src/js.dart';
import 'node.dart';
import 'process.dart';

final FS fs = new FS._();

class FS extends ProxyHolder {
  FS._() : super(require('fs'));

  final String separator = isWindows ? r'\' : '/';

  /// Return the name of the file for the given path.
  String basename(String path) {
    if (path.endsWith(separator)) path = path.substring(0, path.length - 1);
    int index = path.lastIndexOf(separator);
    return index == -1 ? path : path.substring(index + 1);
  }

  /// Return the parent of the given file path or entry.
  String dirname(entry) {
    if (entry is Entry) return entry.getParent().path;
    int index = entry.lastIndexOf(separator);
    return index == -1 ? null : entry.substring(0, index);
  }

  String join(dir, String arg1, [String arg2, String arg3]) {
    //if (dir is Directory) dir = dir.path;
    String path = '${dir}${separator}${arg1}';
    if (arg2 != null) {
      path = '${path}${separator}${arg2}';
      if (arg3 != null) path = '${path}${separator}${arg3}';
    }
    return path;
  }

  String relativize(String root, String path) {
    if (path.startsWith(root)) {
      path = path.substring(root.length);
      if (path.startsWith(separator)) path = path.substring(1);
    }
    return path;
  }

  /// Relative path entries are removed and symlinks are resolved to their final
  /// destination.
  String realpathSync(String path) => invoke('realpathSync', path);

  Stats statSync(String path) => new Stats._(invoke('statSync', path));

  bool existsSync(String path) => invoke('existsSync', path);
}

class Stats extends ProxyHolder {
  Stats._(JsObject obj) : super(obj);

  bool isFile() => invoke('isFile');
  bool isDirectory() => invoke('isDirectory');

  // The last modified time (`2015-10-08 17:48:42.000`).
  String get mtime => obj['mtime'];
}

class Directory extends Entry {
  Directory(JsObject object) : super(object);
  Directory.fromPath(String path, [bool symlink]) :
      super(_create('Directory', path, symlink));

  /// Creates the directory on disk that corresponds to [getPath] if no such
  /// directory already exists. [mode] defaults to `0777`.
  Future create([int mode]) => promiseToFuture(invoke('create', mode));

  /// Returns `true` if this [Directory] is the root directory of the
  /// filesystem, or `false` if it isn't.
  bool isRoot() => invoke('isRoot');

  // TODO: Should we move this _cvt guard into the File and Directory ctors?
  File getFile(filename) => new File(_cvt(invoke('getFile', filename)));

  Directory getSubdirectory(String dirname) =>
      new Directory(invoke('getSubdirectory', dirname));

  List<Entry> getEntriesSync() {
    return invoke('getEntriesSync').map((entry) {
      entry = _cvt(entry);
      return entry.callMethod('isFile') ? new File(entry) : new Directory(entry);
    }).toList() as List<Entry>;
  }

  /// Returns whether the given path (real or symbolic) is inside this directory.
  /// This method does not actually check if the path exists, it just checks if
  /// the path is under this directory.
  bool contains(String p) => invoke('contains', p);

  int get hashCode => path.hashCode;

  operator==(other) => other is Directory && path == other.path;
}

class File extends Entry {
  File(JsObject object) : super(object);
  File.fromPath(String path, [bool symlink]) :
      super(_create('File', path, symlink));

  /// Creates the file on disk that corresponds to [getPath] if no such file
  /// already exists.
  Future create() => promiseToFuture(invoke('create'));

  Stream get onDidRename => eventStream('onDidRename');
  Stream get onDidDelete => eventStream('onDidDelete');

  /// Get the SHA-1 digest of this file.
  String getDigestSync() => invoke('getDigestSync');

  String getEncoding() => invoke('getEncoding');

  /// Reads the contents of the file. [flushCache] indicates whether to require
  /// a direct read or if a cached copy is acceptable.
  Future<String> read([bool flushCache]) =>
      promiseToFuture(invoke('read', flushCache)) as Future<String>;

  /// Reads the contents of the file. [flushCache] indicates whether to require
  /// a direct read or if a cached copy is acceptable.
  String readSync([bool flushCache]) => invoke('readSync', flushCache);

  /// Overwrites the file with the given text.
  void writeSync(String text) => invoke('writeSync', text);

  int get hashCode => path.hashCode;

  operator==(other) => other is File && path == other.path;
}

abstract class Entry extends ProxyHolder {
  Entry(JsObject object) : super(object);

  /// Fires an event when the file or directory's contents change.
  Stream get onDidChange => eventStream('onDidChange');

  String get path => obj['path'];

  bool isFile() => invoke('isFile');
  bool isDirectory() => invoke('isDirectory');
  bool existsSync() => invoke('existsSync');

  String getBaseName() => invoke('getBaseName');
  String getPath() => invoke('getPath');
  String getRealPathSync() => invoke('getRealPathSync');

  Directory getParent() => new Directory(invoke('getParent'));

  String toString() => path;
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
  // We really shouldn't have to be wrapping objects we've already gotten from
  // JS interop.
  return new JsObject.fromBrowserObject(object);
}
