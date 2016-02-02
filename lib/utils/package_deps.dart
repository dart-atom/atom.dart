// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library atom.utils.package_deps;

import 'dart:async';

import '../atom.dart';
import '../node/process.dart';

Future install(String packageLabel, AtomPackage package, {bool justNotify: false}) {
  return package.loadPackageJson().then((Map info) {
    List<String> installedPackages = atom.packages.getAvailablePackageNames();
    List<String> requiredPackages = info['required-packages'] as List<String>;

    if (requiredPackages == null || requiredPackages.isEmpty) {
      return null;
    }

    Set<String> toInstall = new Set.from(requiredPackages);
    toInstall.removeAll(installedPackages);

    if (toInstall.isEmpty) return null;

    if (justNotify) {
      toInstall.forEach((String name) {
        atom.notifications.addInfo(
          "${packageLabel} recommends installing the '${name}' plugin for best results.",
          dismissable: true
          // , buttons: [new NotificationButton(
          //   'Install Packages',
          //   () => atom.workspace.open("atom://config/install")
          // )]
        );
      });
    } else {
      return Future.forEach(toInstall, _installPackage);
    }
  });
}

Future _installPackage(String name) {
  atom.notifications.addInfo('Installing ${name}…');

  ProcessRunner runner = new ProcessRunner.underShell(
    atom.packages.getApmPath(),
    args: ['--no-color', 'install', name]
  );

  return runner.execSimple().then((ProcessResult result) {
    if (result.exit == 0) {
      atom.packages.activatePackage(name);
    } else {
      if (result.stderr != null && result.stderr.isNotEmpty) {
        throw result.stderr.trim();
      } else {
        throw 'exit code ${result.exit}';
      }
    }
  }).then((_) {
    atom.notifications.addSuccess('Installed ${name}.');
  }).catchError((e) {
    atom.notifications.addError(
      'Error installing ${name}:',
      detail: '${e}',
      dismissable: true
    );
  });
}
