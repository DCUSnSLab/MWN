import 'package:flutter/material.dart';

/// 비동기 데이터 화면의 로딩 / 에러(+재시도) / 콘텐츠 상태를 일관되게 렌더링하는 공용 위젯.
///
/// 화면마다 중복되던 `if (isLoading) 스피너 / if (error) 에러위젯 / else 콘텐츠`
/// 보일러플레이트를 대체한다.
///
/// ```dart
/// AsyncView(
///   isLoading: provider.isLoading,
///   error: provider.error,
///   onRetry: provider.reload,
///   builder: (context) => MyContent(...),
/// )
/// ```
class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.builder,
    this.errorTitle = '오류가 발생했습니다',
    this.retryLabel = '다시 시도',
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final String errorTitle;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      );
    }
    return builder(context);
  }
}
