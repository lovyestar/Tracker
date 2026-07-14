/// 앱에서 사용하는 API 키 모음입니다. (SPEC §2)
///
/// 초보자를 위한 설명:
///  - 이 파일 한 곳에서만 키를 관리합니다. 다른 코드는 여기 값을 가져다 씁니다.
///  - 실제 서비스라면 이런 키는 공개 저장소에 올리면 안 됩니다.
///    (대회 제출/로컬 실행용으로만 그대로 사용합니다.)
class ApiKeys {
  static const kakaoNativeAppKey = '5cd9b1b8085d60acff9c34c8bbb217bc'; // 카카오 지도 SDK 초기화
  static const kakaoRestApiKey = '2364cd28d3cab02dbf50e6bc4719275f'; // (참고용) 카카오 REST
  static const kakaoJavascriptKey = '2364cd28d3cab02dbf50e6bc4719275f'; // (참고용)
  static const perplexityApiKey =
      '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';
  static const naverClientId = 'uz0leL7ec88W9D7MbPX4'; // 데이터 파이프라인용(앱 런타임 미사용 가능)
  static const naverClientSecret = '1JMd_0YyWW';
}
