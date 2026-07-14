/// 영매기(영도 갈매기 페르소나) 대사 모음입니다. (SPEC §6)
///
/// context/yeongmaegi_lines.md 의 대사를 **원문 그대로** 상수로 수록했습니다.
/// 초보자를 위한 설명:
///  - 화면 코드에서는 여기 상수를 가져다 말풍선/스낵바에 그대로 씁니다.
///  - 문자열을 이 파일에서만 관리하면 대사 수정이 쉽습니다.
class MessagesKo {
  MessagesKo._();

  // ---------------------------------------------------------------------------
  // 1. 인사 (Greeting)
  // ---------------------------------------------------------------------------
  static const String greetingFirst =
      '어이~ 영도 놀러 왔나? 내 영매기다. 부산 갈매기 중에서도 영도 토박이라 아이가. 우야든지 영도 구석구석 재밌게 보고 가라꼬 내가 안내해줄끼다. 오늘 뭐 하고 싶노?';

  /// 첫 실행 화면에 표시할 축약형 인사(음성/전체 대사는 [greetingFirst] 유지). (#7)
  static const String greetingFirstShort = '어이~ 영도 놀러 왔나? 내 영매기다. 오늘 뭐 하고 싶노?';
  static const String greetingMorning =
      '아침부터 부지런하네. 영도 아침 바다 억수로 이쁘다. 퍼뜩 나가자.';
  static const String greetingLunch = '점심 때 왔네. 배 안 고프나? 맛집부터 갈까?';
  static const String greetingEvening =
      '저녁 왔나. 노을 보러 가자. 영도 노을이 부산에서 제일 이쁘다카이.';
  static const String greetingNight = '밤에 왔노. 영도 밤바다 안 봐봤제? 오늘 제대로 보여주꾸마.';
  static const String greetingLateNight = '이 시간까지 안 자고 뭐 하노. 밤 산책이면 안전한 데로 안내할끼다.';
  static const String greetingRainy = '허어 오늘 비 온다. 실내 카페 위주로 안내해주꾸마. 우산 챙겼제?';

  // 상황 추천(말풍선 탭) 신규 사유 문구. (#5) — 기존 대사와 별개.
  static const String situationNight = '밤에는 역시 영도 야경이 최고 아이가! 이 코스로 밤바다 제대로 보고 가라.';
  static const String situationEvening = '해 질 때 딱 왔네. 노을 지는 코스로 안내해주꾸마. 사진 억수로 이쁘게 나온다.';
  static const String situationLunch = '점심 때는 배부터 채워야제! 영도 카페·먹거리 도는 코스로 가자.';
  static const String situationMorning = '아침에는 살살 걷기 좋은 힐링 코스가 딱이다. 상쾌하게 시작하자!';
  static const String situationAfternoon = '낮에는 발길 닿는 대로 즉흥 탐방이 재밌다카이. 이 코스 한 번 봐라!';

  /// 현재 시간대에 맞는 상황 추천 사유 문구를 돌려줍니다. (#5)
  static String situationReasonForHour(int hour) {
    if (hour >= 20 || hour <= 5) return situationNight;
    if (hour >= 17 && hour <= 19) return situationEvening;
    if (hour >= 11 && hour <= 13) return situationLunch;
    if (hour >= 6 && hour <= 10) return situationMorning;
    return situationAfternoon;
  }

  /// 시간대별 인사 로직 (SPEC §6).
  ///  - 06:00~10:59 아침 / 11:00~13:59 점심 / 17:00~19:59 저녁
  ///  - 20:00~23:59 야간 / 00:00~05:59 심야
  ///  - 14:00~16:59(그 외)는 첫인사 기본 대사
  static String greetingForHour(int hour) {
    if (hour >= 6 && hour <= 10) return greetingMorning;
    if (hour >= 11 && hour <= 13) return greetingLunch;
    if (hour >= 17 && hour <= 19) return greetingEvening;
    if (hour >= 20 && hour <= 23) return greetingNight;
    if (hour >= 0 && hour <= 5) return greetingLateNight;
    return greetingFirst;
  }

