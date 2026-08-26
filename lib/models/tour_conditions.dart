/// 조건 입력 화면에서 사용자가 고른 여행 조건입니다. (SPEC §4-2)
///
/// Perplexity 프롬프트의 INPUT SLOTS 를 채우는 데 사용합니다.
class TourConditions {
  int groupSize; // 인원 1~10
  String gender; // 남성/여성/혼성/무관
  int ageGroup; // 대표 나이(예: 20 => 20대). 연령 필터에 사용.
  String duration; // 반나절/1일/1박2일
  int budgetPerPerson; // 1인 예산(원)
  Set<String> themes; // 자연/역사/카페/포토스팟/맛집
  String companionType; // 혼자/친구/커플/가족/부모님
  String travelStyle; // 계획/즉흥
  String nationality; // 내국인/외국인

  TourConditions({
    this.groupSize = 2,
    this.gender = '무관',
    this.ageGroup = 20,
    this.duration = '1일',
    this.budgetPerPerson = 30000,
    Set<String>? themes,
    this.companionType = '친구',
    this.travelStyle = '계획',
    this.nationality = '내국인',
  }) : themes = themes ?? <String>{};

  bool get isForeigner => nationality == '외국인';
  bool get isSenior => ageGroup >= 60;
  bool get isMinor => ageGroup < 20;
  bool get isSpontaneous => travelStyle == '즉흥';
  bool get hasChild => companionType == '가족';
  bool get isCouple => companionType == '커플';

  /// 기간 문자열을 대략적인 시간(hours)으로 환산합니다.
  int get durationHours {
    switch (duration) {
      case '반나절':
        return 4;
      case '1박2일':
        return 16;
      case '1일':
      default:
        return 8;
    }
  }

  /// "최근 추천 코스 다시 보기" 카드 등에 보여줄 한 줄 요약입니다.
  String get summaryText {
    final budgetMan = (budgetPerPerson / 10000).toStringAsFixed(0);
    final themeText = themes.isEmpty ? '테마 무관' : themes.join('·');
    return '$groupSize명 · $duration · $budgetMan만원 · $themeText';
  }

  /// 프롬프트에 넣을 요약 맵입니다.
  Map<String, dynamic> toPromptSlots() => {
        'gender': gender,
        'age_group': '${ageGroup}s',
        'group_size': groupSize,
        'duration_hours': durationHours,
        'budget_per_person': budgetPerPerson,
        'companion_type': companionType,
        'travel_style': travelStyle,
        'preferred_mood': themes.join(', '),
        'nationality': isForeigner ? 'US' : 'KR',
      };
}
