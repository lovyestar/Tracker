import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/constants/messages_ko.dart';

/// 영매기 대사 상수 무결성 테스트입니다. (SPEC §8-2)
void main() {
  group('MessagesKo 무결성', () {
    test('고정 대사에 빈 문자열이 없다', () {
      for (final line in MessagesKo.allFixedLines) {
        expect(line.trim().isNotEmpty, isTrue);
      }
    });

    test('시간대별 인사 로직이 SPEC §6 과 일치한다', () {
      expect(MessagesKo.greetingForHour(8), MessagesKo.greetingMorning);
      expect(MessagesKo.greetingForHour(12), MessagesKo.greetingLunch);
      expect(MessagesKo.greetingForHour(18), MessagesKo.greetingEvening);
      expect(MessagesKo.greetingForHour(21), MessagesKo.greetingNight);
      expect(MessagesKo.greetingForHour(3), MessagesKo.greetingLateNight);
      // 14~16시는 첫인사 기본 대사
      expect(MessagesKo.greetingForHour(15), MessagesKo.greetingFirst);
    });

    test('스탬프 대사 {stamp_count} 치환이 동작한다', () {
      final result = MessagesKo.stampGetWith(3);
      expect(result.contains('3개'), isTrue);
      expect(result.contains('{stamp_count}'), isFalse);
    });

    test('휴무 대사 {day} 치환이 동작한다', () {
      final result = MessagesKo.closedDayWith('월');
      expect(result.contains('월요일'), isTrue);
      expect(result.contains('{day}'), isFalse);
    });
  });
}
