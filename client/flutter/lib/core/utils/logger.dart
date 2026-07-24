import 'package:logger/logger.dart';

/// Глобальный логгер ЧАРО
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 100,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
  level: Level.debug,
);
