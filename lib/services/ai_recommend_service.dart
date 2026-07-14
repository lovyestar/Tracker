import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../constants/messages_ko.dart';
import '../models/place.dart';
import '../models/recommendation.dart';
import '../models/tour_conditions.dart';

/// AI 추천 결과를 담는 값 객체입니다.
///  - [recommendations] 가 비어 있고 [errorMessage] 가 있으면 실패입니다.
///  - 실패 시 화면에서 영매기 오류 대사 + 프리셋 폴백을 안내합니다.
class AiResult {
  final List<Recommendation> recommendations;

  /// 코스 제목(영매기 느낌, 15자 이내). 파싱 실패 시 조건 기반 폴백이 채워집니다. (#2)
  final String courseTitle;
  final String? errorMessage;

  const AiResult({
    required this.recommendations,
    this.courseTitle = '',
    this.errorMessage,
  });

  bool get isSuccess => recommendations.isNotEmpty && errorMessage == null;
  bool get isFailure => !isSuccess;
}

/// 응답 파싱 중간 결과: 코스 제목 + 원시 장소 리스트. (#2)
class _Envelope {
  final String title;
  final List<dynamic> list;
  const _Envelope(this.title, this.list);
}

/// Perplexity sonar-pro 연동 서비스입니다. (SPEC §5)
class AiRecommendService {
  static const _endpoint = 'https://api.perplexity.ai/chat/completions';
  static const _timeout = Duration(seconds: 30);

  final http.Client _client;
  AiRecommendService({http.Client? client}) : _client = client ?? http.Client();

