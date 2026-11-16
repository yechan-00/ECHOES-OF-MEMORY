# ECHOES OF MEMORY 개발 가이드

Processing 4 Java Mode로 macOS와 Windows에서 같은 스케치를 개발하기 위한 기준이다. 개발 인원은 2명이다.

2단계 카메라 코드는 작성되어 있다. 이 문서를 고치는 동안 스케치 실행, 카메라 권한 확인, commit, push, merge는 하지 않았다. 아래 체크리스트는 실행 결과가 아니다. 각 항목은 해당 컴퓨터에서 직접 확인한 사람만 완료로 표시한다.

작성 시점에 확인한 환경은 다음과 같다.

- 한 Mac에 Processing 4.5.7가 설치되어 있었다.
- 그 Mac의 Processing 스케치북 `libraries` 폴더에는 Video 라이브러리가 없었다.
- Apple Silicon에서의 카메라 동작은 확인하지 않았다.
- 삼성, LG를 포함한 Windows 노트북에서는 확인하지 않았다. 특정 기종의 정상 동작을 보장하지 않는다.

## 확정된 공통 실행 조건

| 항목 | 기준 | 현재 소스 |
| --- | --- | --- |
| Processing | 4, Java Mode | 공통 API와 Video 라이브러리 |
| 스케치 이름 | 폴더 `EchoesOfMemory`, 메인 파일 `EchoesOfMemory.pde` | 일치 |
| 화면 크기 | 1280×720 | `size(1280, 720)` |
| 렌더링 FPS | 60 | `frameRate(60)` |
| 카메라 입력 | 가능하면 640×480, 장치가 보고한 모드 우선 | `CameraManager` |
| 배경색 | `#080D18` | `background(#080D18)` |
| 포인트 / 보조색 | `#38E8D5` / `#A78BFA` | 상태 글자 |
| 외부 런타임 | Python, OpenCV, Node.js 없음 | Video 라이브러리, 스케치 `code/`의 ONNX Runtime Java jar |
| 인코딩 | UTF-8, BOM 없음 | PDE와 문서 |

글꼴은 Java 논리 글꼴 `SansSerif`와 `Monospaced`만 사용한다. 운영체제 전용 카메라 이름, 장치 번호, 장치 경로는 넣지 않는다.

`pixelDensity(displayDensity())`는 공통 API다. 스케치 좌표는 1280×720을 유지한다. Retina와 Windows 배율에서는 선명도만 달라질 수 있다.

## 파일 경로 규칙

리소스는 `EchoesOfMemory/data/`에 둔다.

절대 경로를 코드에 쓰지 않는다. `loadImage("name.png")`, `dataPath()`, `sketchPath()`를 사용한다. 경로를 문자열로 이어 붙이지 않고, 구분자가 필요하면 `File.separator`를 쓴다.

`data/`는 현재 비어 있다. Git은 빈 폴더를 추적하지 않는다.

Video 라이브러리도 프로젝트 폴더 밖에 둔다.

- macOS: `~/Documents/Processing/libraries/video`
- Windows: `문서\Processing\libraries\video`

## macOS 개발 환경

아래 설치와 카메라 실행은 이 문서 작성 시점에 수행하지 않았다.

1. Processing 4를 Windows와 같은 버전으로 설치한다.
2. Library Manager에서 Video 라이브러리를 같은 버전으로 설치한다.
3. `EchoesOfMemory/EchoesOfMemory.pde`를 연다. 모드가 **Java**인지 확인한다.
4. `Processing > About Processing`에서 버전을 확인한다.
5. `시스템 설정 > 개인정보 보호 및 보안 > 카메라`에서 Processing을 허용한다.
6. `⌘R`로 실행한다. 권한을 바꾼 뒤에는 Processing을 다시 실행한다.
7. 콘솔의 `ECHOES camera list`에 MacBook 카메라가 보이는지 확인한다.

Apple Silicon Mac에서 Video 라이브러리의 기본 번들이 동작하는지는 아직 확인하지 않았다. 실행 후 콘솔에 네이티브 라이브러리 오류가 없는지 따로 확인한다. Mac 전용 카메라 이름이나 장치 경로는 코드에 없다.

## Windows 개발 환경

아래 설치와 카메라 실행은 이 문서 작성 시점에 수행하지 않았다. 삼성 갤럭시북, LG 그램을 포함한 특정 기종 테스트는 없다.

1. Processing 4를 macOS와 같은 버전으로 설치한다.
2. Library Manager에서 같은 Video 라이브러리 버전을 설치한다.
3. `EchoesOfMemory/EchoesOfMemory.pde`를 연다. 모드가 **Java**인지 확인한다.
4. `Help > About Processing`에서 버전을 비교한다.
5. PDE를 UTF-8, 줄바꿈 LF로 저장한다. CP949로 저장하면 한글 주석 때문에 컴파일이 실패할 수 있다.
6. `설정 > 개인 정보 및 보안 > 카메라`에서 카메라 액세스와 데스크톱 앱 액세스를 켠다.
7. `Ctrl+R`로 실행한다.

Windows 전용 장치 경로와 카메라 번호는 코드에 없다. Mac에서만 제공되는 API도 사용하지 않는다.

### 카메라가 검색되지 않을 때

이 절차는 작성된 점검 순서다. Windows에서 따라 해 보고 해결됐다고 확인하지는 않았다.

