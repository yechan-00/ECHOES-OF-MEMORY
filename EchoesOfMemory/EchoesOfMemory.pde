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

  camera = new CameraManager(this);
  particles = new ParticleSystem(this);
  backgroundMask = new BackgroundMask(this);
  camera.begin();
  motion = new MotionDetector(this, camera);
}

void draw() {
  background(#080D18);
  camera.update();
  backgroundMask.update(camera);
  updateMotion();

  boolean showParticles = particleMode && camera.pixelsReady();
  if (showParticles) {
    particles.setScatterHeld(spaceScatter);
    particles.setPointerEnabled(!maskDebug);
    applyMotionForce();
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
  if (key == ' ') {
    spaceScatter = true;
    return;
  }
  if (camera == null || key == CODED) return;
  if (key == 'p' || key == 'P') {
    particleMode = !particleMode;
    return;
  }
  if (key == 'b' || key == 'B') {
    backgroundMask.beginCapture(camera);
    return;
  }
  if (key == 'v' || key == 'V') {
    maskDebug = !maskDebug;
    return;
  }
  camera.handleKey(key);
  if (motion != null) {
    motion.handleKey(key);
    char command = Character.toLowerCase(key);
    if (command == 'c' || command == 'r') motion.reset();
  }
}

void keyReleased() {
  if (key == ' ') spaceScatter = false;
}
