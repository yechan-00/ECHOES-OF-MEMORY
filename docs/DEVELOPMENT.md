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
| 외부 런타임 | Python, OpenCV, Node.js 없음 | Video 라이브러리만 사용 |
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
| `EchoSystem.pde` | 잔상. 아직 주석만 있다. |
| `NeonEffects.pde` | 네온. 아직 주석만 있다. |
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