1. 콘솔에 `ECHOES camera list: 0`인지 확인한다.
2. `설정 > 개인 정보 및 보안 > 카메라`에서 카메라 액세스를 켠다.
3. 데스크톱 앱이 카메라에 접근할 수 있게 한다.
4. 카메라, Zoom, Teams처럼 카메라를 점유한 프로그램을 종료한다.
5. 장치 관리자에서 카메라가 사용 안 함으로 되어 있지 않은지 확인한다.
6. Processing으로 돌아와 `R`을 누른다.
7. 목록에 가상 카메라만 있으면 `C`로 내장 카메라를 고른다.
8. 그래도 비어 있으면 그 노트북의 카메라가 Processing Video의 GStreamer 장치에 나타나지 않는 상황일 수 있다. 기종별 동작은 보장하지 않는다.

## Processing 버전 확인

1. 모드가 Java인지 본다.
2. macOS는 `Processing > About Processing`, Windows는 `Help > About Processing`을 연다.
3. Video 버전은 `libraries/video/library.properties`의 `version`을 비교한다.
4. 두 값을 서로 대조하는 작업은 아직이다.

## 프로젝트 실행 방법

1. 양쪽 모두 Video 라이브러리를 설치한 뒤 `EchoesOfMemory.pde`를 연다.
2. macOS는 `⌘R`, Windows는 `Ctrl+R`로 실행한다.
3. 콘솔에서 검색된 장치와 `ECHOES prefer` 줄을 확인한다.
4. 화면에서 연결 전 문구, 첫 프레임 대기, 영상, 실패 문구 중 실제 상태를 확인한다.
5. `M`으로 좌우가 바뀌는지, `C`로 다른 장치가 있으면 전환되는지, `R`로 재검색되는지를 본다.

이 문서 작성 과정에서는 위 실행을 하지 않았다.

## Video 라이브러리

1. `Sketch > Import Library > Manage Libraries...`를 연다.
2. The Processing Foundation의 **Video**를 설치한다.
3. 상대도 같은 `version`을 설치한다.
4. 라이브러리 폴더는 Git에 넣지 않는다.

코드의 import는 `import processing.video.*;` 하나다.

## 카메라 검색과 선택

`Capture.list()`는 시작 시와 `R` 키에서만 호출한다. `draw()`마다 호출하지 않는다.

현재 Video 라이브러리는 장치 이름과 지원 모드를 나눠 준다.

- `Capture.list()` : 장치 이름. 같은 표시 이름이 여러 개면 `이름 #2`처럼 구분된다.
- `Capture.getCapabilities(name)` : `size=640x480,fps=30` 형태의 지원 모드.

목록 문자열 안에 해상도와 FPS가 들어 있는 이전 형식도 읽을 수 있다. 그 경우 같은 이름의 여러 설정은 카메라 하나로 묶고, 640×480에 가장 가까운 모드를 고른다.

자동 선택은 장치 번호를 고정하지 않는다. 같은 점수일 때만 앞쪽 항목이 유지된다. 점수는 다음 순서로 달라진다.

- `virtual`, `obs`, `manycam` 같은 가상 카메라 이름은 뒤로 보낸다.
- `built-in`, `integrated`, `internal`, `facetime` 같은 표현이 있으면 앞으로 보낸다. 이 단어가 없어도 장치를 제외하지 않는다.
- 보고된 모드 중 640×480이 있으면 가산한다.
- 삼성, LG, Apple 같은 제조사 이름은 조건으로 쓰지 않는다.

해상도는 보고된 모드 중 640×480에 가깝고, FPS는 30에 가까운 값을 고른다. 1–120 범위를 우선한다. 지원 모드가 없으면 640×480 @ 30을 요청하되, 그 모드를 장치가 지원한다고 표시하지 않는다. 지원하지 않는 해상도를 여러 개 연속해서 강제하지 않는다.

카메라 FPS와 화면 `frameRate(60)`은 별개다. 화면은 새 프레임이 없으면 마지막 프레임을 다시 그린다.

## 키보드

| 키 | 동작 |
| --- | --- |
| `C` | 다음 카메라. 전환 전에 기존 `Capture`를 멈추고 자원을 반환한 뒤 새 객체를 만든다. |
| `R` | 목록 재검색 후 자동 선택으로 다시 연결한다. |
| `M` | 표시용 좌우 반전. 기본값은 켜짐이다. |
| `H` | 렌더 FPS, 수신 FPS, 해상도, 단축키를 보여 주거나 숨긴다. |
| `E` | 잔상을 바로 소환한다(V 사인과 같은 효과, 시험용). |
| `N` | 네온 발광 켜기 / 끄기. |
| `T` | 손 추적 디버그 표시. 손마다 관절 21개, 뼈대, 관절 모델에 넣은 영역, 번호와 왼손/오른손, 추론 시간을 그린다. 손목 아래에는 손동작 이름과 손가락 상태(`|` 펴짐, `.` 굽힘, 엄지부터)를 쓰고, 엄지 끝과 검지 끝을 잇는 선은 가까울수록 진해진다. |

장치가 하나뿐이면 `C`는 다른 장치로 넘어가지 않는다. 연결에 실패한 경우에는 그 장치를 한 번 더 시도한다.

## 화면과 좌표계

기본 배치는 Fit이다. 4:3 영상을 1280×720에 늘리지 않고, 가로 여백이 생긴 채로 중앙에 둔다. 이후 파티클 단계에서 화면을 채우는 Fill로 바꿀 때는 `camera.viewMode = CameraManager.FILL`을 설정한다. Fill은 비율을 유지한 채 중앙을 기준으로 잘린다.

좌우 반전은 `pushMatrix()`, `translate()`, `scale(-1, 1)`, `image()`로 그린다. 원본 픽셀은 뒤집지 않는다. 화면의 좌우와 원본 좌표는 다를 수 있다.

