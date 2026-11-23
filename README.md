# Vector Range

안드로이드 ARM64용 1인칭 펄스 태그 게임입니다. [GitHub Releases](https://github.com/jjongjjongs/fps-mobile/releases/latest)에서 **Assets → VectorRange-버전-release-arm64.apk**를 눌러 설치하세요.

## 게임 모드

- **PLAY → POLAR AI DUEL → START DUEL**로 북극 연구기지에 들어갑니다. 90초 안에 먼저 5점을 내면 승리합니다. 시간이 끝나면 점수가 높은 쪽이 이기며 동점이면 무승부입니다. 드론이 발광하면 펄스가 날아옵니다.
- **PLAY → START RUN**으로 창고 사격장에서 30초 동안 표적 기록에 도전합니다.

왼쪽 스틱으로 이동하고 오른쪽 빈 공간을 밀어 시점을 돌립니다. **PULSE**로 발사하고, **AIM**으로 확대 조준, **JUMP**로 점프, **LOW**로 앉기와 일어서기를 전환합니다. 다섯 번 발사하면 자동 충전됩니다.

![북극 연구기지 실제 플레이 화면](docs/images/polar.jpg)

## 업데이트

0.2.0부터 패키지 이름은 `com.jjongjjongs.vectorrange`이며 같은 배포 키를 사용합니다. 기존 0.1.x Preview와는 별도로 설치되며 저장 기록도 분리됩니다. 같은 키로 서명한 다음 정식판은 기존 정식판 위에 설치할 수 있습니다.

## 빌드 및 검증

제작 브랜치는 `godot/depot-mobile`입니다. Godot 4.7.2에서 프로젝트를 열거나 다음 명령으로 게임 동작을 검증합니다.

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 --script tests/smoke.gd
```

버전을 올려 푸시하면 GitHub Actions가 맵과 입력 테스트를 거쳐 APK를 생성합니다. 배포용 비밀 값 `ANDROID_SIGNING`은 키스토어 Base64와 별칭, 비밀번호가 든 JSON입니다. 서명 인증서 지문을 확인한 뒤 Android 15에서 낮은 버전의 시험 패키지 위에 APK를 업데이트하고 앱을 실행합니다. 통과한 APK를 GitHub Releases에 게시합니다.
