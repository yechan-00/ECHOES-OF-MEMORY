// ECHOES OF MEMORY
// 2단계: 카메라 입력.
// 파티클, 움직임 감지, 잔상, 네온은 아직 만들지 않는다.
// captureEvent()는 사용하지 않는다. 프레임은 draw()에서 한 번만 읽는다.

CameraManager camera;

void setup() {
  size(1280, 720);
  pixelDensity(displayDensity());
  frameRate(60);
  surface.setTitle("ECHOES OF MEMORY");

  camera = new CameraManager(this);
  camera.begin();
}

void draw() {
  background(#080D18);
  camera.update();
  // 이후 단계에서는 이 위치에서 camera.frame()과 camera.pixelColor()를
  // ParticleSystem과 MotionDetector가 함께 사용한다.
  camera.drawView();
}

void keyPressed() {
  if (camera != null && key != CODED) {
    camera.handleKey(key);
  }
}
