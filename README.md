# Vector Range

Unity 6.3 LTS와 URP로 만드는 안드로이드 가로 화면 FPS입니다. 첫 프로토타입은 창고 사격장 **Depot**, 장비 **Pulse**, **30초 타임어택**을 담습니다.

## 한 판 플레이하기

홈에서 **PLAY → START RUN**을 누릅니다. 청록색 원형 표적을 맞힐 때마다 100점을 얻으며, 5회 발사하면 약 1초 동안 자동 충전됩니다. 결과 화면의 RETRY로 다시 시작할 수 있습니다. RECORDS에서 기기의 최고 점수와 최고 명중률을 확인합니다.

| 동작 | 안드로이드 | Unity 에디터 |
|---|---|---|
| 이동 | 왼쪽 스틱 | W, A, S, D |
| 시점 회전 | 오른쪽 빈 공간 드래그 | Game 뷰 오른쪽에서 마우스 드래그 |
| 발사 | 오른쪽 아래 PULSE | 스페이스 |
| 일시정지 | 오른쪽 위 II | Esc |

감도와 효과음은 SETTINGS에서 조정합니다. 다른 앱으로 이동하면 라운드가 일시정지됩니다.

## 에디터에서 열기

1. Unity Hub에서 **6000.3.28f1**을 설치합니다. Android Build Support와 그 하위 Android SDK & NDK Tools, OpenJDK를 포함합니다.
2. Hub의 Add에서 이 저장소 폴더를 선택하고 프로젝트를 엽니다. 처음에는 패키지를 다운로드합니다.
3. Project 창에서 **Assets/Scenes/Depot.unity**를 열고 Play를 누릅니다. 맵, 장비와 UI는 플레이를 시작할 때 생성됩니다.
4. **Vector Range → Validate prototype**으로 필수 에셋과 라운드 규칙을 점검합니다.

## Android APK 빌드

File → Build Profiles에서 Android를 활성화하고 **Vector Range → Build Android APK**를 선택합니다. 결과 파일은 `Builds/Android/VectorRange.apk`입니다. 패키지 이름은 `com.jjongjjongs.vectorrange`이고 ARM64 테스트 빌드는 Unity의 기본 디버그 키를 사용합니다.

Unity와 Android 모듈이 설치된 PC에서도 아래 예시처럼 빌드할 수 있습니다. 실행 파일과 프로젝트 경로를 PC에 맞게 지정합니다.

```bash
"$UNITY_EDITOR" -batchmode -quit -projectPath "$PWD" -buildTarget Android \
  -executeMethod VectorRange.Editor.AndroidPrototype.BuildAndroid -logFile -
adb install -r Builds/Android/VectorRange.apk
```

## 휴대폰 점검

- 왼쪽 스틱을 누른 채 오른쪽을 드래그해 이동과 시점 회전이 함께 되는지 확인합니다.
- 표적 중앙을 맞혀 점수가 한 번만 오르는지, 앞이 구조물에 막히면 점수가 오르지 않는지 확인합니다.
- 충전 중 이동, 일시정지 후 복귀, 시간이 끝난 뒤 재도전을 차례로 확인합니다.
- 앱을 다시 열어 최고 기록과 설정이 유지되는지 확인합니다.