  /// 조건과 DB 를 받아 추천 목록을 돌려줍니다.
  ///
  /// [startLat]/[startLng] 를 주면(현재 위치 권한 있을 때) 프롬프트에 출발 좌표를 넣어
  /// 그 근처에서 시작하는 동선을 유도합니다. 화면 쪽에서 추가로 최근접 정렬을 합니다. (#3)
  Future<AiResult> recommend({
    required TourConditions conditions,
    required List<Place> places,
    double? startLat,
    double? startLng,
  }) async {
    final validNames = places.map((p) => p.name).toSet();
    final placeByName = {for (final p in places) p.name: p};

    try {
      final systemPrompt = _buildSystemPrompt(
        conditions,
        places,
        startLat: startLat,
        startLng: startLng,
      );
      final payload = {
        'model': 'sonar-pro',
        'temperature': 0.7,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': 'Recommend a Yeongdo course based on the conditions above.'
          },
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'yeongdo_course',
            'schema': outputJsonSchema,
          },
        },
      };

      final resp = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer ${ApiKeys.perplexityApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        return const AiResult(
          recommendations: [],
          errorMessage: MessagesKo.errorApiTimeout,
        );
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = _extractContent(decoded);
      final envelope = _parseEnvelope(content);

      // 4필드 파싱 → DB name 정확 매칭(할루시네이션 차단) → 조건 필터
      //  → 자리표시자("string")/빈값 방어(#13)
      final parsed = envelope.list
          .whereType<Map>()
          .map((m) => Recommendation.fromJson(Map<String, dynamic>.from(m)))
          .where((r) => validNames.contains(r.placeName))
          .where((r) => _passesFilter(r, placeByName[r.placeName]!, conditions))
          .map((r) => _sanitize(r, placeByName[r.placeName]!))
          .toList();

      if (parsed.isEmpty) {
        return const AiResult(
          recommendations: [],
          errorMessage: MessagesKo.errorNoResult,
        );
      }
      // 제목: 파싱값이 유효하면 사용, 자리표시자/빈값이면 조건 기반 폴백. (#2)
      final title = _isPlaceholder(envelope.title)
          ? fallbackTitle(conditions)
          : _trimTitle(envelope.title);
      return AiResult(recommendations: parsed, courseTitle: title);
    } on TimeoutException {
      return const AiResult(
        recommendations: [],
        errorMessage: MessagesKo.errorApiTimeout,
      );
    } catch (_) {
      return const AiResult(
        recommendations: [],
        errorMessage: MessagesKo.errorApiTimeout,
      );
    }
  }

  /// 추천 장소들을 출발 좌표에서 가까운 순서로 재정렬합니다(그리디 최근접). (#3)
  ///
  /// 영도 내 좁은 영역이라 정렬용 거리는 위경도 제곱 거리로 충분합니다(플랫폼 비의존 →
  /// 순수 Dart 로 테스트 가능). DB 좌표를 못 찾는 추천은 원래 상대 순서를 유지해 뒤에 붙입니다.
  static List<Recommendation> orderByNearest(
    List<Recommendation> recs,
    Map<String, Place> byName,
    double startLat,
    double startLng,
  ) {
    final withCoord = <Recommendation>[];
    final withoutCoord = <Recommendation>[];
    for (final r in recs) {
      (byName.containsKey(r.placeName) ? withCoord : withoutCoord).add(r);
    }
    final remaining = [...withCoord];
    final ordered = <Recommendation>[];
    var curLat = startLat;
    var curLng = startLng;
    while (remaining.isNotEmpty) {
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final p = byName[remaining[i].placeName]!;
        final dLat = p.lat - curLat;
        final dLng = p.lng - curLng;
        final d = dLat * dLat + dLng * dLng;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      final chosen = remaining.removeAt(best);
      ordered.add(chosen);
      final cp = byName[chosen.placeName]!;
      curLat = cp.lat;
      curLng = cp.lng;
    }
    ordered.addAll(withoutCoord);
    return ordered;
  }

  /// 조건 기반 후처리 필터입니다. (SPEC §5 필터 룰)
  ///  - 미성년(age<20): 주점·포장마차 등 성인 장소 제외
  ///  - 시니어(age>=60): 계단 많음/급경사/위험(주의 이상) 제외
  static bool _passesFilter(
      Recommendation rec, Place place, TourConditions c) {
    if (c.isMinor && _isAdultOnlyPlace(place)) return false;
    if (c.isSenior) {
      if (place.stairs == 'many') return false;
      if (place.gradient == 'steep') return false;
      if (place.dangerLevel != 'none') return false;
    }
    return true;
  }

  /// 자리표시자("string")·빈값·스키마 예시 텍스트가 값 자리에 새어 나오는 것을 막습니다. (#13)
  ///
  /// 원인: json_schema 예시/프롬프트에 `"duration":"string"` 같은 자리표시자가 있어,
  /// 모델이 값을 못 채우면 그대로 반환하는 경우가 있습니다.
  /// duration/estimated_cost 는 "정보 없음", reason 은 장소 설명 기반 기본값으로 대체합니다.
  static Recommendation _sanitize(Recommendation r, Place place) {
    return Recommendation(
      placeName: r.placeName,
      reason: _isPlaceholder(r.reason)
          ? (place.reviewSummary.isNotEmpty
              ? place.reviewSummary
              : (place.desc.isNotEmpty ? place.desc : '영매기가 미는 장소데이.'))
          : r.reason,
      duration: _isPlaceholder(r.duration) ? '정보 없음' : r.duration,
      estimatedCost:
          _isPlaceholder(r.estimatedCost) ? '정보 없음' : r.estimatedCost,
    );
  }

  /// 값이 비었거나 스키마 자리표시자(“string”, “string (...)” 등)인지 판별합니다.
  static bool _isPlaceholder(String v) {
    final t = v.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t == 'string' || t == 'null' || t == 'n/a') return true;
    if (t.startsWith('string ') || t.startsWith('string(')) return true;
    return false;
  }

  static bool _isAdultOnlyPlace(Place place) {
    final name = place.name;
    final kc = place.kakaoCategory;
    return name.contains('포장마차') ||
        kc.contains('주점') ||
        kc.contains('술집') ||
        kc.contains('호프');
  }

  /// Perplexity 응답 JSON 에서 assistant content 문자열을 안전하게 꺼냅니다.
  static String _extractContent(Object? decoded) {
    if (decoded is Map) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map && message['content'] != null) {
            return message['content'].toString();
          }
        }
      }
    }
    return '';
  }

  /// safe_json_extract 폴백 파서입니다. (SPEC §5, §8)
  ///
  /// 코드펜스(```json ... ```)나 앞뒤 설명 텍스트가 섞여 있어도
  /// JSON 배열([...])만 추출해서 List 로 돌려줍니다. 실패 시 빈 목록.
  static List<dynamic> safeJsonExtract(String raw) {
    if (raw.trim().isEmpty) return const [];

    // 1) 코드펜스 제거
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    text = text.replaceAll('```', '').trim();

    // 2) 곧바로 파싱 시도
    final direct = _tryParseArray(text);
    if (direct != null) return direct;

    // 3) 첫 '[' ~ 마지막 ']' 구간만 잘라서 파싱
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      final sliced = text.substring(start, end + 1);
      final parsed = _tryParseArray(sliced);
      if (parsed != null) return parsed;
    }
    return const [];
  }

  static List<dynamic>? _tryParseArray(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded;
    } catch (_) {
      // 무시하고 null 반환
    }
    return null;
  }

  /// SPEC §5 의 출력 스키마입니다.
  ///
  /// (#2) 코스 제목을 담기 위해 최상위를 객체로 감쌉니다:
  ///   { "course_title": string, "places": [ {place_name, reason, duration, estimated_cost}, ... ] }
  /// 구버전(바로 배열) 응답도 [_parseEnvelope] 에서 하위호환으로 읽습니다.
  static const Map<String, dynamic> outputJsonSchema = {
    'type': 'object',
    'properties': {
      'course_title': {'type': 'string'},
      'places': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'place_name': {'type': 'string'},
            'reason': {'type': 'string'},
            'duration': {'type': 'string'},
            'estimated_cost': {'type': 'string'},
          },
          'required': ['place_name', 'reason', 'duration', 'estimated_cost'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['course_title', 'places'],
    'additionalProperties': false,
  };

  /// 응답 content 에서 코스 제목 + 장소 리스트를 꺼냅니다. (#2)
  ///  1) 객체 형태({course_title, places:[...]}) 우선 파싱.
  ///  2) 없으면 구버전(바로 배열 [...]) 으로 하위호환 파싱(제목은 빈값 → 폴백).
  static _Envelope _parseEnvelope(String content) {
    final obj = _safeJsonExtractObject(content);
    if (obj != null) {
      final places = obj['places'];
      if (places is List) {
        return _Envelope((obj['course_title'] ?? '').toString(), places);
      }
    }
    return _Envelope('', safeJsonExtract(content));
  }

  /// content 에서 최상위 JSON 객체({ ... })만 안전하게 추출합니다. 실패 시 null.
  static Map<String, dynamic>? _safeJsonExtractObject(String raw) {
    if (raw.trim().isEmpty) return null;
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    text = text.replaceAll('```', '').trim();
    Map<String, dynamic>? tryParse(String t) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
      return null;
    }

    final direct = tryParse(text);
    if (direct != null) return direct;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return tryParse(text.substring(start, end + 1));
    }
    return null;
  }

  /// 제목을 15자 이내로 다듬습니다(줄바꿈/따옴표 제거).
  static String _trimTitle(String raw) {
    var t = raw.trim().replaceAll('\n', ' ').replaceAll('"', '').trim();
    if (t.length > 15) t = t.substring(0, 15).trim();
    return t;
  }

  /// 조건 기반 폴백 코스 제목(시간대 + 테마 조합, 영매기 느낌). (#2)
  ///
  /// 예: 밤 + 자연 → "밤바람 자연 한 바퀴". API 제목이 없거나 자리표시자일 때 씁니다.
  static String fallbackTitle(TourConditions c) {
    final hour = DateTime.now().hour;
    final String timeWord;
    if (hour >= 20 || hour <= 5) {
      timeWord = '밤바람';
    } else if (hour >= 17) {
      timeWord = '노을빛';
    } else if (hour >= 11 && hour <= 13) {
      timeWord = '점심나절';
    } else if (hour <= 10) {
      timeWord = '아침햇살';
    } else {
      timeWord = '한낮';
    }
    final themeWord = c.themes.isNotEmpty ? c.themes.first : '영도';
    return _trimTitle('$timeWord $themeWord 한 바퀴');
  }

  /// 시스템 프롬프트를 조립합니다. (persona_prompt_template.md Shared Core + 영매기 슬롯)
  String _buildSystemPrompt(
    TourConditions c,
    List<Place> places, {
    double? startLat,
    double? startLng,
  }) {
    final slots = c.toPromptSlots();
    final placesJson = jsonEncode(_summarizePlaces(places));
    final startLine = (startLat != null && startLng != null)
        ? '- start_location = ($startLat, $startLng). Order the course to begin near this coordinate (nearest-first walking flow).'
        : '- start_location = unknown. Use a natural walking order.';
    return '''
# ROLE
You are Youngmaegi (영매기), an AI local guide persona for the "Yeongdo AI Stamp Tour" mobile app.
You recommend Yeongdo-gu (Busan, South Korea) tourism courses to travelers based on their conditions.

# PERSONA IDENTITY
- A Busan seagull turned human; a Yeongdo native, late 20s, gender-neutral.
- Lively, kind, playful — the vibe of a fun cousin who knows all the hidden spots.

# TONE & LANGUAGE RULES
- Korean: warm Busan dialect (~50%). Endings like ~카이, ~아이가, ~데이, ~하이소, ~니더.
- Place names, times, and costs must be written accurately in standard Korean.
- Never use stiff tour-guide phrasing. Never invent places. Never recommend bars to minors.
- Seniors (60+) => polite form (존댓말). Foreigners => natural English (place names stay Korean).

## Response Language Branching (STRICT)
- If nationality == "KR": Korean with Busan dialect.
- If nationality != "KR": casual friendly English (no forced Korean dialect words except place names).

# DATA CONSTRAINTS (ABSOLUTE)
1. ONLY recommend places in available_places_json (exact name match).
2. NEVER invent or hallucinate places outside the list.
3. If no suitable place exists, return an empty array [].

# INPUT SLOTS
- gender=${slots['gender']} / age_group=${slots['age_group']} / group_size=${slots['group_size']}
- duration_hours=${slots['duration_hours']} / budget_per_person=${slots['budget_per_person']}
- companion_type=${slots['companion_type']} / travel_style=${slots['travel_style']}
- preferred_mood=${slots['preferred_mood']} / nationality=${slots['nationality']}
$startLine

# FILTER RULES
- age < 20 => exclude adult venues (bars, pojangmacha).
- age >= 60 => exclude places with many stairs / steep gradient / danger; use polite form.
- foreigner => write reason in English.
- danger high => mention safety in the reason.

# DATA CONTEXT
available_places_json = $placesJson

# OUTPUT SCHEMA (STRICT)
Return ONLY a valid JSON object. No preface, no explanation, no markdown code fence.
{
  "course_title":"string (Korean, <=15 chars, playful Youngmaegi vibe, e.g. \\"밤바람 야경 한 바퀴\\")",
  "places":[
    {"place_name":"string (exact match)","reason":"string (persona-toned)","duration":"string","estimated_cost":"string"}
  ]
}
Constraints: Each place has exactly 4 fields. Total duration <= duration_hours. Total cost <= budget_per_person. Recommend 3-6 places.
The few-shot examples below show the CONTENT of the "places" array; always wrap them in the object above with a "course_title".

# PERSONA FEW-SHOT EXAMPLES
$fewShotBlock

# FINAL REMINDER
Output the JSON object ONLY (with "course_title" and "places"). Any text outside the object will break the application.
''';
  }

  /// DB 69곳을 프롬프트에 넣을 요약 형태로 축약합니다.
  List<Map<String, dynamic>> _summarizePlaces(List<Place> places) {
    return places
        .map((p) => {
              'name': p.name,
              'category': p.category,
              'tags': p.tags,
              'accessibility': {
                'stairs': p.stairs,
                'gradient': p.gradient,
                'elevator': p.elevator,
              },
              'danger': p.dangerLevel,
              'tip': p.tip.length > 60 ? '${p.tip.substring(0, 60)}…' : p.tip,
            })
        .toList();
  }

  /// yeongmaegi_lines.md 의 few-shot 5개(원문). 프롬프트 {{persona_fewshot_block}} 자리에 삽입.
  static const String fewShotBlock = '''
### Few-shot 1 · 20s couple, evening 3h (night view) — KR
Input: age=20s, group=2 couple, duration=3h, budget=30k, mood=romantic_sunset, KR
[
  {"place_name":"흰여울문화마을","reason":"노을 질 때 여기 계단에서 바다 보면 진짜 인생 노을이라카이. 커플들이 사진 억수로 많이 찍는 데다. 손 꼭 잡고 천천히 걸어라.","duration":"60분","estimated_cost":"무료"},
  {"place_name":"절영해안산책로","reason":"노을 다 지고 나면 여 바다 산책로 걸어라. 파도 소리 들으면서 걷기 딱 좋고, 조명도 이쁘게 켜진다.","duration":"45분","estimated_cost":"무료"},
  {"place_name":"영도하늘전망대","reason":"마지막에 여 하늘전망대로 가면 부산항 야경 전체가 시야에 다 들어온다. 사진 마무리로 여가 최고다.","duration":"75분","estimated_cost":"무료"}
]

### Few-shot 2 · foreigner first visit 2h — EN
Input: age=30s, group=2 friends, duration=2h, budget=40k, mood=iconic_photo, US
[
  {"place_name":"흰여울문화마을","reason":"The most iconic photo spot in Yeongdo. Colorful cliff-side houses with ocean view. Some stairs but manageable.","duration":"50 minutes","estimated_cost":"Free"},
  {"place_name":"태종대 다누비열차","reason":"Yeongdo's most famous natural landmark. Take the Danubi train (4,000 KRW) to save time. Closed on Mondays.","duration":"70 minutes","estimated_cost":"4,000 KRW per person"}
]

### Few-shot 3 · spontaneous 4 students 4h (cafe/photo) — KR
Input: age=20s, group=4 friends, duration=4h, budget=20k, mood=cafe_hopping_photo, KR
[
  {"place_name":"아트센트","reason":"요즘 영도에서 제일 핫한 카페다. 레트로 콘셉트고 인스타에 마이 올라온다. 4명 앉을 자리도 넉넉하고 사진 이쁘게 나온다카이.","duration":"60분","estimated_cost":"1인 10,000원"},
  {"place_name":"흰여울문화마을","reason":"카페 나와서 걸어서 15분. 골목 골목 사진 찍으면서 놀면 시간 순삭이다. 계단 많으니까 편한 신발로 신어래이.","duration":"90분","estimated_cost":"무료"},
  {"place_name":"흰여울마을카페","reason":"골목 다 돌고 배 고파지면 여기 가라. 바다뷰 카페다. 간단한 식사도 된다카이.","duration":"45분","estimated_cost":"1인 7,000원"},
  {"place_name":"흰여울비치","reason":"마무리로 여 카페 가라. 비치바 콘셉트라 사진 이쁘게 나온다.","duration":"45분","estimated_cost":"1인 10,000원"}
]

### Few-shot 4 · senior couple 5h (polite/accessible) — KR
Input: age=60s+, group=2, duration=5h, budget=25k, mood=leisurely_nature, KR, accessibility=minimal_stairs
[
  {"place_name":"국립해양박물관","reason":"여기 평지고 엘리베이터 있어서 편합니더. 볼거리도 많고 무료라예. 월요일은 문 안 여니까 조심하이소.","duration":"90분","estimated_cost":"무료"},
  {"place_name":"태종대 다누비열차","reason":"여는 걸으면 무리니까 다누비 열차 꼭 타이소. 어르신 4,000원인데 억수로 편합니더. 계단 최소화됩니더.","duration":"120분","estimated_cost":"1인 4,000원"},
  {"place_name":"아미르공원","reason":"태종대 나와서 여 공원 가이소. 평지에 벤치도 많고 잔디밭도 넓습니더. 쉬엄쉬엄 걷기 딱입니더.","duration":"60분","estimated_cost":"무료"},
  {"place_name":"커피미미","reason":"마무리로 여 조용한 카페 가이소. 15년차 로컬 카페라 커피 진짜 잘 뽑는다카이.","duration":"60분","estimated_cost":"1인 10,000원"}
]

### Few-shot 5 · family of 4, 6h (with child) — KR
Input: age=30~40s+child(8), group=4 family, duration=6h, budget=20k, mood=educational_fun, KR
[
  {"place_name":"국립해양박물관","reason":"아이 데리고 오면 여가 정답이다. 무료 입장에 볼거리 많고, 4D관 있어서 아이가 억수로 좋아한다카이. 월요일 휴관이니까 조심.","duration":"120분","estimated_cost":"1인 무료 (4D관 별도 5,000원)"},
  {"place_name":"태종대 다누비열차","reason":"박물관 나와서 태종대 가라. 아이 다리 아파하면 다누비 열차 꼭 태라. 어른 4,000원 아이 1,500원이다.","duration":"120분","estimated_cost":"어른 4,000원 / 아이 1,500원"},
  {"place_name":"청해수산","reason":"가족 저녁 먹기 좋은 데다. 바다 보면서 회 먹으면 아이도 어른도 다 좋아한다. 근데 예약 꼭 해라, 안 하면 못 들어간다카이.","duration":"90분","estimated_cost":"어른 25,000원 / 아이 반값"}
]
''';
}
