// ECHOES OF MEMORY
// 2단계: 카메라 입력. 4단계 일부: 움직임 감지(프레임 차분).
// 파티클, 잔상, 네온은 아직 만들지 않는다.
// captureEvent()는 사용하지 않는다. 프레임은 draw()에서 한 번만 읽는다.

CameraManager camera;
MotionDetector motion;

void setup() {
  size(1280, 720);
  pixelDensity(displayDensity());
  frameRate(60);
  surface.setTitle("ECHOES OF MEMORY");

  camera = new CameraManager(this);
  camera.begin();
  motion = new MotionDetector(this, camera);
}

void draw() {
  background(#080D18);
  camera.update();
  // 감지는 camera.update() 직후, 같은 프레임으로 한 번만 계산한다.
  // ParticleSystem은 이후 motion.grid / motion.intensityAt()을 읽기만 한다.
  motion.update();
  camera.drawView();
  motion.drawDebug();
}

void keyPressed() {
  if (camera != null && key != CODED) {
    camera.handleKey(key);
  }
  if (motion != null && key != CODED) {
    motion.handleKey(key);
  }
}
