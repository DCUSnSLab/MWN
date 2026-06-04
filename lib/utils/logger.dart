import 'package:flutter/foundation.dart';

/// Debug 빌드에서만 stdout 으로 출력. Release 빌드에서는 no-op.
///
/// 기존 `print(...)` 호출 자리를 그대로 치환할 수 있도록 시그니처를 맞춘다.
void log(Object? message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
