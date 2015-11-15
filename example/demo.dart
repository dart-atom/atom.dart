
// Build with: `dev_compiler -oexample/ddc example/demo.dart`.

import 'package:atom/atom.dart';

void main() {
  registerPackage(new DemoPackage());
}

class DemoPackage extends AtomPackage {
  DemoPackage() : super("_demoPackage");

  void activate([dynamic state]) {
    print('activated!');
  }

  void deactivate() {
    print('deactivated');
  }
}
