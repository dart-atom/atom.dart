// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node process APIs.
library node.process;

import 'dart:async';

import 'package:logging/logging.dart';

import '../atom.dart';
import '../src/js.dart';
import 'node.dart';

final Process process = new Process._();

final bool isWindows = process.platform.startsWith('win');
final bool isMac = process.platform == 'darwin';
final bool isLinux = !isWindows && !isMac;

final Logger _logger = new Logger('process');

class Process extends ProxyHolder {
  Process._() : super(require('process'));

  /// 'darwin', 'freebsd', 'linux', 'sunos' or 'win32'.
  String get platform => obj['platform'];

  String get chromeVersion => obj['versions']['chrome'];

  /// Get the value of an environment variable. This is often not accurate on
  /// the mac since mac apps are launched in a different shell then the terminal
  /// default.
  String env(String key) {
    try {
      return obj['env'][key];
    } catch (err) {
      return null;
    }
  }
}

Future<String> exec(String cmd, [List<String> args]) {
  ProcessRunner runner = new ProcessRunner(cmd, args: args);
  return runner.execSimple().then((ProcessResult result) {
    if (result.exit == 0) return result.stdout;
    throw result.exit;
  }) as Future<String>;
}

class ProcessRunner {
  final String command;
  final List<String> args;
  final String cwd;
  final Map<String, String> env;

  BufferedProcess _process;
  Completer<int> _exitCompleter = new Completer();
  int _exit;

  StreamController<String> _stdoutController = new StreamController();
  StreamController<String> _stderrController = new StreamController();

  ProcessRunner(this.command, {this.args, this.cwd, this.env});

  /// Execute the command under the user's preferred shell. On the Mac, this
  /// will determine the shell from the `$SHELL` env variable. On other platforms,
  /// this will call through to the normal [ProcessRunner] constructor.
  factory ProcessRunner.underShell(String command, {
    List<String> args, String cwd, Map<String, String> env
  }) {
    if (isMac) {
      // This shouldn't be trusted for security.
      final RegExp shellEscape = new RegExp('(["\'| \\\$!\\(\\)\\[\\]])');

      final String shell = process.env('SHELL');

      if (shell == null) {
        _logger.warning("Couldn't identify the user's shell");
      } else {
        if (args != null) {
          // Escape the arguments.
          Iterable escaped = args.map((String arg) {
            return "'${arg.replaceAllMapped(shellEscape, (Match m) => '\\' + m.group(0))}'";
          });
          command += ' ' + (escaped.join(' '));
        }

        args = ['-l', '-c', command];

        return new ProcessRunner(shell, args: args, cwd: cwd, env: env);
      }
    }

    return new ProcessRunner(command, args: args, cwd: cwd, env: env);
  }

  bool get started => _process != null;
  bool get finished => _exit != null;

  int get exit => _exit;

  Future<int> get onExit => _exitCompleter.future;

  Stream<String> get onStdout => _stdoutController.stream;
  Stream<String> get onStderr => _stderrController.stream;

  Future<ProcessResult> execSimple() {
    if (_process != null) throw new StateError('exec can only be called once');

    StringBuffer stdout = new StringBuffer();
    StringBuffer stderr = new StringBuffer();

    onStdout.listen((str) => stdout.write(str));
    onStderr.listen((str) => stderr.write(str));

    return execStreaming().then((code) {
      return new ProcessResult(code, stdout.toString(), stderr.toString());
    }) as Future<ProcessResult>;
  }

  Future<int> execStreaming() {
    if (_process != null) throw new StateError('exec can only be called once');

    // _logger.fine('exec: ${command} ${args == null ? "" : args.join(" ")}'
    //     '${cwd == null ? "" : " (cwd=${cwd})"}');

    try {
      _process = BufferedProcess.create(command, args: args, cwd: cwd, env: env,
          stdout: (s) => _stdoutController.add(s),
          stderr: (s) => _stderrController.add(s),
          exit: (code) {
            // _logger.fine('exit code: ${code} (${command})');
            _exit = code;
            if (!_exitCompleter.isCompleted) _exitCompleter.complete(code);
          },
          onWillThrowError: (e) {
            if (!_exitCompleter.isCompleted) _exitCompleter.completeError(e);
          }
      );
    } catch (e) {
      // TODO: We don't seem to be able to catch some JS exceptions.
      return new Future.error(e);
    }

    return _exitCompleter.future;
  }

  void write(String str) => _process.write(str);

  Future<int> kill() {
    // _logger.fine('kill: ${command} ');
    if (_process != null) _process.kill();
    new Future.delayed(new Duration(milliseconds: 50), () {
      if (!_exitCompleter.isCompleted) _exitCompleter.complete(0);
    });
    return _exitCompleter.future;
  }

  String getDescription() {
    if (args != null) {
      return '${command} ${args.join(' ')}';
    } else {
      return command;
    }
  }
}

class ProcessResult {
  final int exit;
  final String stdout;
  final String stderr;

  ProcessResult(this.exit, this.stdout, this.stderr);

  String toString() => '${exit}';
}
