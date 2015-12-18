// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

class FutureSerializer<T> {
  List _operations = [];
  List<Completer<T>> _completers = [];

  Future<T> perform(Function operation) {
    Completer<T> completer = new Completer();

    _operations.add(operation);
    _completers.add(completer);

    if (_operations.length == 1) {
      _serviceQueue();
    }

    return completer.future;
  }

  void _serviceQueue() {
    Function operation = _operations.first;
    Completer<T> completer = _completers.first;

    Future future = operation();
    future.then((value) {
      completer.complete(value);
    }).catchError((e) {
      completer.completeError(e);
    }).whenComplete(() {
      _operations.removeAt(0);
      _completers.removeAt(0);

      if (_operations.isNotEmpty) _serviceQueue();
    });
  }
}
