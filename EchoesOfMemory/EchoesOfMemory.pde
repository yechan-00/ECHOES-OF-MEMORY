// ECHOES OF MEMORY
// 파티클 초상화, 기준 배경 차분, 스프링 복원, 움직임 감지.
// 잔상과 네온은 아직 만들지 않는다.
// 프레임은 CameraManager.update()에서 한 번만 읽는다.

CameraManager camera;
ParticleSystem particles;
BackgroundMask backgroundMask;
MotionDetector motion;
boolean particleMode = false;
boolean maskDebug = false;
boolean spaceScatter = false;
boolean motionFailed = false;
// A: 둘 다 false. B: 감지만 true. C: 둘 다 true.
boolean ENABLE_MOTION_DETECTION = true;
boolean ENABLE_MOTION_FORCE = true;
boolean cameraBegun = false;
boolean startupFrameShown = false;
PFont startupFont;

static final float MOTION_MIN_TOTAL = 0.04;
static final float MOTION_RADIUS_MIN = 90;
static final float MOTION_RADIUS_MAX = 210;
static final float MOTION_FORCE_MAX = 3.6;

void settings() {
  fullScreen();
  pixelDensity(displayDensity());
}

void setup() {
  frameRate(60);
  surface.setTitle("ECHOES OF MEMORY");

  try {
    camera = new CameraManager(this);
    particles = new ParticleSystem(this);
    backgroundMask = new BackgroundMask(this);
    if (ENABLE_MOTION_DETECTION) motion = new MotionDetector(this, camera);
  } catch (Throwable problem) {
    println("[INIT] setup failed: " + problem.getClass().getName() + ": " + problem.getMessage());
    problem.printStackTrace();
    if (problem instanceof RuntimeException) throw (RuntimeException) problem;
    if (problem instanceof Error) throw (Error) problem;
    throw new RuntimeException(problem);
  }
}

void draw() {
  background(8, 13, 24);

  // 카메라 연결보다 먼저 한 프레임을 화면에 올린다.
  if (!startupFrameShown) {
    startupFrameShown = true;
    drawStartup();
    return;
  }
  if (!cameraBegun) {
    cameraBegun = true;
    try {
      camera.begin();
    } catch (Throwable problem) {
      println("[INIT] camera initialization failed: " + problem.getClass().getName() + ": " + problem.getMessage());
      problem.printStackTrace();
    }
  }

  camera.update();
  backgroundMask.update(camera);
  if (ENABLE_MOTION_DETECTION) updateMotion();

  boolean showParticles = particleMode && camera.pixelsReady();
  if (showParticles) {
    particles.setScatterHeld(spaceScatter);
    particles.setPointerEnabled(!maskDebug);
    if (ENABLE_MOTION_DETECTION && ENABLE_MOTION_FORCE) applyMotionForce();
    particles.update(camera, backgroundMask);
    if (maskDebug && backgroundMask.isReady()) backgroundMask.drawMask(camera);
    else particles.draw();
  } else if (maskDebug && backgroundMask.isReady()) {
    backgroundMask.drawMask(camera);
  } else {
    camera.drawView();
  }

  backgroundMask.drawNotice(maskDebug);
  if (maskDebug) particles.drawDebug(backgroundMask);
  if (motion != null && motion.showDebug) motion.drawDebug();
}

void drawStartup() {
  if (startupFont == null) startupFont = createFont("SansSerif", 28);
  fill(244, 251, 255);
  textFont(startupFont);
  textAlign(CENTER, CENTER);
  textSize(28);
  text("ECHOES OF MEMORY", width / 2.0, height / 2.0 - 24);
  textSize(16);
  text("카메라를 연결하는 중", width / 2.0, height / 2.0 + 18);
}

void updateMotion() {
  if (motion == null) return;
  try {
    motion.update();
    motionFailed = false;
  } catch (Throwable problem) {
    motion.reset();
    if (!motionFailed) {
      motionFailed = true;
      println("ECHOES motion update failed: " + problem.getClass().getSimpleName());
    }
  }
}

void applyMotionForce() {
  if (motion == null || motion.center == null) return;
  if (motion.total < MOTION_MIN_TOTAL) return;
  float amount = motion.total;
  if (amount > 1) amount = 1;
  float radius = MOTION_RADIUS_MIN + (MOTION_RADIUS_MAX - MOTION_RADIUS_MIN) * amount;
  float strength = MOTION_FORCE_MAX * amount;
  particles.pushAt(motion.center.x, motion.center.y, radius, strength);
}

void keyPressed() {
  if (key == ' ' || keyCode == ' ') {
    spaceScatter = true;
    return;
  }
  if (camera == null) return;
  char command = commandKey();
  if (command == 0) return;
  if (command == 'p') {
    particleMode = !particleMode;
    return;
  }
  if (command == 'b') {
    backgroundMask.beginCapture(camera);
    return;
  }
  if (command == 'v') {
    maskDebug = !maskDebug;
    return;
  }
  camera.handleKey(command);
  if (motion != null) {
    motion.handleKey(command);
    if (command == 'c' || command == 'r') motion.reset();
  }
}

// 한글 입력기에서는 문자가 ㅔ, ㅠ처럼 들어오고 keyCode만 물리 키를 유지한다.
char commandKey() {
  if (key >= 'a' && key <= 'z') return key;
  if (key >= 'A' && key <= 'Z') return Character.toLowerCase(key);
  if (key == '[' || key == ']') return key;
  if (keyCode == 'P') return 'p';
  if (keyCode == 'B') return 'b';
  if (keyCode == 'V') return 'v';
  if (keyCode == 'G') return 'g';
  if (keyCode == 'H') return 'h';
  if (keyCode == 'C') return 'c';
  if (keyCode == 'R') return 'r';
  if (keyCode == 'M') return 'm';
  if (keyCode == '[') return '[';
  if (keyCode == ']') return ']';
  return 0;
}

void keyReleased() {
  if (key == ' ' || keyCode == ' ') spaceScatter = false;
}
