#!/usr/bin/env dart
import 'dart:io';
import 'dart:convert';

const historyFilePath = 'cli_history.json';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help') || arguments.contains('-h')) {
    _showHelp();
    return;
  }
  

  if (arguments.contains('history')) {
    await _showHistory();
    return;
  }

  if (arguments.contains('clean-history')) {
    await _clearHistory();
    return;
  }

  final projectPath = arguments.first;
  if (!_isValidProjectPath(projectPath)) {
    print('Invalid project path. Please provide a valid Flutter project directory.');
    return;
  }

  final verbose = arguments.contains('--verbose');
  
  print('Scanning project at "$projectPath" for print statements...');

  final startTime = DateTime.now();
  final fileStats = await _removePrintStatements(Directory(projectPath), verbose: verbose);
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);

  print('All print statements have been removed successfully.');
  await _logHistory(projectPath, fileStats, duration);
}

void _showHelp() {
  print('''
Usage: remove_print_cli [options] <project_path>

Options:
  --help, -h         Show this help message
  history            Display the history of CLI usage
  clean-history      Clear all history logs
  --verbose          Show detailed logs of file content before and after modifications

Example:
  remove_print_cli /path/to/flutter/project
  remove_print_cli history
  remove_print_cli clean-history
  remove_print_cli /path/to/flutter/project --verbose
''');
}

Future<void> _showHistory() async {
  final historyFile = File(historyFilePath);

  if (!await historyFile.exists()) {
    print('No history found.');
    return;
  }

  final content = await historyFile.readAsString();
  final List<dynamic> history = jsonDecode(content);

  print('==== remove_print_cli History ====');

  for (final entry in history) {
    final timestamp = entry['timestamp'];
    final projectPath = entry['projectPath'];
    final fileStats = entry['fileStats'] as Map<String, dynamic>?;

    print('\nDate: $timestamp');
    print('Project Path: $projectPath');

    if (fileStats != null && fileStats.isNotEmpty) {
      print('Files Processed:');
      for (final file in fileStats.keys) {
        print('  $file: ${fileStats[file]} print statements removed');
      }
    } else {
      print('No files were processed or logged.');
    }
  }
}

Future<void> _clearHistory() async {
  final historyFile = File(historyFilePath);

  if (!await historyFile.exists()) {
    print('No history to clear.');
    return;
  }

  await historyFile.writeAsString('[]', flush: true);
  print('History has been cleared.');
}

bool _isValidProjectPath(String path) {
  final directory = Directory(path);
  final exists = directory.existsSync();
  
  print('Checking directory: $path');
  print('Directory exists: $exists');

  if (!exists) {
    return false;
  }

  // Check for .dart files
  final files = directory.listSync(recursive: true).whereType<File>();
  final dartFiles = files.where((file) => file.path.endsWith('.dart')).toList();
  print('Dart files found: ${dartFiles.length}');

  return dartFiles.isNotEmpty;
}

Future<Map<String, int>> _removePrintStatements(Directory directory, {bool verbose = false}) async {
  final fileStats = <String, int>{};

  final files = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final lines = await file.readAsLines();
    final updatedLines = lines.where((line) => !line.contains(RegExp(r'^\s*print\(.*\);'))).toList();
    final removedCount = lines.length - updatedLines.length;

    if (removedCount > 0) {
      fileStats[file.path] = removedCount;

      // Log the file processing status
      print('Processed: ${file.path} ($removedCount print statements removed)');

      // If verbose flag is set, print detailed file content before and after modification
      if (verbose) {
        print('File Content Before:\n${lines.join('\n')}');
        print('File Content After:\n${updatedLines.join('\n')}');
      }

      await file.writeAsString(updatedLines.join('\n'));
    }
  }

  return fileStats;
}

Future<void> _logHistory(String projectPath, Map<String, int> fileStats, Duration duration) async {
  final logEntry = {
    'timestamp': DateTime.now().toIso8601String(),
    'projectPath': projectPath,
    'fileStats': fileStats,
    'totalStatementsRemoved': fileStats.values.fold(0, (sum, count) => sum + count),
    'duration': '${duration.inSeconds}.${duration.inMilliseconds % 1000} seconds',
  };

  List<dynamic> history = [];
  final historyFile = File(historyFilePath);

  // Read existing history
  if (await historyFile.exists()) {
    final content = await historyFile.readAsString();
    history = jsonDecode(content);
  }

  history.add(logEntry);

  await historyFile.writeAsString(jsonEncode(history), flush: true);
}