- 버퍼의 `(0, 0)`은 카메라 프레임의 왼쪽 위다. `pixelColor(x, y)`도 이 좌표를 사용한다.
- 반전이 켜져 있으면 버퍼의 x가 클수록 화면에서는 왼쪽에 놓인다.
- `frameToScreenX(pixelX)`, `frameToScreenY(pixelY)`는 원본 픽셀을 현재 Fit 또는 Fill 화면 위치로 바꾼다.
- `screenToFrameX(screenX)`, `screenToFrameY(screenY)`는 화면 위치를 원본 픽셀 좌표로 바꾼다.
- 예: 반전이 켜진 Fit 화면에서 영상의 오른쪽을 클릭하면 `screenToFrameX()`는 0에 가까운 값을 반환한다.
- 좌표 변환은 `drawView()`와 같은 배치를 사용한다. 픽셀 색을 읽을 때는 화면 좌표를 먼저 원본 좌표로 바꾼다.

## 오류 처리

실패해도 스케치 전체를 종료하지 않도록 연결 구간에서 예외를 받는다. 라이브러리 내부의 네이티브 오류까지 모두 복구한다고 가정하지 않는다. 자동으로 끝없이 다시 연결하지 않는다.

| 상황 | 화면 |
| --- | --- |
| 장치가 없거나 목록이 비어 있음 | `CAMERA UNAVAILABLE` |
| 열기 실패 | `CAMERA UNAVAILABLE`. 사용 중, 권한 거부, 지원되지 않는 해상도 또는 FPS일 수 있다고 안내 |
| 열렸지만 첫 프레임이 없음 | 약 4초 뒤 `INITIALIZING CAMERA`와 재시도 안내. 캡처는 유지 |
| 수신이 끊김 | 마지막 프레임 위에 `SIGNAL INTERRUPTED` |
| 프레임을 읽는 중 예외 | 캡처를 닫고 `CAMERA UNAVAILABLE` |

권한 거부와 장치 점유를 라이브러리 메시지만으로 항상 구분할 수 없으므로, 원인을 하나로 단정하지 않는다.

## 카메라와 이후 모듈의 연결

`draw()`에서 `camera.update()`를 한 번 호출한 뒤에 같은 프레임을 사용한다. `captureEvent()`와 `available()/read()`를 함께 쓰지 않는다. 읽기는 `update()` 안의 `available()` / `read()` 한 경로만 사용한다.

```java
void draw() {
  background(#080D18);
  camera.update();

  if (camera.pixelsReady()) {
    int argb = camera.pixelColor(10, 20);
    // MotionDetector와 ParticleSystem은 이 값이나 frame()을 같이 본다.
  }

  camera.drawView();
}
```

`update()`가 새 프레임을 읽은 직후 `loadPixels()`를 한 번 호출한다. 같은 프레임을 다시 그리는 동안에는 픽셀 배열을 다시 만들지 않는다. `PImage`를 복사하지 않는다.

프레임을 읽는 `read()`는 `CameraManager`만 호출한다. `ParticleSystem`과 `MotionDetector`는 내부 `Capture`를 받지 않으며, `read()`, `start()`, `stop()`, `dispose()`를 호출하지 않는다. `frame()`이 돌려주는 객체를 `Capture`로 캐스팅하지 않는다.

### 데이터가 유효한 동안

- `update()`가 끝난 뒤부터 다음 `update()`가 새 프레임을 읽기 전까지, `frame()`과 `pixelColor()`는 같은 프레임을 가리킨다.
- 새 프레임이 없으면 직전 프레임이 그대로 유효하다.
- `hasNewFrame()`는 그 `update()` 이후, 다음 `update()` 전에만 참이다.
- 카메라 전환, 재검색, 종료가 되면 이전 픽셀은 즉시 무효가 된다. 배열 참조를 다음 프레임까지 저장하지 않는다.
- `pixelColor()`의 x, y는 원본 영상 좌표다. 화면에서 고른 위치는 `screenToFrameX()`, `screenToFrameY()`로 바꾼 뒤 사용한다.
- 범위를 벗어나거나 픽셀이 아직 준비되지 않으면 `pixelColor()`는 0을 반환한다. 0은 검은색일 수도 있으므로, 먼저 `pixelInRange()` 또는 `pixelsReady()`를 확인한다.

| 메서드 | 의미 |
| --- | --- |
| `frame()` | 최신 프레임. 없으면 `null`. 같은 `PImage`를 반환하며 복사하지 않는다. |
| `frameWidth()`, `frameHeight()` | 원본 프레임 크기. 프레임이 없으면 0. |
| `pixelsReady()` | `pixelColor()`를 호출할 수 있는지. |
| `pixelInRange(x, y)` | 원본 좌표가 프레임 안인지. |
| `pixelColor(x, y)` | 원본 좌표의 `0xAARRGGBB`. 유효하지 않으면 0. |
| `hasNewFrame()` | 이번 `update()`에서 새 프레임을 읽었는지. |
| `isReady()` | 최소 한 프레임을 받았는지. |
| `isConnected()` | 캡처 객체가 열려 있는지. |
| `connectionState()` | `searching`, `waiting`, `live`, `no-device`, `failed`, `no-frames`, `interrupted` |
| `frameToScreenX/Y` | 원본 픽셀을 화면 좌표로 변환. |
| `screenToFrameX/Y` | 화면 좌표를 원본 픽셀로 변환. |

`ParticleSystem`과 `MotionDetector`는 아직 구현하지 않는다. 둘 다 위 메서드만 사용한다.

## 카메라 권한

실행으로 확인하지 않았다.

macOS:

1. `시스템 설정 > 개인정보 보호 및 보안 > 카메라`를 연다.
2. Processing이 허용되어 있는지 확인한다.
3. 설정을 바꾼 뒤 Processing을 다시 실행하고 `R`을 누른다.

Windows:

1. `설정 > 개인 정보 및 보안 > 카메라`를 연다.
2. 카메라 액세스를 켠다.
3. 데스크톱 앱 액세스를 켠다.
4. 다른 프로그램이 카메라를 사용 중이면 종료하고 `R`을 누른다.

## GitHub 협업 규칙

원격 저장소는 `https://github.com/yechan-00/ECHOES-OF-MEMORY` 이다.

로컬 `main`은 `origin/main`을 추적한다. 이미 있는 초기 커밋은 `8b36f57` `Initial Processing project setup`이다. 2단계 카메라 변경은 그 커밋에 넣지 않았다. commit, push, merge는 실행하지 않았다. Mac에서 카메라 실행을 확인한 뒤에 사용자가 진행한다.

`git push --force`는 사용하지 않는다. 원격에 새 커밋이 생겼는지 push 전에 확인한다.

```bash
git status
git diff
git diff --cached
git remote -v
git ls-remote origin
```

원격 내용이 로컬과 달라졌으면 현재 폴더에 덮어쓰지 말고, 다른 폴더에 clone해서 비교한다.

```bash
git clone https://github.com/yechan-00/ECHOES-OF-MEMORY.git ../ECHOES-OF-MEMORY-remote
diff -rq --exclude=.git . ../ECHOES-OF-MEMORY-remote
```

### 브랜치

| 브랜치 | 역할 |
| --- | --- |
| `main` | 실행 가능한 상태만 유지한다. |
| `feature/particle-system` | `Particle.pde`, `ParticleSystem.pde` |
| `feature/motion-effects` | `MotionDetector.pde`, `EchoSystem.pde`, `NeonEffects.pde` |

각자 담당 브랜치에서 작업하고 Pull Request로 `main`에 병합한다. 한 사람이 파일을 수정하는 동안 다른 사람은 그 파일을 수정하지 않는다. `EchoesOfMemory.pde`는 공통 진입점이므로 한 번에 한 사람만 수정한다.

`.DS_Store`, `Thumbs.db`, `Desktop.ini`, IDE 임시 파일은 `.gitignore`에 의해 커밋에서 빠진다.

## 손 추적

`HandTracker`가 카메라 프레임에서 손을 최대 두 개 찾고, 손마다 관절 21개의 좌표를 낸다. 손동작 판별과 효과 연결은 아직 없다.

구성:

| 파일 | 출처 | 크기 |
| --- | --- | --- |
| `code/onnxruntime-1.31.1.jar` | Maven Central `com.microsoft.onnxruntime:onnxruntime:1.31.1` (MIT) | 약 51 MB |
| `data/palm_detection_mediapipe_2023feb.onnx` | opencv_zoo, MediaPipe Hands 변환본 (Apache 2.0) | 약 3.9 MB |
| `data/handpose_estimation_mediapipe_2023feb.onnx` | opencv_zoo, MediaPipe Hands 변환본 (Apache 2.0) | 약 4.1 MB |

jar에는 Windows x64, macOS Apple Silicon, Linux용 네이티브 라이브러리가 들어 있다. Intel Mac용은 없다. 클래스는 Java 8 대상이라 Processing 4에 들어 있는 JDK 17에서 동작한다.

처리 흐름:

1. `submit()`이 `draw()`에서 새 프레임의 픽셀을 복사해 작업 스레드에 넘긴다. 추론이 밀리면 중간 프레임은 버린다.
2. 추적 중인 손은 이전 관절 위치로 회전된 정사각형 영역을 잡고 관절 모델만 돌린다.
3. 잡힌 손이 두 개보다 적으면 손바닥 검출 모델로 새 손을 찾는다. 손이 하나라도 잡혀 있으면 3프레임마다 찾는다.
4. 관절 좌표에 One Euro 필터를 적용하고 결과를 통째로 바꿔 내보낸다.

받는 쪽이 쓰는 값:

- `handTracker.hands()`: `Hand[]`. 결과가 0.5초보다 오래되면 빈 배열이다.
- `Hand.id`: 추적이 이어지는 동안 유지되는 번호. 손을 놓쳤다가 다시 잡으면 새 번호가 된다.
- `Hand.x[k]`, `Hand.y[k]`: 원본 프레임 좌표. 화면에는 `camera.frameToScreenX/Y()`로 바꿔 그린다.
- `Hand.z[k]`: 손목 기준 상대 깊이. 작을수록 카메라에 가깝다.
- `Hand.rightHand`, `Hand.score`, `Hand.palmSize`, `Hand.trackedMs`.
- 관절 번호는 MediaPipe Hands와 같다. 0 손목, 4 엄지 끝, 8 검지 끝, 12 중지 끝, 16 약지 끝, 20 새끼 끝.

2026-11-16 Windows에서 Processing JDK 17로 MediaPipe 테스트 사진 7장을 확인했다. 결과는 다음과 같다.

- 모두 검출됐고, 양손 사진에서는 두 손이 모두 잡혔다. 거꾸로 된 손과 옆으로 누운 손도 포함이다.
- 640×480 프레임에서 양손을 추적할 때 평균 16 ms, 최악 25 ms가 걸렸다.
- 움직이는 사진을 60프레임 넣는 동안 두 손 모두 놓치지 않았고, 번호도 유지됐다.

실제 카메라로는 아직 확인하지 않았다.

권장 거리는 카메라에서 1 m 안쪽이다. 손이 화면에서 너무 작으면 손바닥 검출이 실패한다.

