import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/widgets/course_stop_card.dart';

/// #11 회귀 방지: 코스 내비 하단 스탬프 카드는 고정 높이(가로 ListView) 안에서
/// 장소명이 아주 길어도 세로(BOTTOM) 오버플로우가 나면 안 됩니다.
///
/// 실기기에서 "BOTTOM OVERFLOWED BY 11 PIXELS" 가 재발한 지점으로,
/// 이전 구현(Spacer + 고정 높이 Column)에서는 긴 이름이 2줄이 되면 넘쳤습니다.
void main() {
  // 실기기 유사: 하단 리스트 높이(128) 제약 + 시스템 글꼴 확대(textScaler).
  // 재현 조건 — 이전 구현(Spacer + 고정 높이)은 글꼴 배율 1.15 이상에서
  // 긴 이름이 2줄이 되며 "BOTTOM OVERFLOWED BY 11 PIXELS" 가 발생했습니다.
  Widget harness(String placeName, {double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SizedBox(
            height: 128,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              children: [
                CourseStopCard(
                  index: 1,
                  placeName: placeName,
                  duration: '약 40분 소요',
                  visited: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  const longName = '부산광역시 영도구 흰여울문화마을 절영해안산책로 무지개계단 전망대 포토존';

  testWidgets('30자+ 장소명 + 글꼴 확대(1.3)에서도 세로 오버플로우가 없다',
      (tester) async {
    expect(longName.length, greaterThan(30));

    await tester.pumpWidget(harness(longName, textScale: 1.3));
    await tester.pump();

    // 오버플로우가 발생하면 렌더링 중 예외가 잡힙니다.
    expect(tester.takeException(), isNull);
    expect(find.byType(CourseStopCard), findsOneWidget);
  });

  testWidgets('글꼴 확대 1.5 극단값에서도 오버플로우가 없다', (tester) async {
    await tester.pumpWidget(harness(longName, textScale: 1.5));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('기본 배율 + 짧은 장소명도 정상 렌더된다', (tester) async {
    await tester.pumpWidget(harness('태종대'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
