# ECHOES OF MEMORY 개발 가이드

Processing 4 Java Mode로 Mac과 Windows에서 같은 스케치를 개발하기 위한 기준이다.

## 공통 규칙

- 스케치 폴더 이름 `EchoesOfMemory`와 메인 파일 `EchoesOfMemory.pde`를 유지한다. Processing은 둘의 이름이 같아야 스케치로 연다.
- 소스와 문서는 UTF-8로 저장한다.
- 1단계 시작 화면은 Processing 기본 API만 사용한다. 외부 라이브러리를 추가하지 않는다.
- 경로는 `sketchPath()`와 `dataPath()`로 다룬다. `C:\`나 `/Users/...`처럼 한 운영체제에만 해당하는 경로를 코드에 넣지 않는다.
- 이미지, 폰트 등 공유 파일은 `EchoesOfMemory/data/`에 둔다.
- 기능 구현은 아래 담당 파일 안에서 추가한다. 아직 클래스와 함수가 없는 파일을 다른 파일에서 호출하지 않는다.
- `.DS_Store`, `Thumbs.db`, IDE 임시 파일은 `.gitignore`에 의해 제외된다. 저장소에 올리지 않는다.

Processing 4 설치본에 Java가 포함된다. 스케치 실행을 위해 별도의 JDK를 맞출 필요는 없다. 가능하면 같은 Processing 4 버전을 사용한다.

## Mac

- 작품의 촬영 대상은 MacBook 내장 카메라다. 카메라 연결은 이후 단계에서 `CameraManager.pde`에 구현한다.
- Processing에서 `EchoesOfMemory.pde`를 열고 `⌘R`로 실행한다.
- 글자 표시에는 Java 논리 글꼴 `SansSerif`, `Monospaced`만 사용한다. Mac 전용 글꼴 이름을 코드에 넣지 않는다.

## Windows

- 내장 카메라가 없는 환경에서는 웹캠을 사용한다. 장치 이름과 순서는 Mac과 다를 수 있다.
- 이후 `CameraManager`는 특정 Mac 카메라 이름을 고정하지 않고, 사용 가능한 장치 목록에서 선택하도록 만든다.
- Processing에서 `EchoesOfMemory.pde`를 열고 `Ctrl+R`로 실행한다.
- `Thumbs.db`와 `Desktop.ini`가 생겨도 커밋하지 않는다.

## 이후 라이브러리

1단계에는 추가 라이브러리가 없다.

카메라 단계를 시작할 때 양쪽 모두 Processing Contribution Manager에서 **Video** 라이브러리를 같은 버전으로 설치한다. 설치 전에는 `processing.video`를 import하지 않는다.

## 담당 파일

| 파일 | 담당 |
| --- | --- |
| `EchoesOfMemory.pde` | 스케치 진입점. `setup()`, `draw()`, 화면 크기와 시작 화면 |
| `CameraManager.pde` | 실시간 카메라 입력과 현재 프레임 전달 |
| `Particle.pde` | 입자 하나의 위치, 색, 흩어짐과 복귀 상태 |
| `ParticleSystem.pde` | 수천 개 입자의 생성, 분산, 현재 모습으로의 복원 |
| `MotionDetector.pde` | 연속 프레임 비교와 움직임 양 판단 |
| `EchoSystem.pde` | 움직임이 있을 때 남기는 과거 모습의 잔상 |
| `NeonEffects.pde` | 청록색과 보라색 네온 발광 |
| `EchoesOfMemory/data/` | 양쪽에서 함께 쓰는 리소스 |

`EchoesOfMemory.pde`를 제외한 PDE 파일은 현재 주석만 있다. 클래스 선언도 없다.

## 구현 순서

1. 프로젝트 초기화와 시작 화면. 현재 단계.
2. 카메라 입력.
3. 파티클 초상.
4. 움직임 감지와 입자의 흩어짐, 복원.
5. 잔상.
6. 청록색·보라색 네온.

한 단계의 실행을 확인한 뒤에 다음 단계로 넘어간다. Git commit과 push는 시작 화면 실행을 확인한 다음 진행한다.