## 손동작 판별

`GestureRecognizer`가 `handTracker.hands()`를 받아 손마다 손동작을 판별한다. `draw()`에서 매 프레임 `update()`를 호출한다.

| 손동작 | 상수 | 조건 |
| --- | --- | --- |
| 손바닥 펴기 | `OPEN` | 검지·중지·약지·새끼가 모두 펴짐. 엄지는 보지 않는다 |
| 주먹 | `FIST` | 네 손가락이 모두 굽고 엄지도 접힘 |
| 가리키기 | `POINT` | 검지만 펴짐 |
| V 사인 | `VICTORY` | 검지와 중지만 펴짐 |
| 집기 | `PINCH` | 엄지 끝과 검지 끝이 붙음. 다른 동작보다 먼저 본다 |
| 해당 없음 | `NONE` | 엄지 척, 손가락 셋 등 |

판별 기준은 모두 비율이라 손의 회전과 거리에 영향받지 않는다.

- 손가락: 손목→끝 거리 / 손목→둘째 마디 거리가 `EXTEND_RATIO`(1.05)보다 크면 펴짐.
- 엄지: 엄지 끝→검지 뿌리 거리 / `palmSize`가 `THUMB_OUT_RATIO`(0.55)보다 크면 펴짐.
- 집기: 엄지 끝→검지 끝 거리 / `palmSize`가 `PINCH_ON`(0.30)보다 작아지면 시작하고, `PINCH_OFF`(0.45)보다 커지면 끝난다.
  - 시작하려면 검지 끝이 손바닥 중심에서 `PINCH_INDEX_REACH`(0.7) 이상 떨어져 있어야 한다.
  - 주먹은 엄지가 검지 위에 얹혀 엄지 끝→검지 끝 거리가 0.18까지 줄어든다. 이 조건이 그 오판을 막는다.
- 흔들림 방지: 같은 판별이 `HOLD_MS`(120 ms) 동안 이어져야 손동작이 바뀐다.

받는 쪽이 쓰는 값 (`gestures.gestures()` → `HandGesture[]`, 또는 `gestures.find(hand.id)`):

- `gesture`: 흔들림을 걸러낸 현재 손동작. `previous`: 바로 전 손동작.
- `justChanged`: 이번 `update()`에서 손동작이 바뀌었는지. 예를 들어 집기를 놓는 순간은 `justChanged && previous == PINCH`다.
- `heldMs(millis())`: 현재 손동작이 이어진 시간.
- `pinchX/Y`(엄지 끝과 검지 끝의 중간), `pointX/Y`(검지 끝), `palmX/Y`(손바닥 중심), `palmSize`. 모두 원본 프레임 좌표다.
- `pinchStrength`: 0~1. 엄지와 검지가 가까울수록 1이다. 집기 전 단계의 연출에 쓴다.

2026-11-16 테스트 사진 7장(좌우 반전 포함 18개 손)으로 확인했다.

- 모든 손이 의도한 동작으로 판별됐다. 엄지 척은 `NONE`으로 나왔다.
- 집기 사진은 없어서, 실제로 검출된 가리키기 손과 V 사인 손의 엄지 끝을 33 ms마다 검지 끝 쪽으로 옮겼다가 되돌렸다.
  - 집기는 0.29에서 시작해 0.46에서 끝났다.
  - 손동작은 판별이 바뀌고 약 130 ms 뒤에 바뀌었다.
- 50 ms마다 주먹과 펴기를 번갈아 넣었을 때 1초 동안 손동작이 바뀌지 않았다.

실제 카메라로는 확인하지 않았다. 임계값은 카메라로 확인하면서 조정한다.

## 손동작 효과

`HandEffects`가 손동작을 파티클 힘과 화면 효과로 바꾼다. 입자는 직접 움직이지 않는다. `ParticleSystem.addHandField()`로 힘을 등록하면 다음 `update()` 한 번에 적용되고 비워진다. `P` 초상화 모드에서만 동작한다.

`ParticleSystem`이 받는 힘은 손동작과 무관한 세 가지다.

| 힘 | 동작 |
| --- | --- |
| `FIELD_PUSH` | 중심에서 바깥으로 민다 |
| `FIELD_GATHER` | 중심으로 끌어와 `core` 반지름 안에 머물게 한다. 입자마다 머무는 거리가 달라 한 점이 아니라 빛 덩어리가 된다. `swirl`을 주면 중심을 돈다 |
| `FIELD_BURST` | 그 프레임에 한 번 속도를 바깥으로 더한다 |

힘에 닿은 입자는 `release`가 올라가 스프링이 잠시 풀린다. 손을 떼면 약 1.6초에 걸쳐 제자리로 돌아온다.

손동작별 효과 (크기는 손바닥 크기의 배수, 상수는 `HandEffects.pde` 위쪽에 있다):

| 손동작 | 효과 | 반지름 |
| --- | --- | --- |
| 손바닥 펴기 | 손바닥 중심에서 바깥으로 미는 바람 | 1.8 |
| 가리키기 | 검지 끝 주변을 갈라 지나가고, 검지 끝을 따라 0.9초 동안 남는 청록→보라 네온 궤적 | 0.5 |
| 집기 | 집은 지점으로 끌어모아 소용돌이친다. 손마다 도는 방향이 반대다 | 1.8 |
| 주먹 | 손바닥 중심으로 압축해 붙잡는다. 손을 움직이면 따라간다 | 1.6 |
| 집기·주먹을 놓는 순간 | 모았던 입자를 튕긴 뒤 0.25초 더 밀어 흩뿌린다. 오래 쥘수록(0.9초까지) 세다 | 2.0 |
| 휘두르기 | 손바닥이 빠르게(초당 손바닥 7개 이상) 움직이면 그 방향으로 쓸어낸다. 쥐고 있을 때는 걸지 않는다 | 1.8 |
| 양손 벌리기·모으기 | 두 손 사이 거리가 빠르게(초당 손바닥 1.5개 이상) 벌어지면 가운데서 흩뿌리고, 좁혀지면 가운데로 모은다 | 두 손 거리의 절반 + 1 |
| V 사인 | 잔상 소환. 아래 "잔상"에서 설명한다 | |

