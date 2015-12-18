// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

final Logger _logger = new Logger('disposable');

abstract class Disposable {
  void dispose();
}

class Disposables implements Disposable {
  final bool catchExceptions;

  List<Disposable> _disposables = [];

  Disposables({this.catchExceptions});

  void add(Disposable disposable) => _disposables.add(disposable);

  void addAll(Iterable<Disposable> list) => _disposables.addAll(list);

  bool remove(Disposable disposable) => _disposables.remove(disposable);

  void dispose() {
    for (Disposable disposable in _disposables) {
      if (catchExceptions) {
        try {
          disposable.dispose();
        } catch (e, st) {
          _logger.severe('exception during dispose', e, st);
        }
      } else {
        disposable.dispose();
      }
    }

    _disposables.clear();
  }
}
