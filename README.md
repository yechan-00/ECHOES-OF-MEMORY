# ECHOES OF MEMORY

MacBook 카메라로 관람객의 모습을 실시간 촬영하고, 그 형상을 수천 개의 파티클로 보여주는 인터랙티브 미디어 아트 작품이다. 움직임이 감지되면 입자가 흩어지며 청록색과 보라색 네온, 그리고 과거 모습의 잔상이 나타난다. 움직임이 멈추면 입자는 현재 모습으로 돌아온다.

이 저장소는 Processing 4 Java Mode 스케치다.

## 현재 단계

1단계 프로젝트 초기화만 되어 있다.

- 1280×720 시작 화면
- 배경색 `#080D18`
- 중앙 제목 `ECHOES OF MEMORY`
- 제목 아래 `Interactive Particle Portrait`
- 화면 하단 `SYSTEM INITIALIZED`

카메라 입력, 파티클, 움직임 감지, 잔상, 네온 효과는 아직 없다. 해당 파일에는 담당 기능을 설명하는 주석만 있다.

이 초기화 작업에서는 Processing을 실행하지 않았다. 아래 방법으로 직접 실행해 창이 열리는지 확인해 달라.

## 실행 환경

- Processing 4
- Mode: Java
- 추가 라이브러리 없음

Processing 설치본에 Java가 포함되어 있으므로, 스케치를 실행하기 위해 별도의 JDK를 설치할 필요는 없다.

## 실행 방법

1. [Processing 4](https://processing.org/download)를 설치한다.
2. Processing에서 `EchoesOfMemory/EchoesOfMemory.pde`를 연다.
3. 스케치 폴더 이름이 `EchoesOfMemory`인지 확인한다. Processing은 폴더 이름과 메인 파일 이름이 같아야 한다.
4. Run을 누른다. macOS는 `⌘R`, Windows는 `Ctrl+R`이다.
5. 1280×720 창에 위 세 줄의 글자가 보이는지 확인한다.

## 개발 예정 기능

- 실시간 카메라 촬영
- 영상을 수천 개의 파티클로 재구성
- 움직임 감지
- 움직임이 있을 때 입자 분산
- 청록색과 보라색 네온
- 과거 모습의 잔상
- 움직임이 멈추면 현재 모습으로 복원

Mac과 Windows에서 함께 작업하는 방법과 파일별 담당 범위는 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)에 정리되어 있다.

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