- 집기 직전에는 엄지와 검지 사이에 손가락이 가까워질수록 좁아지는 고리가 보인다. 집는 동안에는 그 자리가 빛난다.
- 손이 하나라도 잡혀 있으면 움직임 감지 힘을 0.3배로 줄여 손동작 힘과 다투지 않게 한다(`MOTION_SCALE_WITH_HANDS`).
- 입자 최고 속도는 `MAX_SPEED`(16 px/프레임)로 잘린다. 그래서 한 번 튕기기만으로는 약 80 px밖에 퍼지지 않아, 놓은 뒤 0.25초 동안 계속 밀도록 했다.

2026-11-16 하네스로 물리 동작을 확인했다. 조건은 640×480 프레임, 화면 배율 2, 손바닥 크기 화면 120 px, 입자 12,288개다.

| 효과 | 결과 |
| --- | --- |
| 주먹 | 반지름 안의 1,160개가 1.1초 뒤 모두 50 px 안으로 모였다. 손을 116 px 옮겨도 모두 따라왔다 |
| 터뜨리기 | 1.5초 쥐었다 놓으면 0.3초 뒤 평균 175 px까지, 0.2초 쥐었다 놓으면 128 px까지 퍼졌다 |
| 집기 | 1,468개 중 99%가 모였고, 초당 약 1바퀴 돌았다 |
| 손바닥 바람 | 반지름 절반 안이 0.65초 만에 모두 비었다 |
| 검지 | 지나간 선 위 입자 88개가 모두 비켜났다 |
| 복원 | 모든 효과 뒤 4~5초 안에 제자리로 돌아왔다(평균 오차 0.00 px) |

실제 카메라와 화면으로는 확인하지 않았다. 궤적과 고리 그림도 화면으로 보지 않았다.

손 속도와 양손 거리 (`GestureRecognizer`):

- `HandGesture.speed`: 손바닥 중심 속도를 초당 손바닥 크기 몇 개로 잰 값이다. `velX/velY`는 프레임 px/초다.
  - 손 위치는 카메라 프레임마다 바뀌고 `update()`는 draw마다 불리므로, 위치가 실제로 바뀐 때만 속도를 다시 구한다.
- `swiping`: `SWIPE_START`(7)를 넘으면 켜지고 `SWIPE_END`(4) 밑으로 내려가면 꺼진다.
  - 1 m 안쪽에서 손바닥은 약 9 cm다. 천천히 흔들기(0.5 m/s)는 약 5.5, 빠르게 휘두르기(1.5 m/s)는 약 16이다. 실측 전 추정값이다.
- `pairActive`, `pairDistance`, `pairRate`, `pairMidX/Y`: 손이 정확히 둘일 때 두 손바닥 중심 사이 거리(손바닥 단위)와 그 초당 변화다.
- `T` 화면에서 손목 이름표 끝에 속도와 `SWIPE`가, 두 손 가운데에 `PAIR 거리 변화/s`가 나온다.

## 잔상

`EchoSystem`이 초상화의 과거 모습을 저장해 두었다가 보라색 잔상으로 띄운다. 입자 물리에는 손대지 않고 저장한 모습을 따로 그린다.

- 저장: 0.4초마다 밝게 켜진 입자 3개 중 1개의 화면 위치, 색, 크기, 밝기를 저장한다. 10개를 돌려 써서 최근 4초가 남는다.
  - 인물이 없거나(점 150개 미만) 흩어지는 중이면(켜진 입자의 5% 넘게 빠르게 움직이면) 저장하지 않는다.
- 큰 움직임: `motion.total`이 `MOTION_TRIGGER`(0.05)를 넘으면 0.8초 전 모습을 하나 띄운다. 1.5초 쿨다운이 있다.
  - 0.05는 실측 전 추정값이다. 손만 흔들 때는 넘지 않고 몸 전체가 움직일 때 넘도록 `G` 화면의 `total`을 보고 조정한다.
- V 사인: 확정되는 순간 저장된 모습을 최근 것부터 5개, 0.16초 간격으로 띄운다. 오래된 것일수록 흐리다.
- `E` 키: V 사인 없이 바로 소환한다(시험용).
- 잔상 하나는 2.6초 동안 보라색으로 물들며 46 px 떠오르고, 중심에서 14% 퍼지며 사라진다.

## 네온

`NeonEffects`가 빠르게 움직이는 입자(2.5 px/프레임 이상) 뒤에 빛 번짐, 밝은 중심, 움직임 반대쪽 꼬리를 그린다.

- 느리면 청록, 빠를수록 보라다. 움직임 감지로 보라색이 든 입자는 처음부터 보라 쪽이다.
- 블렌드 모드를 바꾸지 않고 반투명 원을 겹친다. 기본 렌더러(JAVA2D)에서 같은 모습이 나오게 하기 위해서다.
- 한 프레임에 최대 4,000개만 빛낸다. `N` 키로 켜고 끈다.

그리는 순서는 뒤에서부터 잔상, 네온 번짐, 지금 모습, 손 효과(궤적·집기 빛)다.

