import 'dart:io';

import 'package:atom/build/build.dart';
import 'package:grinder/grinder.dart';

main(List<String> args) => grind(args);

@Task()
analyze() => new PubApp.global('tuneup').runAsync(['check']);

@Task()
build() async {
  return buildDart2JS();
}

@Task()
test() => new TestRunner().testAsync();

buildDart2JS() async {
  File inputFile = getFile('example/demo.dart');
  File outputFile = getFile('example/demo.dart.js');

  await Dart2js.compileAsync(inputFile, csp: true);
  outputFile.writeAsStringSync(patchDart2JSOutput(outputFile.readAsStringSync()));
}

@DefaultTask()
@Depends(analyze, test, build)
bot() => null;

@Task('Analyze with DDC')
ddc() {
  return new DevCompiler().analyzeAsync(
    getFile('example/demo.dart'),
    htmlReport: true
  );
}
