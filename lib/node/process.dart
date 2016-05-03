// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Exposes the node process APIs.
library node.process;

import 'dart:async';

import 'package:logging/logging.dart';

import '../src/js.dart';
import 'node.dart';

final Process process = new Process._();

final bool isWindows = process.platform.startsWith('win');
final bool isMac = process.platform == 'darwin';
final bool isLinux = !isWindows && !isMac;
bool get isPosix => !isWindows;

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

Future<String> exec(String command, [List<String> args, Map<String, String> env]) {
  ProcessRunner runner = new ProcessRunner(command, args: args, env: env);
  return runner.execSimple().then((ProcessResult result) {
    if (result.exit == 0) return result.stdout;
    throw result.exit;
  });
}

/// Execute the given command synchronously and return the stdout. If the
/// process has a non-zero exit code, this method will throw.
String execSync(String command) {
  try {
    String result = require('child_process').callMethod('execSync', [command]);
    if (result == null) return null;
    result = '$result'.trim();
    return result.isEmpty ? null : result;
  } catch (error) {
    // https://nodejs.org/api/child_process.html#child_process_child_process_spawnsync_command_args_options
    throw '$error';
  }
}

class ProcessRunner {
  static ShellWrangler _shellWrangler;

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

  /// Execute the command using the environment of the user's preferred shell.
  /// On the Mac, this will determine the shell from the `$SHELL` env variable.
  /// On other platforms, this will call through to the normal [ProcessRunner]
  /// constructor.
  factory ProcessRunner.underShell(String command, {
    List<String> args, String cwd, Map<String, String> env
  }) {
    if (isPosix && _shellWrangler == null) {
      if (_shellWrangler == null) {
        _shellWrangler = new ShellWrangler();
      }

      if (_shellWrangler.isNecessary) {
        return new ProcessRunner(command, args: args, cwd: cwd, env: _shellWrangler.env);
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
    });
  }

  Future<int> execStreaming() {
    if (_process != null) throw new StateError('exec can only be called once');

    _logger.fine('exec: ${command} ${args == null ? "" : args.join(" ")}'
        '${cwd == null ? "" : " (cwd=${cwd})"}');

    try {
      _process = BufferedProcess.create(command, args: args, cwd: cwd, env: env,
          stdout: (s) => _stdoutController.add(s),
          stderr: (s) => _stderrController.add(s),
          exit: (code) {
            _logger.fine('exit code: ${code} (${command})');
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

/// Shell out to query the given environment variable. This is slower but more
/// reliable than the node env map.
String queryEnv(String variable) {
  try {
    return execSync('echo \$$variable');
  } catch (e) {
    return null;
  }
}

/// This class exists to help manage situations where Atom is running in an
/// environment without a properly set up environment (env and PATH variables).
///
/// When Atom is launched from the Dock on macos, it is run in the borne shell
/// (/bin/sh). A user's default shell on the mac is bash, so the borne shell
/// will have none of the user's environment variables or path set up. Atom will
/// not be able to locate or launch many user command-line applications. In
/// order to fix this, we:
/// - detect the current shell and the user's preferred shell
/// - gather all the env variables from the preferred shell
/// - when exec'ing a process, pass in the env variables discovered from the user's shell
class ShellWrangler {
  String _currentShell;
  String _targetShell;
  Map<String, String> _env;

  ShellWrangler() {
    _currentShell = queryEnv('0');
    _targetShell = queryEnv('SHELL');

    if (isNecessary) {
      String result;

      if (_targetShell.endsWith('/csh') || _targetShell.endsWith('/tcsh')) {
        // csh and tcsh don't support -l
        result = execSync("$_targetShell -c 'printenv'");
      } else {
        result = execSync("$_targetShell -l -c 'printenv'");
      }

      _env = {};

      for (String line in result.split('\n')) {
        int index = line.indexOf('=');
        if (index != -1) {
          String key = line.substring(0, index);
          String value = line.substring(index + 1);

          // Strip the `TERM` environment variable - when launching processes we
          // do not support ansi codes.
          if (key != 'TERM') _env[key] = value;
        }
      }
    }
  }

  bool get isNecessary {
    if (isMac) {
      return _currentShell == '/bin/sh';
    } else {
      return _currentShell != _targetShell;
    }
  }

  String get targetShell => _targetShell;

  String getEnv(String variable) => _env == null ? null : _env[variable];

  /// Return the target shell's environment. This will be `null` if the
  /// `isNecessary` is false.
  Map<String, String> get env => _env;

  String toString() => '$_currentShell $_targetShell $_env';
}

class BufferedProcess extends ProxyHolder {
  static BufferedProcess create(String command, {
      List<String> args,
      void stdout(String str),
      void stderr(String str),
      void exit(num code),
      String cwd,
      Map<String, String> env,
      Function onWillThrowError}) {
    Map<String, dynamic> options = {'command': command};

    if (args != null) options['args'] = args;
    if (stdout != null) options['stdout'] = stdout;
    if (stderr != null) options['stderr'] = stderr;
    if (exit != null) options['exit'] = exit;
    if (onWillThrowError != null) options['onWillThrowError'] = (JsObject e) {
      e.callMethod('handle');
      onWillThrowError(e['error']);
    };

    if (cwd != null || env != null) {
      Map<String, dynamic> nodeOptions = {};
      if (cwd != null) nodeOptions['cwd'] = cwd;
      if (env != null) nodeOptions['env'] = jsify(env);
      options['options'] = nodeOptions;
    }

    JsFunction ctor = require('atom')['BufferedProcess'];
    return new BufferedProcess._(new JsObject(ctor, [new JsObject.jsify(options)]));
  }

  JsObject _stdin;

  BufferedProcess._(JsObject object) : super(object);

  /// Write the given string as utf8 bytes to the process' stdin.
  void write(String str) {
    // node.js ChildProcess, Writeable stream
    if (_stdin == null) _stdin = obj['process']['stdin'];
    _stdin.callMethod('write', [str, 'utf8']);
  }

  void kill() => invoke('kill');
}