2026-11-16 하네스로 4단계를 확인했다. Processing 그래픽 객체(`PGraphicsJava2D`)를 창 없이 만들어 실제로 그려 보았다.

| 항목 | 결과 |
| --- | --- |
| 손 속도 | 카메라 프레임당 6, 12, 30 px 이동이 3.0, 6.0, 14.4 손바닥/초로 나왔다(이론값과 5~8% 안). 30 px일 때만 휘두르기로 판정됐다 |
| 양손 거리 | 변화 속도가 +6.0/초로 나왔다(이론값 +6.3) |
| 휘두르기 | 지나간 자리 입자가 진행 방향으로 평균 22 px 밀렸다 |
| 양손 벌리기·모으기 | 가운데 입자 평균 거리가 107 px에서 각각 187 px, 40 px가 됐다 |
| 잔상 | 큰 움직임에 하나 떴고, 쿨다운 안에서는 다시 뜨지 않았고, 2.6초 뒤 사라졌다. V 사인에 5개가 0, 160, 320, 480, 640 ms에 떴다 |
| 네온 | 주먹을 놓아 터뜨리는 순간 약 1,400개가 빛났다. 그림에서 보라색 빛 고리가 퍼지는 것을 확인했다 |
| 검지 궤적 | 그림에서 갈라진 길과 청록에서 보라로 바래는 선을 확인했다 |

실제 카메라로는 확인하지 않았다. 잔상은 테스트 사진이 화면 전체를 밝게 채워 지금 모습과 겹쳐 보였기 때문에, 잔상만 따로 그려 모양을 확인했다.

## 웹 테스트 페이지

`web/hand-test/index.html`은 `HandTracker`와 `GestureRecognizer`를 JavaScript로 그대로 옮긴 페이지다. Processing 없이 브라우저와 노트북 카메라로 손 추적과 손동작 판별을 확인한다.

- 실행: 저장소 최상위에서 `python3 -m http.server 8000`(Windows는 `python`)을 실행하고 `http://localhost:8000/web/hand-test/`를 연다. 모델은 `../../EchoesOfMemory/data/`에서 읽으므로 최상위에서 띄워야 한다.
- 추론: onnxruntime-web 1.20.1(WASM, 단일 스레드)을 jsDelivr에서 불러온다. 첫 실행에는 인터넷이 필요하다.
- 화면: 관절, 손동작 이름, 손가락별 측정값 막대(흰 눈금이 임계값)를 보여 준다. 슬라이더로 바꾼 임계값을 Java 상수 형태로 복사할 수 있다. `사진으로 테스트`로 이미지 파일도 넣을 수 있다.
- 2026-11-16 Windows의 Claude 내장 브라우저(Chromium)에서 MediaPipe 테스트 사진 7장을 넣었다. 손동작, 왼손/오른손, 손목 좌표(1 px 안쪽)가 Java 결과와 같았다. 브라우저 쪽 추론은 양손 기준 약 50 ms로 Java보다 느리다.
- `HandTracker.pde`나 `GestureRecognizer.pde`의 상수나 계산을 바꾸면 이 페이지도 함께 바꾼다.

## 테스트 체크리스트

완료한 항목만 체크한다. 2026-11-10에 Windows 항목을 확인했다. macOS 항목은 아직 미검증이다.

환경:

- [x] 양쪽 Processing 4 버전이 같다. (Mac 4.5.7, Windows 4.5.7)
- [x] 모드가 Java다.
- [ ] 양쪽 Video 라이브러리 버전이 같다. (Windows 2.2.2, Mac 미확인)
- [x] 스케치 폴더 이름이 `EchoesOfMemory`다.

macOS:

- [ ] Processing에 카메라 권한이 있다.
- [ ] 콘솔에 카메라 목록이 출력된다.
- [ ] 내장 카메라 영상이 중앙에 비율을 유지한 채 나온다.
- [ ] 기본 화면이 좌우 반전이다.
- [ ] `M`으로 반전이 바뀐다.
- [ ] `C`와 `R`이 동작한다.
- [ ] Apple Silicon에서 네이티브 라이브러리 오류가 없다.

Windows:

- [x] 카메라와 데스크톱 앱 권한이 켜져 있다.
- [x] 콘솔에 내장 웹캠이 출력된다.
- [x] 영상이 비율을 유지한 채 나온다.
- [x] `C`, `R`, `M`, `H`가 동작한다.
- [ ] 카메라가 없을 때 스케치가 종료되지 않고 안내가 남는다.
- [x] 움직임 감지: `G`로 감지 칸과 중심 표시, `[` `]`로 임계값 조절이 동작한다.

손 추적 (양쪽 운영체제):

- [ ] 콘솔에 `ECHOES hands: model load failed`가 나오지 않는다.
- [ ] `T`로 디버그 표시가 켜지고, 손을 올리면 뼈대가 손가락을 따라간다.
- [ ] 양손을 함께 올리면 둘 다 잡히고, 움직이는 동안 번호가 바뀌지 않는다.
- [ ] 화면에 표시된 `L`/`R`이 실제 손과 같다. 반대면 `HANDEDNESS_FLIP`을 `true`로 바꾼다.
- [ ] 패널의 추론 시간이 대체로 33 ms보다 짧다.
- [ ] Apple Silicon에서 ONNX Runtime 네이티브 라이브러리 오류가 없다.

손동작 판별 (`T` 화면에서):

