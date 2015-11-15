// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes various core node functions.
@JsName('global')
library node;

import '../src/js.dart';

@JsName()
external require(String path);