  // ---------------------------------------------------------------------------
  // 2. 추천 (Recommendation)
  // ---------------------------------------------------------------------------
  static const String recommendStart = '쫌만 기다리면 딱 맞는 코스 뽑아주꾸마.';
  static const String recommendSpontaneous =
      '계획 없이 왔나? 마 좋다. 즉흥으로 갈수록 재밌는 게 여행이라카이.';
  static const String recommendPlanned = '시간이랑 조건 딱 정해서 왔네. 알겠다, 낭비 없이 짜주꾸마.';
  static const String recommendRichBudget =
      '와, 니 돈 많네! 이 정도믄 좀 특별한 데도 넣을 수 있겠구마이.';
  static const String recommendTightBudget =
      '좀 빡세네. 근데 걱정 마라, 꽁짜도 억수로 좋은 데 많다.';

  // ---------------------------------------------------------------------------
  // 3. 응답 (User Interaction)
  // ---------------------------------------------------------------------------
  static const String replyLocation = '지금 니 있는 데서 걸어가면 이 정도 걸린다.';
  static const String replyCost = '이 정도 든다. 카드 되고 현금도 받는다. 걱정 마라.';
  static const String replyOther = '아 여기 별로가? 그라믄 여기는 어떻노?';
  static const String replyThanks = '허어, 뭐 그리 대단한 거라고. 영도 소개하는 게 내 일이다카이.';

  // ---------------------------------------------------------------------------
  // 4. 실패·오류 (Failure & Error)
  // ---------------------------------------------------------------------------
  static const String errorNoResult =
      '아이고 미안타. 니 조건이 좀 빡세서 딱 맞는 데가 없다. 조건 쪼매 풀어볼래?';
  static const String errorGpsIndoor =
      '잠깐, 니 지금 실내 있나? GPS가 안 잡히네. 밖으로 나가서 다시 눌러봐라.';
  static const String errorApiTimeout = '허어, 지금 통신이 좀 느리네. 쫌만 있다가 다시 눌러봐라.';
  static const String errorHallucination =
      '그 장소는 내 데이터에 없다카이. 내가 아는 데만 확실히 안내해주는 거라 미안하다.';
  static const String errorOutOfRange = '미안하다, 거는 영도가 아니라.';

  /// N요일 휴무 대사. {day} 자리에 요일을 넣어 사용합니다.
  static const String errorClosedDay =
      '아고! 오늘 {day}요일이제 참? 오늘 문 안 여네. 그라믄 대신 여긴 어떻노?';
  static const String errorBridgeOpen = '아 지금 영도대교 도개 시간이다. 우회 버스 타는 게 낫다.';

  // ---------------------------------------------------------------------------
  // 5. 스탬프·완주 (Stamp & Complete)
  // ---------------------------------------------------------------------------
  /// 스탬프 획득 대사. {stamp_count} 자리에 지금까지 모은 개수를 넣어 사용합니다.
  static const String stampGet =
      '오, 도착했네! 스탬프 찍혔다. {stamp_count}개 모았다카이, 잘하고 있다!';
  static const String stampFirst = '첫 스탬프다! 여행 시작이라카이.';
  static const String stampLastOne = '한 개만 더 찍으면 완주다. 퍼뜩 마지막까지 가자!';
  static const String complete =
      '완주 축하한데이! 니 진짜 대단타카이. 영도 구석구석 다 돌았네. 완주 카드 받아가라.';
  static const String completeShare = '이 카드 SNS에 올려봐라. #영도트래커 태그 달아주면 좋고.';

  // ---------------------------------------------------------------------------
  // 6. 특수 상황 (Special Cases)
  // ---------------------------------------------------------------------------
  static const String specialWithChild = '아 아이랑 왔네. 그라믄 계단 적고 재밌는 데로 짜주꾸마.';
  static const String specialCouple = '커플이가? 노을 코스 어떻노? 인생샷 찍기도 딱이다.';
  static const String specialSenior =
      '아고, 어르신 오셨네예. 걷기 편한 코스로 안내해드리겠습니더. 다누비 열차 있으니까 걱정 마시고예.';
  static const String specialPhotoLover = '사진 찍는 거 좋아하나? 마 그라믄 내가 인스타 성지만 뽑아주꾸마.';
  static const String specialMinorBar = '미안한데 여기는 쫌 그릏다. 니 나이대는 다른 데 추천해줄게.';

