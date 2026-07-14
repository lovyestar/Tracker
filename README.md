# 영도 AI 스탬프 투어 — 트래커 (Tracker)

부산 영도를 여행자에게 안내하는 AI 로컬 가이드 앱입니다.
갈매기 페르소나 **영매기**가 조건에 맞는 코스를 추천하고, GPS로 장소에 도착하면 스탬프를 찍어줍니다.

> 이 문서는 **프로그래밍 경험이 없는 팀원**도 그대로 따라 할 수 있게 작성했습니다.
> 순서대로 천천히 따라 하면 됩니다.

---

## 0. 이 앱이 하는 일 (화면)

1. **홈** — 영매기 인사(시간대별로 대사가 바뀜) + 메뉴 4개
2. **AI 맞춤 코스** — 인원·나이·예산·테마 등을 고르면 AI가 코스를 짜줌
3. **추천 코스 11선** — 미리 검증된 코스 중에서 골라 바로 출발
4. **지도/스탬프** — 카카오맵에 코스 장소 표시, 50m 안에 들어가면 스탬프 자동 획득
5. **완주 카드** — 스탬프를 다 모으면 완주 카드 생성 + 기록 저장
6. **리더보드** — (Firebase 설정 시) 누적 스탬프 순위 실시간 표시
7. **내 기록** — 내가 완주한 코스 이력

---

## 1. 준비물

- 컴퓨터 (Windows / macOS / Linux)
- 안드로이드 휴대폰 또는 안드로이드 에뮬레이터
- 인터넷 연결

---

## 2. Flutter 설치하기

Flutter는 이 앱을 실행·빌드하는 도구입니다.

1. 공식 설치 안내 페이지로 이동: <https://docs.flutter.dev/get-started/install>
2. 자기 운영체제(Windows/macOS/Linux)를 고르고 안내대로 설치합니다.
3. 설치가 끝나면 터미널(명령 프롬프트)에서 아래 명령으로 확인합니다.

```bash
flutter --version
```

버전 정보가 나오면 성공입니다. (이 앱은 **Flutter stable** 채널에서 개발했습니다.)

4. 안드로이드 앱을 만들려면 **Android Studio**도 설치해야 합니다.
   Android Studio를 설치하면 Android SDK가 함께 설치됩니다.
   설치 후 아래 명령으로 부족한 게 없는지 점검하세요.

```bash
flutter doctor
```

체크 항목에 빨간 X가 있으면 그 안내에 따라 해결합니다.
(대부분 "Android licenses"는 `flutter doctor --android-licenses` 로 동의하면 됩니다.)

---

## 3. 프로젝트 열고 라이브러리 받기

1. 터미널에서 이 프로젝트 폴더로 이동합니다.

```bash
cd tracker_app
```

2. 앱이 사용하는 라이브러리(패키지)를 내려받습니다.

```bash
flutter pub get
```

`Got dependencies!` 같은 메시지가 나오면 성공입니다.

---

## 4. API 키 확인

API 키는 이미 코드에 들어 있습니다: `lib/config/api_keys.dart`

- **카카오 지도 키** (`kakaoNativeAppKey`): 지도를 띄우는 데 사용
- **Perplexity 키** (`perplexityApiKey`): AI 코스 추천에 사용

> 별도로 바꿀 필요는 없습니다. 키가 만료되면 이 파일의 값만 새 키로 교체하면 됩니다.

---

## 5. (선택) Firebase 리더보드 연결하기

리더보드(순위표)를 쓰려면 Firebase를 연결해야 합니다.
**연결하지 않아도 앱은 정상 동작**합니다. (리더보드 화면에 안내만 뜨고, "내 기록"은 폰에 저장됩니다.)

연결하고 싶다면:

1. <https://console.firebase.google.com> 접속 → **프로젝트 만들기**
2. 프로젝트 안에서 **Android 앱 추가**
   - 패키지 이름(Android package name)에 정확히 입력: `com.example.tracker_app`