- [ ] 손바닥 펴기, 주먹, 검지 가리키기, V 사인, 집기가 각각 맞는 이름으로 표시된다.
- [ ] 엄지 척이나 손가락 셋은 `NONE`으로 표시된다.
- [ ] 손을 천천히 움직이는 동안 이름이 깜빡이지 않는다. 괄호 안 판별값이 자주 바뀌면 임계값을 조정한다.
- [ ] 손을 옆으로 눕히거나 손등을 보여도 같은 동작으로 판별된다.
- [ ] 집기를 시작하고 놓을 때 반응이 늦게 느껴지지 않는다. 늦으면 `HOLD_MS`를 줄인다.

손동작 효과 (`P` 초상화 모드에서):

- [ ] 주먹을 쥐면 주변 입자가 손으로 모이고, 손을 움직이면 따라온다. 주먹을 펴면 흩어졌다가 돌아온다.
- [ ] 집으면 입자가 집은 지점으로 모여 돈다. 놓으면 흩어진다.
- [ ] 손바닥을 펴면 손 주변이 비워진다. 늘 펴고 있는 손 때문에 거슬리면 `OPEN_FORCE`를 줄인다.
- [ ] 검지로 가리키며 움직이면 지나간 자리가 갈라지고 네온 궤적이 남는다.
- [ ] 효과 크기가 화면에 비해 너무 크거나 작지 않다. 반지름 상수로 조정한다.
- [ ] 손동작 효과를 켠 채로 프레임 속도가 크게 떨어지지 않는다.
- [ ] 손을 빠르게 휘두를 때만 `SWIPE`가 뜨고, 천천히 움직일 때는 뜨지 않는다. 아니면 `SWIPE_START`를 조정한다.
- [ ] 두 손을 빠르게 벌리면 가운데가 흩어지고, 모으면 모인다. 천천히 움직일 때는 반응하지 않는다.

잔상과 네온 (`P` 초상화 모드에서):

- [ ] V 사인을 하면 과거 모습이 보라색 잔상으로 차례로 떠올랐다 사라진다. `E` 키로도 같은 것이 나온다.
- [ ] 몸을 크게 움직이면 직전 모습이 잔상으로 뜨고, 손만 흔들 때는 뜨지 않는다. 아니면 `G` 화면의 `total`을 보고 `MOTION_TRIGGER`를 조정한다.
- [ ] 입자가 흩어질 때 청록·보라로 빛나고, 멈추면 빛이 사라진다. `N`으로 끄고 켤 수 있다.
- [ ] 잔상과 네온을 켠 채로 프레임 속도가 크게 떨어지지 않는다.

아직 구현하지 않은 항목은 테스트하지 않는다. 파티클, 잔상, 네온이다.

| 날짜 | 운영체제 | Processing | Video | 확인한 항목 | 결과 |
| --- | --- | --- | --- | --- | --- |
| 2026-11-10 | Windows 11 Home | 4.5.7 | 2.2.2 | 카메라 연결·표시, `C` `R` `M` `H`, 움직임 감지 `G` `[` `]` | 동작함. 카메라 `Hy-HD(7501)-Camera` 640×480 @ 30. 참고 사항 3가지는 아래 |

Windows 실행 중 발견한 사항(2026-11-10):

- `Capture.getCapabilities()`가 이 카메라에서 `StringIndexOutOfBoundsException`을 낸다. `CameraManager`가 예외를 받아 640×480 @ 30 기본 요청으로 넘어가므로 실행에는 지장이 없다.
- 화면 배율 125%에서 `pixelDensity(displayDensity())` 때문에 1280×720 창이 약 1600×900으로 커져 화면 밖으로 잘렸다. `integration/demo`에서 `fullScreen()`으로 바뀌어 더는 해당하지 않는다.
- 종료 시 `IllegalAccessException`이 난다. `CameraManager`가 `public class`가 아니라서 `registerMethod("dispose", this)`로 등록한 `dispose()`를 Processing이 호출하지 못한다.

## 담당 파일

| 파일 | 담당 |
| --- | --- |
| `EchoesOfMemory.pde` | 창 크기, 프레임 속도, `CameraManager` 연결과 키 입력 |
| `CameraManager.pde` | 카메라 검색, 연결, 프레임, 표시, 종료 |
| `Particle.pde` | 입자 하나. 아직 주석만 있다. |
| `ParticleSystem.pde` | 입자 무리. 아직 주석만 있다. |
| `MotionDetector.pde` | 움직임 양. 아직 주석만 있다. |
| `HandTracker.pde` | 양손 관절 21개 추적. 별도 스레드에서 ONNX 모델을 실행한다. |
| `GestureRecognizer.pde` | 관절 좌표로 손마다 손동작을 판별한다. 효과는 만들지 않는다. |
| `HandEffects.pde` | 손동작을 파티클 힘(`ParticleSystem.addHandField`)과 검지 궤적으로 바꾼다. |
| `EchoesOfMemory/code/` | ONNX Runtime Java jar. Processing이 자동으로 클래스패스에 넣는다. |
| `EchoSystem.pde` | 잔상. 과거 모습을 저장해 두었다가 큰 움직임과 V 사인에 띄운다. |
| `NeonEffects.pde` | 네온. 빠르게 흩어지는 입자에 청록·보라 빛 번짐과 꼬리를 그린다. |
| `EchoesOfMemory/data/` | 공유 리소스 |

## 구현 순서

1. 프로젝트 초기화와 시작 화면.
2. 공통 개발 환경 정리.
3. 카메라 입력. 코드는 작성되어 있고, Mac/Windows 실행 확인은 아직이다.
4. 파티클 초상.
5. 움직임 감지와 입자의 흩어짐, 복원.
6. 잔상.
7. 청록색·보라색 네온.

한 단계의 실행을 확인한 뒤에 다음 단계로 넘어간다.