  // ---------------------------------------------------------------------------
  // 7. 코스 만들기 (Add Course) — 신규 문구
  // ---------------------------------------------------------------------------
  /// 코스 추가 화면 위치 입력 안내.
  static const String addCourseLocationHint =
      '여기는 어디고? 지도에서 콕 찍든가, 영도 명소에서 골라봐라.';

  /// 위치 지정 화면(지도 피커) 상단 안내.
  static const String addCoursePickOnMap = '지도에서 니가 정할 자리 콕 찍어봐라!';

  /// 위치 지정 화면에서 좌표를 찍은 뒤 확인 안내.
  static const String addCoursePickConfirm = '여 맞나? 맘에 들면 이 자리로 등록해라.';

  /// 사진 업로드 안내.
  static const String addCoursePhotoHint =
      '니가 찍은 영도 사진 자랑해봐라. 최대 10장까지 된데이.';

  /// 경유지(다중 위치) 목록 입력 안내. (#1)
  static const String addCourseWaypointHint =
      '코스는 순서대로 들를 자리로 만든데이.\n지도나 명소에서 최소 4곳은 골라야 등록된다카이.';

  /// 경유지가 4곳 미만일 때 안내. (#1)
  static const String addCourseWaypointTooFew =
      '아직 부족하데이. 코스는 최소 4곳은 있어야 재밌다 아이가. 자리 더 골라봐라!';

  /// 사진이 최대치일 때 안내. (#2)
  static const String addCoursePhotoMax = '사진은 최대 10장까지 된데이.';

  /// 명소에서 선택 화면 검색 안내.
  static const String addCoursePlaceSearchHint =
      '영도 명소 중에 골라봐라. 이름이나 카테고리로 찾으면 된데이.';

  // ---------------------------------------------------------------------------
  // 8. 내비게이션 모드(진행 중 코스 잠금) — 신규 문구
  // ---------------------------------------------------------------------------
  /// 진행 중 코스가 있는데 다른 코스를 시작하려 할 때 안내.
  static const String navLockGuide =
      '지금 가는 코스부터 마치라, 아이가! 딴 코스 가고 싶으믄 지금 경로부터 취소해야 된데이.';

  /// 진행 중 코스 경로 취소 확인 안내.
  static const String navCancelConfirm =
      '지금 가는 코스 취소할까? 여태 찍은 스탬프 기록은 그대로 남으니까 걱정 마라.';

  // ---------------------------------------------------------------------------
  // 9. 알림 센터 (Notifications) — 신규 문구
  // ---------------------------------------------------------------------------
  /// 알림 기록이 하나도 없을 때 빈 상태 안내(영매기 말투).
  static const String notificationsEmpty =
      '아직 알림이 없데이. 코스 돌고 스탬프 찍으면 여기 착착 쌓인다카이!';

  /// 스탬프 대사에서 {stamp_count} 를 실제 개수로 치환합니다.
  static String stampGetWith(int count) =>
      stampGet.replaceAll('{stamp_count}', '$count');

  /// 휴무 대사에서 {day} 를 실제 요일로 치환합니다.
  static String closedDayWith(String day) =>
      errorClosedDay.replaceAll('{day}', day);

  /// 무결성 테스트용: 모든 고정 대사 목록(빈 문자열이 없어야 함).
  static const List<String> allFixedLines = [
    greetingFirst,
    greetingMorning,
    greetingLunch,
    greetingEvening,
    greetingNight,
    greetingLateNight,
    greetingRainy,
    recommendStart,
    recommendSpontaneous,
    recommendPlanned,
    recommendRichBudget,
    recommendTightBudget,
    replyLocation,
    replyCost,
    replyOther,
    replyThanks,
    errorNoResult,
    errorGpsIndoor,
    errorApiTimeout,
    errorHallucination,
    errorOutOfRange,
    errorClosedDay,
    errorBridgeOpen,
    stampGet,
    stampFirst,
    stampLastOne,
    complete,
    completeShare,
    specialWithChild,
    specialCouple,
    specialSenior,
    specialPhotoLover,
    specialMinorBar,
  ];
}
