// ECHOES OF MEMORY
// 파티클 초상화, 기준 배경 차분, 스프링 복원.
// 잔상과 네온은 아직 만들지 않는다.
// 프레임은 CameraManager.update()에서 한 번만 읽는다.

CameraManager camera;
ParticleSystem particles;
BackgroundMask backgroundMask;
boolean particleMode = false;
boolean maskDebug = false;
boolean spaceScatter = false;

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
}

void draw() {
  background(#080D18);
  camera.update();
  backgroundMask.update(camera);

  boolean showParticles = particleMode && camera.pixelsReady();
  if (showParticles) {
    particles.setScatterHeld(spaceScatter);
    particles.setPointerEnabled(!maskDebug);
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
}

void keyReleased() {
  if (key == ' ') spaceScatter = false;
}
