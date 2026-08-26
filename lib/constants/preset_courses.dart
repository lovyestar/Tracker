import '../models/preset_course.dart';
import '../models/recommendation.dart';

/// 영도 코스 11선 (courses_11.md v2 확정본). (SPEC §3, §4-4)
///
/// 모든 place_name 은 assets/yeongdo_tourism_db.json 의 name 과 완전 일치합니다.
/// reason 은 영매기 톤(사투리 50%)이며, 장소명·시간·비용은 표준어로 정확히 적었습니다.
///  - 코스 8: 외국인용 → reason 영어 (place_name 은 한국어 유지)
///  - 코스 9: 시니어용 → 존댓말(~합니더/~하이소)
const List<PresetCourse> kPresetCourses = [
  // 1. 야경 · 20~30대 커플 · 3h · 25,000원 · 계단 중
  PresetCourse(
    id: 1,
    theme: '야경',
    target: '20~30대 커플',
    totalTime: '3시간',
    budget: '25,000원',
    stairs: '중',
    stops: [
      Recommendation(
        placeName: '흰여울문화마을',
        reason: '노을 질 때 여기 계단에서 바다 보면 진짜 인생 노을이라카이. 커플들이 사진 억수로 많이 찍는 데다. 손 꼭 잡고 천천히 걸어라.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '절영해안산책로',
        reason: '노을 다 지고 나면 여 바다 산책로 걸어라. 파도 소리 들으면서 걷기 딱 좋고, 조명도 이쁘게 켜진다.',
        duration: '45분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '영도하늘전망대',
        reason: '마지막에 여 하늘전망대로 가면 부산항 야경 전체가 시야에 다 들어온다. 사진 마무리로 여가 최고다.',
        duration: '75분',
        estimatedCost: '무료',
      ),
    ],
  ),

  // 2. 포토 · 20대 SNS · 4h · 20,000원 · 계단 중~상
  PresetCourse(
    id: 2,
    theme: '포토',
    target: '20대 SNS',
    totalTime: '4시간',
    budget: '20,000원',
    stairs: '중~상',
    stops: [
      Recommendation(
        placeName: '아트센트',
        reason: '요즘 영도에서 제일 핫한 카페다. 레트로 콘셉트고 인스타에 마이 올라온다. 사진 이쁘게 나온다카이.',
        duration: '60분',
        estimatedCost: '1인 10,000원',
      ),
      Recommendation(
        placeName: '흰여울문화마을',
        reason: '카페 나와서 골목 골목 사진 찍으면서 놀면 시간 순삭이다. 계단 많으니까 편한 신발로 신어래이.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '흰여울 해안터널',
        reason: '여 터널 지나면 바다가 확 열린다. 터널 프레임 안에 바다 담아서 찍으면 인생샷이라카이.',
        duration: '30분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '흰여울비치',
        reason: '마무리로 여 비치바 콘셉트 카페 가라. 바다 앞이라 사진 이쁘게 나온다.',
        duration: '60분',
        estimatedCost: '1인 10,000원',
      ),
    ],
  ),

  // 3. 맛집투어 (성인 전용) · 20~40대 · 3~4h · 50,000원 · 계단 하
  PresetCourse(
    id: 3,
    theme: '맛집투어',
    target: '20~40대',
    totalTime: '3~4시간',
    budget: '50,000원',
    stairs: '하',
    adultOnly: true,
    stops: [
      Recommendation(
        placeName: '영도해녀촌',
        reason: '해녀들이 직접 잡은 해산물 파는 데다. 싱싱한 회 한 접시부터 시작하자.',
        duration: '60분',
        estimatedCost: '1인 15,000원',
      ),
      Recommendation(
        placeName: '청해수산',
        reason: '바다 보면서 회 먹기 딱인 데다. 예약 안 하면 자리 없을 수도 있으니 미리 전화해래이.',
        duration: '90분',
        estimatedCost: '1인 30,000원',
      ),
      Recommendation(
        placeName: '영도대교 포장마차거리',
        reason: '마무리는 여 포장마차에서 한잔이라카이. 어른들만 오는 데니까 분위기 제대로다.',
        duration: '60분',
        estimatedCost: '1인 25,000원',
      ),
    ],
  ),

  // 4. 카페순례 · 20~30대 · 5h · 35,000원 · 계단 하
  PresetCourse(
    id: 4,
    theme: '카페순례',
    target: '20~30대',
    totalTime: '5시간',
    budget: '35,000원',
    stairs: '하',
    stops: [
      Recommendation(
        placeName: '모모스 영도 로스터리&커피바',
        reason: '커피 좋아하믄 여는 꼭 가봐야 한다. 로스터리라 원두 향이 억수로 진하다카이.',
        duration: '60분',
        estimatedCost: '1인 10,000원',
      ),
      Recommendation(
        placeName: '피아크 카페엔베이커리',
        reason: '바다 앞 대형 베이커리 카페다. 빵도 맛있고 공간도 넓어서 오래 앉아 있기 좋다.',
        duration: '90분',
        estimatedCost: '1인 15,000원',
      ),
      Recommendation(
        placeName: '신기커피 영도',
        reason: '마무리로 여 조용한 카페 가라. 로컬들이 아끼는 커피 맛집이라카이.',
        duration: '60분',
        estimatedCost: '1인 10,000원',
      ),
    ],
  ),

  // 5. 역사·문화 · 30~50대 · 4h · 5,000원 · 계단 하
  PresetCourse(
    id: 5,
    theme: '역사·문화',
    target: '30~50대',
    totalTime: '4시간',
    budget: '5,000원',
    stairs: '하',
    stops: [
      Recommendation(
        placeName: '국립해양박물관',
        reason: '무료에 볼거리 억수로 많은 데다. 바다 역사 공부하기 딱 좋고 애들도 좋아한다. 월요일은 문 안 여니까 조심.',
        duration: '90분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '영도조내기고구마역사기념관',
        reason: '영도 고구마 역사 아나? 여 오면 다 알게 된다카이. 소소하지만 재밌는 데다.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '봉래산',
        reason: '마무리로 봉래산 올라가서 영도 전체 내려다봐라. 역사 얘기랑 뷰가 같이 온다.',
        duration: '60분',
        estimatedCost: '무료',
      ),
    ],
  ),

  // 6. 자연·힐링 · 30~60대 · 6h · 15,000원 · 계단 중
  PresetCourse(
    id: 6,
    theme: '자연·힐링',
    target: '30~60대',
    totalTime: '6시간',
    budget: '15,000원',
    stairs: '중',
    stops: [
      Recommendation(
        placeName: '태종대유원지',
        reason: '영도 자연 하면 여기라카이. 절벽이랑 바다가 장관이다. 길이 좀 험한 데 있으니 안전하게 다녀래이.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '태종대 다누비열차',
        reason: '걸으면 힘드니까 다누비 열차 타라. 4,000원인데 편하게 태종대 한 바퀴 돈다.',
        duration: '60분',
        estimatedCost: '1인 4,000원',
      ),
      Recommendation(
        placeName: '아미르공원',
        reason: '태종대 나와서 여 공원 가라. 평지에 잔디밭 넓어서 쉬엄쉬엄 걷기 딱이다.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '75광장',
        reason: '마무리로 여 광장 가서 바다 보며 쉬어라. 노을 시간 맞추면 더 좋다카이.',
        duration: '60분',
        estimatedCost: '무료',
      ),
    ],
  ),

  // 7. 가족 · 4인 가족 · 6h · 20,000원 · 계단 하
  PresetCourse(
    id: 7,
    theme: '가족',
    target: '4인 가족',
    totalTime: '6시간',
    budget: '20,000원',
    stairs: '하',
    stops: [
      Recommendation(
        placeName: '국립해양박물관',
        reason: '아이 데리고 오면 여가 정답이다. 무료 입장에 볼거리 많고 4D관도 있다카이. 월요일 휴관 조심.',
        duration: '120분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '삼진어묵 영도본점',
        reason: '어묵 만들기 체험도 되고 갓 튀긴 어묵 맛도 억수로 좋다. 아이들이 제일 좋아하는 데다.',
        duration: '60분',
        estimatedCost: '1인 8,000원',
      ),
      Recommendation(
        placeName: '태종대 다누비열차',
        reason: '아이 다리 아파하면 다누비 열차 꼭 태라. 어른 4,000원 아이 1,500원이다.',
        duration: '120분',
        estimatedCost: '어른 4,000원 / 아이 1,500원',
      ),
      Recommendation(
        placeName: '청해수산',
        reason: '가족 저녁은 여기서 바다 보며 회 먹어라. 예약 꼭 하고 가래이.',
        duration: '60분',
        estimatedCost: '1인 20,000원',
      ),
    ],
  ),

  // 8. 외국인 첫방문(EN) · 외국인 · 4h · 25,000원 · 계단 중
  PresetCourse(
    id: 8,
    theme: 'First Visit (EN)',
    target: 'Foreign visitors',
    totalTime: '4 hours',
    budget: '25,000 KRW',
    stairs: 'Medium',
    stops: [
      Recommendation(
        placeName: '흰여울문화마을',
        reason: 'The most iconic photo spot in Yeongdo. Colorful cliff-side houses with an ocean view. Some stairs but manageable.',
        duration: '60 minutes',
        estimatedCost: 'Free',
      ),
      Recommendation(
        placeName: '흰여울 해안터널',
        reason: 'A short seaside tunnel that opens up to a stunning ocean view. Great for framed photos.',
        duration: '30 minutes',
        estimatedCost: 'Free',
      ),
      Recommendation(
        placeName: '태종대유원지',
        reason: "Yeongdo's most famous natural landmark with dramatic cliffs. Watch your step near the edges.",
        duration: '60 minutes',
        estimatedCost: 'Free',
      ),
      Recommendation(
        placeName: '태종대 다누비열차',
        reason: 'Take the Danubi train to tour Taejongdae comfortably (4,000 KRW). Closed on Mondays.',
        duration: '60 minutes',
        estimatedCost: '4,000 KRW per person',
      ),
    ],
  ),

  // 9. 시니어 부부(존댓말) · 60대+ · 5h · 25,000원 · 계단 최소
  PresetCourse(
    id: 9,
    theme: '시니어',
    target: '60대+',
    totalTime: '5시간',
    budget: '25,000원',
    stairs: '최소',
    stops: [
      Recommendation(
        placeName: '국립해양박물관',
        reason: '여기 평지고 엘리베이터 있어서 편합니더. 볼거리도 많고 무료라예. 월요일은 문 안 여니까 조심하이소.',
        duration: '90분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '태종대 다누비열차',
        reason: '여는 걸으면 무리니까 다누비 열차 꼭 타이소. 어르신 4,000원인데 억수로 편합니더.',
        duration: '120분',
        estimatedCost: '1인 4,000원',
      ),
      Recommendation(
        placeName: '아미르공원',
        reason: '태종대 나와서 여 공원 가이소. 평지에 벤치도 많고 잔디밭도 넓습니더. 쉬엄쉬엄 걷기 딱입니더.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '라발스스카이카페&바',
        reason: '마무리로 여 전망 좋은 카페 가이소. 앉아서 바다 보며 쉬기 딱 좋습니더.',
        duration: '60분',
        estimatedCost: '1인 15,000원',
      ),
    ],
  ),

  // 10. 즉흥 탐방 · 20대 즉흥 · 3h · 15,000원 · 계단 중
  PresetCourse(
    id: 10,
    theme: '즉흥 탐방',
    target: '20대 즉흥',
    totalTime: '3시간',
    budget: '15,000원',
    stairs: '중',
    stops: [
      Recommendation(
        placeName: '흰여울문화마을',
        reason: '계획 없이 왔나? 마 좋다. 여 골목 골목 걸으면서 사진 찍고 놀면 시간 순삭이다카이.',
        duration: '90분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '흰여울 해안터널',
        reason: '걷다 보면 나오는 터널이다. 바다 프레임 사진 하나 남기고 가래이.',
        duration: '30분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '흰여울마을카페',
        reason: '배 고파지면 여 바다뷰 카페 가라. 간단한 식사도 되고 쉬기 좋다.',
        duration: '60분',
        estimatedCost: '1인 10,000원',
      ),
    ],
  ),

  // 11. 깡깡이 문화 · 30~50대 · 4h · 15,000원 · 계단 하
  PresetCourse(
    id: 11,
    theme: '깡깡이 문화',
    target: '30~50대',
    totalTime: '4시간',
    budget: '15,000원',
    stairs: '하',
    stops: [
      Recommendation(
        placeName: '깡깡이예술마을',
        reason: '옛날 조선소 마을이 예술마을로 변한 데다. 벽화랑 골목 구경하면서 영도 근현대사 느껴봐라.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '깡깡이마을박물관',
        reason: '깡깡이 아지매들 이야기가 다 여 있다카이. 영도 조선소 역사 제대로 배우는 데다.',
        duration: '60분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '봉래물양장갤러리',
        reason: '작은 갤러리인데 감성 있다. 조용히 작품 보면서 쉬어가기 좋다.',
        duration: '45분',
        estimatedCost: '무료',
      ),
      Recommendation(
        placeName: '남항시장',
        reason: '마무리는 여 시장 구경이라카이. 영도 사람들 사는 냄새 나는 데고, 먹거리도 많다.',
        duration: '60분',
        estimatedCost: '1인 12,000원',
      ),
    ],
  ),
];
