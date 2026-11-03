// ECHOES OF MEMORY
// 2단계: 카메라 입력 + 무작위 점 찍기.
// 매 프레임 카메라 영상에서 무작위 위치의 색을 골라 점으로 찍는다.
// 파티클, 움직임 감지, 잔상, 네온은 아직 만들지 않는다.
// captureEvent()는 사용하지 않는다. 프레임은 draw()에서 한 번만 읽는다.

CameraManager camera;
DotPainter painter;

void setup() {
  size(1280, 720);
  pixelDensity(displayDensity());
  frameRate(60);
  surface.setTitle("ECHOES OF MEMORY");

  camera = new CameraManager(this);
  camera.extraShortcuts = "V: Dots    X: Clear    S: Save";
  camera.begin();
  painter = new DotPainter(this);
}

void draw() {
  background(#080D18);
  camera.update();
  // 이후 단계에서는 이 위치에서 camera.frame()과 camera.pixelColor()를
  // ParticleSystem과 MotionDetector가 함께 사용한다.
  painter.update(camera);
  camera.extraStatus = painter.statusLine();

  if (painter.enabled) {
    painter.draw();
    camera.drawChrome();
  } else {
    camera.drawView();
  }
}

void keyPressed() {
  if (camera == null || key == CODED) return;

  char command = Character.toLowerCase(key);
  if (command == 'v') {
    painter.toggle();
  } else if (command == 'x') {
    painter.clear();
  } else if (command == 's') {
    painter.save();
  } else {
    camera.handleKey(key);
    // 카메라나 반전이 바뀌면 이전 점과 위치가 맞지 않으므로 지운다.
    if (command == 'c' || command == 'r' || command == 'm') painter.clear();
  }
}
