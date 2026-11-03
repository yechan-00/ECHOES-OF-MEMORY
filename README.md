# ECHOES OF MEMORY

MacBook 카메라로 관람객의 모습을 실시간 촬영하고, 그 형상을 수천 개의 파티클로 보여주는 인터랙티브 미디어 아트 작품이다. 움직임이 감지되면 입자가 흩어지며 청록색과 보라색 네온, 그리고 과거 모습의 잔상이 나타난다. 움직임이 멈추면 입자는 현재 모습으로 돌아온다.

이 저장소는 Processing 4 Java Mode 스케치다.

## 현재 단계

2단계 카메라 입력 코드가 들어 있다. 파티클, 움직임 감지, 잔상, 네온은 아직 없다.

이 코드를 작성한 뒤에는 Processing으로 실행하지 않았다. 카메라 연결 성공은 확인되지 않았다. Mac과 Windows에서 각각 실행해 확인해야 한다.

## 실행 환경

- Processing 4
- Mode: Java
- 라이브러리: Processing Foundation의 **Video**
- 외부 Python, OpenCV, Node.js, npm은 사용하지 않는다

두 컴퓨터는 같은 Processing 버전과 같은 Video 라이브러리 버전을 사용한다. Video 라이브러리는 스케치 폴더에 복사하지 않는다. Processing 스케치북의 `libraries` 폴더에 설치된다.

- macOS: `~/Documents/Processing/libraries/video`
- Windows: `문서\Processing\libraries\video`

이 저장소를 작성한 Mac에는 Processing 4.5.7가 설치되어 있었다. 그때 `libraries` 폴더에는 Video 라이브러리가 없었다. 이 사실만으로 카메라 동작을 보장하지 않는다.

## Video 라이브러리 설치

1. Processing을 연다.
2. `Sketch > Import Library > Manage Libraries...`를 연다.
3. `Video`를 검색한다.
4. The Processing Foundation의 **Video**를 설치한다.
5. `libraries/video/library.properties`의 `version` 값을 서로 비교한다. 같아야 한다.
6. 설치 전에 스케치를 실행하면 `processing.video`를 찾지 못하고 컴파일에 실패한다.

코드는 `Capture.list()`와 `Capture.getCapabilities()`를 사용한다. 두 메서드가 있는 현재 Video 라이브러리를 설치한다.

## 실행 방법

1. 위에서 Video 라이브러리를 설치한다.
2. `EchoesOfMemory/EchoesOfMemory.pde`를 연다. 폴더 이름은 `EchoesOfMemory`여야 한다.
3. 오른쪽 모드가 **Java**인지 확인한다.
4. Run한다. macOS는 `⌘R`, Windows는 `Ctrl+R`이다.
5. 콘솔에 `ECHOES camera list`가 출력되는지 본다.
6. 화면은 1280×720, 배경 `#080D18`이다.
   - 연결 전: `ECHOES OF MEMORY`, `INITIALIZING CAMERA`
   - 연결 후: 비율을 유지한 카메라 영상. 기본은 좌우 반전이다
   - 실패: `CAMERA UNAVAILABLE`과 `R` 재시도 안내

## 키보드

| 키 | 동작 |
| --- | --- |
| `C` | 다음 카메라 |
| `R` | 목록을 다시 검색하고 연결을 다시 시도 |
| `M` | 좌우 반전 켜기 / 끄기 |
| `H` | 도움말과 프레임 정보 표시 |

대문자와 소문자 모두 동작한다. 화면 하단에도 `C: Camera`, `R: Retry`, `M: Mirror`, `H: Help`가 표시된다. 장치 번호와 제조사 이름은 코드에 고정되어 있지 않다.

## 카메라 권한

macOS는 `시스템 설정 > 개인정보 보호 및 보안 > 카메라`에서 Processing을 허용한다.

Windows는 `설정 > 개인 정보 및 보안 > 카메라`에서 카메라 액세스와 데스크톱 앱 액세스를 켠다.

권한이 거부된 경우와 다른 프로그램이 카메라를 쓰는 경우를 코드에서 항상 구분할 수는 없다. 화면은 가능한 원인을 함께 안내하고, `R`로 다시 검색한다.

## 프레임 데이터

`CameraManager`만 카메라 프레임을 읽는다. 파티클과 움직임 감지는 다음 메서드를 사용한다.

- `frame()`, `frameWidth()`, `frameHeight()`
- `pixelsReady()`, `pixelInRange(x, y)`, `pixelColor(x, y)`
- `hasNewFrame()`, `isConnected()`, `connectionState()`

`pixelColor()`의 좌표는 화면에 비친 좌우가 아니라 원본 프레임 좌표다. 좌우 반전은 그릴 때만 적용된다. 상세한 유효 기간과 좌표 변환은 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)에 있다.

## 개발 예정 기능

- 영상을 수천 개의 파티클로 재구성
- 움직임 감지
- 움직임이 있을 때 입자 분산
- 청록색과 보라색 네온
- 과거 모습의 잔상
- 움직임이 멈추면 현재 모습으로 복원

카메라 권한, 검색 방식, 실패 시 점검, 파티클 연결 방법은 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)에 있다.

## 디렉터리

```text
ECHOES-OF-MEMORY/
├── EchoesOfMemory/
│   ├── EchoesOfMemory.pde
│   ├── CameraManager.pde
│   ├── Particle.pde
│   ├── ParticleSystem.pde
│   ├── MotionDetector.pde
│   ├── EchoSystem.pde
│   ├── NeonEffects.pde
│   └── data/
├── docs/
│   └── DEVELOPMENT.md
├── README.md
└── .gitignore
```
