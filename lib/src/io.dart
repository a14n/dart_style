// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_style.src.io;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dart_formatter.dart';
import 'exceptions.dart';
import 'formatter_options.dart';
import 'source_code.dart';

/// Runs the formatter on every .dart file in [path] (and its subdirectories),
/// and replaces them with their formatted output.
///
/// Returns `true` if successful or `false` if an error occurred in any of the
/// files.
bool processDirectory(FormatterOptions options, Directory directory) {
  options.reporter.showDirectory(directory.path);

  var success = true;
  var shownHiddenPaths = Set<String>();

  for (var entry in directory.listSync(
      recursive: true, followLinks: options.followLinks)) {
    var relative = p.relative(entry.path, from: directory.path);

    if (entry is Link) {
      options.reporter.showSkippedLink(relative);
      continue;
    }

    if (entry is! File || !entry.path.endsWith(".dart")) continue;

    // If the path is in a subdirectory starting with ".", ignore it.
    var parts = p.split(relative);
    var hiddenIndex;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].startsWith(".")) {
        hiddenIndex = i;
        break;
      }
    }

    if (hiddenIndex != null) {
      // Since we'll hide everything inside the directory starting with ".",
      // show the directory name once instead of once for each file.
      var hiddenPath = p.joinAll(parts.take(hiddenIndex + 1));
      if (shownHiddenPaths.add(hiddenPath)) {
        options.reporter.showHiddenPath(hiddenPath);
      }
      continue;
    }

    if (!processFile(options, entry, label: relative)) success = false;
  }

  return success;
}

/// Runs the formatter on [file].
///
/// Returns `true` if successful or `false` if an error occurred.
bool processFile(FormatterOptions options, File file, {String label}) {
  if (label == null) label = file.path;

  var formatter = DartFormatter(
      indent: options.indent,
      pageWidth: options.pageWidth,
      fixes: options.fixes);
  try {
    var fileContent = file.readAsStringSync();
    var content = _commentFormatterOff(fileContent);
    var source = SourceCode(content, uri: file.path);
    options.reporter.beforeFile(file, label);
    var output = formatter.formatSource(source);
    output = SourceCode(_uncommentFormatterOff(output.text),
        isCompilationUnit: output.isCompilationUnit,
        selectionLength: output.selectionLength,
        selectionStart: output.selectionStart,
        uri: output.uri);
    options.reporter
        .afterFile(file, label, output, changed: fileContent != output.text);
    return true;
  } on FormatterException catch (err) {
    var color = Platform.operatingSystem != "windows" &&
        stdioType(stderr) == StdioType.terminal;

    stderr.writeln(err.message(color: color));
  } on UnexpectedOutputException catch (err) {
    stderr.writeln('''Hit a bug in the formatter when formatting $label.
$err
Please report at github.com/dart-lang/dart_style/issues.''');
  } catch (err, stack) {
    stderr.writeln('''Hit a bug in the formatter when formatting $label.
Please report at github.com/dart-lang/dart_style/issues.
$err
$stack''');
  }

  return false;
}

const _offSectionPrefix = '//';

String _commentFormatterOff(String text) {
  var off = false;
  var output = StringBuffer();
  for (var line in LineSplitter.split(text)) {
    if (line.trim() == '// @formatter:off') {
      off = true;
    } else if (line.trim() == '// @formatter:on') {
      off = false;
    } else if (off) {
      output.writeln('$_offSectionPrefix$line');
    }
    output.writeln(line);
  }
  return output.toString();
}

String _uncommentFormatterOff(String text) {
  var off = false;
  var output = StringBuffer();
  var iter = LineSplitter.split(text).iterator;

  while (iter.moveNext()) {
    var line = iter.current;
    if (line.trim() == '// @formatter:off') {
      off = true;
      output.writeln(line);
    } else if (line.trim() == '// @formatter:on') {
      off = false;
      output.writeln(line);
    } else if (off) {
      output.writeln(line.substring(_offSectionPrefix.length));
      iter.moveNext();
    } else {
      output.writeln(line);
    }
  }
  return output.toString();
}