3. 안내에 따라 **google-services.json** 파일을 내려받습니다.
4. 그 파일을 이 위치에 넣습니다: `android/app/google-services.json`
5. 플러그인을 켭니다. 이 프로젝트는 **Kotlin DSL(`.gradle.kts`)** 을 씁니다.

   **(1) `android/settings.gradle.kts` — 이미 되어 있습니다. 손댈 필요 없어요.**
   (플러그인이 `apply false` 로 미리 선언돼 있어 json 이 없어도 무해합니다.)

   **(2) `android/app/build.gradle.kts` — 주석 한 줄만 해제하면 끝입니다.**
   `plugins { ... }` 블록에서 아래 줄 앞의 `//` 를 지웁니다.

   ```kotlin
   // id("com.google.gms.google-services")   ← 이 줄의 맨 앞 //  를 지우세요
   ```

   → 지운 뒤 모습:

   ```kotlin
   id("com.google.gms.google-services")
   ```

6. Firebase 콘솔에서 **Firestore Database**를 만들고(테스트 모드로 시작해도 됨), 저장하면 끝입니다.

> (2)의 주석 해제는 **google-services.json 파일을 넣은 뒤에만** 하세요.
> 파일 없이 해제하면 빌드가 실패합니다.
> 파일도 안 넣고 (2)도 그대로 두면 리더보드만 비활성화되고 나머지는 정상 동작합니다.

---

## 6. 앱 실행하기

1. 휴대폰을 USB로 연결(개발자 모드/USB 디버깅 켜기)하거나, Android Studio에서 에뮬레이터를 실행합니다.
2. 연결된 기기를 확인합니다.

```bash
flutter devices
```

3. 앱을 실행합니다.

```bash
flutter run
```

- 지도가 보이고 영매기 인사가 뜨면 성공입니다.
- **스탬프는 실제 GPS 위치가 목표 장소 50m 안에 들어가면 자동으로 찍힙니다.**
  (실내나 PC에서 테스트할 땐 지도 아래 장소 카드를 **꾹 눌러(길게 눌러)** 수동으로 스탬프를 찍어볼 수 있습니다.)

---

## 7. APK(설치 파일) 만들기

친구 폰에 설치해주고 싶을 때 사용합니다.

```bash
flutter build apk --release
```

완성된 파일 위치:

```
build/app/outputs/flutter-apk/app-release.apk
```

이 파일을 휴대폰으로 옮겨 설치하면 됩니다.
(설치 시 "출처를 알 수 없는 앱" 허용이 필요할 수 있습니다.)

> 참고: 위치 권한을 물어보면 **허용**해야 스탬프 기능이 동작합니다.

---

## 8. 문제가 생겼을 때

| 증상 | 해결 |
|---|---|
| `flutter` 명령을 못 찾음 | Flutter의 `bin` 폴더를 PATH 환경변수에 추가했는지 확인 |
| `flutter doctor`에 빨간 X | 그 항목의 안내대로 설치/동의 진행 |
| 지도가 안 뜸 | 인터넷 연결 확인, 카카오 키 확인 |
| 스탬프가 안 찍힘 | 위치 권한 허용 확인, 실외에서 시도, 또는 카드 길게 눌러 테스트 |
| 리더보드가 비어 있음 | Firebase(5번) 연결 여부 확인 |

---

## 9. 폴더 구조 (개발자용)

```
lib/
  config/       API 키
  constants/    영매기 대사, 프리셋 코스 11선, 테마
  models/       데이터 구조(장소, 추천, 코스, 기록, 조건)
  services/     장소 DB 로드, AI 추천, Firebase, 로컬 저장
  screens/      화면들(홈/조건/추천/코스/지도/완주/리더보드/기록)
  widgets/      영매기 말풍선 등 공용 위젯
test/           데이터 정합성·파서·대사 무결성 테스트
assets/         장소 DB(json), 마커/영매기 이미지
```

개발 중 코드 검사와 테스트:

```bash
flutter analyze   # 코드 오류 검사 (0 issues 여야 함)
flutter test      # 자동 테스트 실행
```
