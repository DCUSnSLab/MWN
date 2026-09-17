import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwn/utils/responsive.dart';

/// 논리 크기 + DPR 로 폰/태블릿 뷰포트를 흉내낸다.
/// (flutter_test 기본 뷰포트는 800x600 이라 shortestSide 가 정확히 600 —
///  태블릿으로 판정되므로 테스트마다 명시적으로 지정해야 한다.)
void _setViewport(WidgetTester tester, Size logical, {double dpr = 2}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logical * dpr;
  addTearDown(tester.view.reset);
}

const _phone = Size(375, 812); // iPhone 11 Pro
const _tablet = Size(1024, 1366); // iPad Pro 12.9" 세로

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('isTabletDevice / resolveDesignSize', () {
    testWidgets('폰 뷰포트 → iPhone 기준 designSize', (tester) async {
      _setViewport(tester, _phone, dpr: 3);
      expect(isTabletDevice(), isFalse);
      expect(resolveDesignSize(), const Size(375, 812));
    });

    testWidgets('태블릿 뷰포트 → iPad 기준 designSize', (tester) async {
      _setViewport(tester, _tablet);
      expect(isTabletDevice(), isTrue);
      expect(resolveDesignSize(), const Size(768, 1024));
    });

    testWidgets('판정 기준은 폭이 아니라 shortestSide 다', (tester) async {
      // 가로로 눕힌 폰(812x375): 폭은 넓지만 shortestSide 375 → 폰
      _setViewport(tester, const Size(812, 375), dpr: 3);
      expect(isTabletDevice(), isFalse);
    });
  });

  group('isTablet(context)', () {
    testWidgets('MediaQuery shortestSide 기준으로 판정한다', (tester) async {
      _setViewport(tester, _tablet);
      late bool result;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        result = isTablet(context);
        return const SizedBox();
      })));
      expect(result, isTrue);
    });
  });

  group('TabletConstrained', () {
    const key = Key('content');
    final innerConstrainedBox = find.descendant(
      of: find.byType(TabletConstrained),
      matching: find.byType(ConstrainedBox),
    );

    testWidgets('폰: no-op — 자식이 전체 폭을 그대로 채운다', (tester) async {
      _setViewport(tester, _phone, dpr: 3);
      await tester.pumpWidget(_host(
        const TabletConstrained(child: SizedBox.expand(key: key)),
      ));
      expect(tester.getSize(find.byKey(key)).width, _phone.width);
      expect(innerConstrainedBox, findsNothing);
    });

    testWidgets('태블릿: 기본 kListMaxWidth 로 폭이 제한되고 가운데 정렬된다',
        (tester) async {
      _setViewport(tester, _tablet);
      await tester.pumpWidget(_host(
        const TabletConstrained(child: SizedBox.expand(key: key)),
      ));
      expect(tester.getSize(find.byKey(key)).width, kListMaxWidth);
      expect(
        tester.getTopLeft(find.byKey(key)).dx,
        (_tablet.width - kListMaxWidth) / 2,
      );
      expect(innerConstrainedBox, findsOneWidget);
    });

    testWidgets('태블릿: 명시한 maxWidth(kFormMaxWidth) 를 따른다', (tester) async {
      _setViewport(tester, _tablet);
      await tester.pumpWidget(_host(
        const TabletConstrained(
          maxWidth: kFormMaxWidth,
          child: SizedBox.expand(key: key),
        ),
      ));
      expect(tester.getSize(find.byKey(key)).width, kFormMaxWidth);
    });

    testWidgets('태블릿: SingleChildScrollView 의 child 로 써도 세로축은 열려 있다',
        (tester) async {
      _setViewport(tester, _tablet);
      await tester.pumpWidget(_host(
        SingleChildScrollView(
          child: TabletConstrained(
            maxWidth: kFormMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Container(key: key, height: 2000)],
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byKey(key));
      expect(size.width, kFormMaxWidth);
      expect(size.height, 2000);
    });

    testWidgets('태블릿: RefreshIndicator 안의 ListView 도 폭 제한 + 스크롤 정상',
        (tester) async {
      _setViewport(tester, _tablet);
      await tester.pumpWidget(_host(
        RefreshIndicator(
          onRefresh: () async {},
          child: TabletConstrained(
            child: ListView(
              children: List.generate(
                60,
                (i) => ListTile(key: ValueKey(i), title: Text('row $i')),
              ),
            ),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(ListView)).width, kListMaxWidth);

      await tester.fling(find.byType(ListView), const Offset(0, -800), 2000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey(0)), findsNothing); // 스크롤돼 첫 행이 사라짐
    });
  });
}
