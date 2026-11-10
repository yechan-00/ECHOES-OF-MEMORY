// ParticleSystem
//
// 카메라 밝기를 청록·보라 팔레트의 작은 빛 입자로 바꾼다.
// 기준 배경이 있으면 인물 영역만 밝히고, 배경은 고정된 낮은 밀도로 남긴다.
// home으로 스프링 복원하고, SPACE와 마우스 주변에는 흩어지는 힘을 더한다.

class ParticleSystem {
  static final int SAMPLE_STEP = 5;
  static final float PARTICLE_SIZE = 2.8;
  static final float JITTER_AMOUNT = 0.42;
  static final int BLUR_STRENGTH = 4;
  static final int BRIGHTNESS_LEVELS = 8;
  static final float FLOAT_AMPLITUDE = 0.6;
  static final float FLOAT_SPEED = 0.65;
  static final boolean PALETTE_SMOOTH = true;
  static final boolean USE_SOURCE_COLOR = false;
  static final float LUMA_GAMMA = 0.7;
  static final float ALPHA_MIN = 150;
  static final float ALPHA_MAX = 210;
  static final float MASK_DRAW_CUT = 0.08;
  static final float SPRING_STRENGTH = 0.06;
  static final float DAMPING = 0.86;
  static final float MAX_DELTA = 0.05;
  static final float MAX_SPEED = 16;
  static final float SPACE_FORCE = 5.4;
  static final float MOUSE_RADIUS = 120;
  static final float MOUSE_FORCE = 2.5;
  static final float MOTION_MIN_INTENSITY = 0.12;
  static final float MOTION_FORCE = 2.8;
  static final float MOTION_RADIUS = 48;
  static final float MOTION_TWIST = 0.35;
  // 움직이는 방향으로 쓸어내는 힘. motion.speed()가 SWEEP_MIN_SPEED 이상일 때만 걸린다.
  // 전체 화면 실측(2026-11-10, Windows): 손을 흔들 때 speed 평균 약 18, 크게 휘두르면 60~110.
  static final float MOTION_SWEEP = 5.0;
  static final float MOTION_SWEEP_MIN_SPEED = 4;     // px/카메라 프레임
  static final float MOTION_SWEEP_FULL_SPEED = 25;   // 이 속도에서 쓸어내는 힘이 최대가 된다
  static final float MOTION_RADIAL_KEEP = 0.6;       // 쓸어낼 때 바깥으로 미는 힘을 남기는 비율
  // 움직임 힘에 맞은 입자는 스프링이 풀려 밀려난 자리에 머물다 돌아온다.
  static final float RELEASE_SECONDS = 1.6;   // release가 1에서 0으로 돌아오는 시간
  static final float RELEASE_GAIN = 2.5;      // 감쇠(falloff)에 곱한다. 국소 중심 가까이는 바로 1이 된다
  static final float RELEASE_CURVE = 3;       // 스프링 = (1 - release)^CURVE. 클수록 오래 비어 있다
  static final float PRESENCE_RESPONSE = 0.18;
  static final float ACTIVATION_RESPONSE = 0.22;
  static final float MOTION_TINT_RESPONSE = 0.16;
  static final float SPARSE_AMBIENT = 0.18;
  static final float BALANCED_AMBIENT = 0.38;
  static final float SPARSE_AMBIENT_ALPHA = 28;
  static final float BALANCED_AMBIENT_ALPHA = 42;
  static final float SPARSE_AMBIENT_SIZE = 1.15;
  static final float BALANCED_AMBIENT_SIZE = 1.35;
  static final float AMBIENT_FLOAT = 0.22;
  static final int POINTER_IDLE_MS = 140;
  static final int MAX_FORCES = 8;

  final int[] PALETTE = {
    0xFF6D4AA8,
    0xFF9B72E8,
    0xFF4B8FE0,
    0xFF38E8D5,
    0xFFA5FFF2
  };

  PApplet app;
  PFont debugFont;
  Particle[] particles = new Particle[0];
  int count = 0;
  int drawn = 0;
  int sourceWidth = -1;
  int sourceHeight = -1;
  float jitterSpan = 0;
  float lastSpacing = -1;
  float[] toneLut = new float[256];
  int[] inkLut = new int[256];
  float[] forceX = new float[MAX_FORCES];
  float[] forceY = new float[MAX_FORCES];
  float[] forceR = new float[MAX_FORCES];
  float[] forceS = new float[MAX_FORCES];
  int forceCount = 0;
  int lastPhysicsAt = 0;
  int lastPointerAt = 0;
  float lastPointerX = 0;
  float lastPointerY = 0;
  boolean pointerSeen = false;
  boolean scatterHeld = false;
  boolean pointerEnabled = false;
  boolean pointerHot = false;
  boolean motionHot = false;
  int visualPreset = 0;
  int motionCols = 0;
  int motionRows = 0;
  int motionTouched = 0;
  float[] motionWeight = new float[0];
  float[] motionOriginX = new float[0];
  float[] motionOriginY = new float[0];
  float[] motionPeak = new float[0];
  int[] motionTouch = new int[0];
  float motionAddX = 0;
  float motionAddY = 0;
  float motionHit = 0;        // accumulateMotion이 계산한 감쇠. release에 쓴다
  // prepareMotion에서 motion.velocity로 정한다. 모든 칸에 같은 방향으로 걸린다.
  float sweepX = 0;
  float sweepY = 0;
  float radialScale = 1;

  ParticleSystem(PApplet app) {
    this.app = app;
    debugFont = app.createFont("Monospaced", 13);
    for (int i = 0; i < 256; i++) {
      float t = app.pow(i / 255f, LUMA_GAMMA);
      toneLut[i] = t;
      inkLut[i] = paletteColor(t);
    }
  }

  int size() {
    return count;
  }

  void setScatterHeld(boolean held) {
    scatterHeld = held;
  }

  void setPointerEnabled(boolean enabled) {
    pointerEnabled = enabled;
  }

  void setVisualPreset(int preset) {
    visualPreset = preset == 1 ? 1 : 0;
    println("[VISUAL] Preset: " + visualPresetName());
  }

  String visualPresetName() {
    return visualPreset == 1 ? "BALANCED" : "SPARSE";
  }

  float ambientKeep() {
    return visualPreset == 1 ? BALANCED_AMBIENT : SPARSE_AMBIENT;
  }

  float ambientAlpha() {
    return visualPreset == 1 ? BALANCED_AMBIENT_ALPHA : SPARSE_AMBIENT_ALPHA;
  }

  float ambientSize() {
    return visualPreset == 1 ? BALANCED_AMBIENT_SIZE : SPARSE_AMBIENT_SIZE;
  }

  String motionLabel() {
    String label = "spring";
    if (scatterHeld && pointerHot) label = "spring + space + mouse";
    else if (scatterHeld) label = "spring + space";
    else if (pointerHot) label = "spring + mouse";
    if (motionHot) label += " + motion";
    return label;
  }

  void clearMotion() {
    motionHot = false;
    clearMotionField();
  }

  // 칸마다 한 번만 힘을 펼치고, 파티클은 home이 속한 칸을 한 번 읽는다.
  void prepareMotion(MotionDetector motion) {
    clearMotionField();
    if (motion == null || motion.grid == null || motion.cols < 1 || motion.rows < 1) return;
    prepareSweep(motion);
    int cols = motion.cols;
    int rows = motion.rows;
    int cells = cols * rows;
    if (motion.grid.length < cells) return;
    ensureMotionBuffers(cols, rows);

    float cell = MotionDetector.CELL_SIZE;
    float radius = MOTION_RADIUS;
    float radiusSq = radius * radius;
    int reach = (int) Math.ceil(radius / cell);
    if (reach < 1) reach = 1;
    float[] source = motion.grid;

    for (int row = 0; row < rows; row++) {
      int rowIndex = row * cols;
      float sourceY = (row + 0.5f) * cell;
      for (int col = 0; col < cols; col++) {
        float intensity = source[rowIndex + col];
        if (intensity < MOTION_MIN_INTENSITY) continue;
        float sourceX = (col + 0.5f) * cell;
        int row0 = row - reach;
        int row1 = row + reach;
        int col0 = col - reach;
        int col1 = col + reach;
        if (row0 < 0) row0 = 0;
        if (col0 < 0) col0 = 0;
        if (row1 >= rows) row1 = rows - 1;
        if (col1 >= cols) col1 = cols - 1;
        for (int ry = row0; ry <= row1; ry++) {
          float dy = sourceY - (ry + 0.5f) * cell;
          int base = ry * cols;
          for (int rx = col0; rx <= col1; rx++) {
            float dx = sourceX - (rx + 0.5f) * cell;
            float distSq = dx * dx + dy * dy;
            if (distSq > radiusSq) continue;
            float fall = 1f - (float) Math.sqrt(distSq) / radius;
            if (fall <= 0) continue;
            int index = base + rx;
            if (motionWeight[index] == 0 && motionPeak[index] == 0) {
              motionTouch[motionTouched] = index;
              motionTouched++;
            }
            float weight = intensity * fall;
            motionWeight[index] += weight;
            motionOriginX[index] += sourceX * weight;
            motionOriginY[index] += sourceY * weight;
            if (intensity > motionPeak[index]) motionPeak[index] = intensity;
          }
        }
      }
    }
    motionHot = motionTouched > 0;
  }

  // 빠를수록 바깥으로 퍼지는 힘을 줄이고 움직이는 방향으로 쓸어낸다.
  void prepareSweep(MotionDetector motion) {
    sweepX = 0;
    sweepY = 0;
    radialScale = 1;
    float speed = motion.speed();
    if (speed < MOTION_SWEEP_MIN_SPEED) return;
    float amount = (speed - MOTION_SWEEP_MIN_SPEED) / (MOTION_SWEEP_FULL_SPEED - MOTION_SWEEP_MIN_SPEED);
    if (amount > 1) amount = 1;
    sweepX = motion.velocity.x / speed * MOTION_SWEEP * amount;
    sweepY = motion.velocity.y / speed * MOTION_SWEEP * amount;
    radialScale = 1f - (1f - MOTION_RADIAL_KEEP) * amount;
  }

  // 다음 update() 한 번만 적용된다. 움직임 감지 쪽은 화면 좌표와 세기만 넘기면 된다.
  void pushAt(float screenX, float screenY, float radius, float strength) {
    if (forceCount >= MAX_FORCES || radius <= 1f) return;
    if (strength == 0 || strength != strength) return;
    forceX[forceCount] = screenX;
    forceY[forceCount] = screenY;
    forceR[forceCount] = radius;
    forceS[forceCount] = strength;
    forceCount++;
  }

  void update(CameraManager camera, BackgroundMask backgroundMask) {
    if (camera == null || !camera.pixelsReady()) {
      forceCount = 0;
      pointerHot = false;
      return;
    }

    int frameW = camera.frameWidth();
    int frameH = camera.frameHeight();
    if (frameW <= 0 || frameH <= 0) {
      forceCount = 0;
      pointerHot = false;
      return;
    }
    drawn = 0;
    boolean useMask = backgroundMask != null && backgroundMask.isReady();

    float originX = camera.frameToScreenX(0);
    float scaleX = (camera.frameToScreenX(frameW) - originX) / frameW;
    float originY = camera.frameToScreenY(0);
    float scaleY = (camera.frameToScreenY(frameH) - originY) / frameH;
    float spacing = app.min(app.abs(scaleX), app.abs(scaleY)) * SAMPLE_STEP;
    if (spacing <= 0) spacing = SAMPLE_STEP;

    boolean refreshColor = ensureGrid(frameW, frameH) || camera.hasNewFrame();
    boolean spacingChanged = app.abs(spacing - lastSpacing) > 0.5f;
    lastSpacing = spacing;
    jitterSpan = spacing * JITTER_AMOUNT;

    int[] pixels = null;
    if (refreshColor || spacingChanged) {
      PImage source = camera.frame();
      if (source != null) pixels = source.pixels;
    }

    int now = app.millis();
    float dt = lastPhysicsAt == 0 ? 1f / 60f : (now - lastPhysicsAt) / 1000f;
    lastPhysicsAt = now;
    if (dt < 0) dt = 1f / 60f;
    if (dt > MAX_DELTA) dt = MAX_DELTA;
    float step = dt * 60f;
    float damp = (float) Math.pow(DAMPING, step);
    float blend = PRESENCE_RESPONSE * step;
    if (blend > 1) blend = 1;
    float actBlend = ACTIVATION_RESPONSE * step;
    if (actBlend > 1) actBlend = 1;
    float tintBlend = MOTION_TINT_RESPONSE * step;
    if (tintBlend > 1) tintBlend = 1;
    float keep = ambientKeep();
    pointerHot = pointerActive(now);

    float centerX = originX + scaleX * frameW * 0.5f;
    float centerY = originY + scaleY * frameH * 0.5f;
    float mouseX = app.mouseX;
    float mouseY = app.mouseY;
    float mouseR2 = MOUSE_RADIUS * MOUSE_RADIUS;
    float minX = -48;
    float minY = -48;
    float maxX = app.width + 48;
    float maxY = app.height + 48;
    boolean pushing = scatterHeld || pointerHot || forceCount > 0 || motionHot;

    for (int i = 0; i < count; i++) {
      Particle particle = particles[i];
      if (!camera.pixelInRange(particle.sampleX, particle.sampleY)) {
        particle.approachPresence(0, blend);
        particle.approachActivation(0, actBlend);
        particle.visible = false;
        continue;
      }

      float sx = originX + (particle.sampleX + 0.5f) * scaleX;
      float sy = originY + (particle.sampleY + 0.5f) * scaleY;
      if (sx < 0 || sy < 0 || sx > app.width || sy > app.height) {
        particle.approachPresence(0, blend);
        particle.approachActivation(0, actBlend);
        particle.visible = particle.activation > 0.03f || particle.fieldRank < keep;
        if (particle.visible) drawn++;
        continue;
      }

      float target = 1;
      if (useMask) {
        float coverage = backgroundMask.maskAt(particle.sampleX, particle.sampleY);
        target = coverage < MASK_DRAW_CUT ? 0 : coverage;
      }

      particle.place(sx, sy);
      particle.approachPresence(target, blend);
      particle.approachActivation(target, actBlend);
      if (particle.motionTint > 0.003f || (motionHot && target > 0.03f)) {
        float tintTarget = motionHot && target > 0.03f ? motionLevel(particle) : 0;
        particle.approachMotion(tintTarget, tintBlend);
      }
      boolean lively = target > 0.03f || particle.presence > 0.03f || particle.speedSq > 0.05f;
      if (pixels != null && lively) {
        applySample(pixels, frameW, frameH, particle, spacing);
      }
      particle.visible = particle.fieldRank < keep || (particle.activation > 0.03f && particle.alpha > 1f);

      if (!lively) {
        if (particle.visible) drawn++;
        continue;
      }
      if (!particle.anchored) {
        if (particle.visible) drawn++;
        continue;
      }

      float releaseDecay = step / (60f * RELEASE_SECONDS);
      particle.release = particle.release > releaseDecay ? particle.release - releaseDecay : 0;
      float spring = SPRING_STRENGTH * (float) Math.pow(1f - particle.release, RELEASE_CURVE);
      float ax = (particle.home.x - particle.position.x) * spring;
      float ay = (particle.home.y - particle.position.y) * spring;

      if (scatterHeld && (target > 0.03f || particle.presence > 0.03f)) {
        float outwardX = particle.home.x - centerX;
        float outwardY = particle.home.y - centerY;
        float twist = particle.jitterX * 0.55f;
        float rx = outwardX - outwardY * twist;
        float ry = outwardY + outwardX * twist;
        float mag2 = rx * rx + ry * ry;
        float minMag = spacing * spacing;
        if (mag2 < minMag) {
          rx = particle.jitterX;
          ry = particle.jitterY;
          mag2 = rx * rx + ry * ry;
          if (mag2 < 0.01f) mag2 = 0.01f;
        }
        float inv = 1f / (float) Math.sqrt(mag2);
        float power = SPACE_FORCE * (0.75f + 0.4f * particle.sizeBias);
        ax += rx * inv * power;
        ay += ry * inv * power;
      }

      if (pointerHot) {
        float dx = particle.position.x - mouseX;
        float dy = particle.position.y - mouseY;
        float d2 = dx * dx + dy * dy;
        if (d2 < mouseR2 && d2 > 0.25f) {
          float falloff = 1f - d2 / mouseR2;
          falloff *= falloff;
          float inv = 1f / (float) Math.sqrt(d2);
          ax += dx * inv * MOUSE_FORCE * falloff;
          ay += dy * inv * MOUSE_FORCE * falloff;
        }
      }

      if (motionHot && particle.presence > 0.02f) {
        accumulateMotion(particle);
        ax += motionAddX;
        ay += motionAddY;
        float hit = motionHit * RELEASE_GAIN;
        if (hit > 1) hit = 1;
        if (hit > particle.release) particle.release = hit;
      }

      if (forceCount > 0 && particle.presence > 0.02f) {
        float px = particle.position.x;
        float py = particle.position.y;
        for (int f = 0; f < forceCount; f++) {
          float dx = px - forceX[f];
          float dy = py - forceY[f];
          float radius = forceR[f];
          float r2 = radius * radius;
          float d2 = dx * dx + dy * dy;
          if (d2 >= r2 || d2 < 0.25f) continue;
          float falloff = 1f - d2 / r2;
          falloff *= falloff;
          float inv = 1f / (float) Math.sqrt(d2);
          ax += dx * inv * forceS[f] * falloff;
          ay += dy * inv * forceS[f] * falloff;
        }
      }

      float homeX = particle.home.x - particle.position.x;
      float homeY = particle.home.y - particle.position.y;
      if (!pushing && homeX * homeX + homeY * homeY < 0.2f && particle.speedSq < 0.02f) {
        particle.position.x = particle.home.x;
        particle.position.y = particle.home.y;
        particle.velocity.x = 0;
        particle.velocity.y = 0;
        particle.acceleration.x = 0;
        particle.acceleration.y = 0;
        particle.speedSq = 0;
      } else {
        particle.stepPhysics(step, damp, ax, ay, MAX_SPEED, minX, minY, maxX, maxY);
      }
      if (particle.visible) drawn++;
    }
    forceCount = 0;
  }

  boolean pointerActive(int now) {
    if (!pointerEnabled) return false;
    float mx = app.mouseX;
    float my = app.mouseY;
    if (mx < 0 || my < 0 || mx >= app.width || my >= app.height) return false;
    if (!pointerSeen) {
      pointerSeen = true;
      lastPointerX = mx;
      lastPointerY = my;
      return false;
    }
    float dx = mx - lastPointerX;
    float dy = my - lastPointerY;
    if (dx * dx + dy * dy > 0.36f) {
      lastPointerAt = now;
      lastPointerX = mx;
      lastPointerY = my;
    }
    return now - lastPointerAt < POINTER_IDLE_MS;
  }

  void draw() {
    float seconds = app.millis() * 0.001;
    float keep = ambientKeep();
    float alpha = ambientAlpha();
    float dia = ambientSize();
    app.noStroke();
    for (int i = 0; i < count; i++) {
      particles[i].draw(app, seconds, jitterSpan, keep, alpha, dia, AMBIENT_FLOAT);
    }
  }

  void drawDebug(BackgroundMask backgroundMask) {
    String stats = count + " particles    " + drawn + " shown    " + (int) app.frameRate + " fps";
    String motion = motionLabel();
    String state = backgroundMask == null ? "" : backgroundMask.statusLabel();
    String keys = "P Portrait    1 Sparse    2 Balanced    Space    Mouse    G Motion    B V C R M H";

    app.noStroke();
    app.rectMode(PApplet.CORNER);
    app.textFont(debugFont);
    float boxW = app.max(app.textWidth(stats), app.max(app.textWidth(motion), app.textWidth(state))) + 28;
    app.fill(8, 13, 24, 210);
    app.rect(12, 12, boxW, 68);
    app.fill(#38E8D5);
    app.textAlign(PApplet.LEFT, PApplet.CENTER);
    app.text(stats, 24, 26);
    app.text(motion, 24, 46);
    if (state.length() > 0) app.text(state, 24, 66);

    app.fill(8, 13, 24, 210);
    app.rect(0, app.height - 36, app.width, 36);
    app.fill(#A78BFA);
    app.textAlign(PApplet.CENTER, PApplet.CENTER);
    app.text(keys, app.width / 2.0, app.height - 18);
  }

  void drawModeHint() {
    app.textFont(debugFont);
    app.fill(#A78BFA);
    app.textAlign(PApplet.RIGHT, PApplet.CENTER);
    app.text("P: Portrait", app.width - 24, 28);
  }

  void clearMotionField() {
    for (int i = 0; i < motionTouched; i++) {
      int index = motionTouch[i];
      motionWeight[index] = 0;
      motionOriginX[index] = 0;
      motionOriginY[index] = 0;
      motionPeak[index] = 0;
    }
    motionTouched = 0;
    motionHot = false;
  }

  void ensureMotionBuffers(int cols, int rows) {
    int needed = cols * rows;
    if (motionWeight.length == needed && motionCols == cols && motionRows == rows) return;
    motionWeight = new float[needed];
    motionOriginX = new float[needed];
    motionOriginY = new float[needed];
    motionPeak = new float[needed];
    motionTouch = new int[needed];
    motionCols = cols;
    motionRows = rows;
    motionTouched = 0;
  }

  // home이 속한 칸의 국소 중심에서 바깥으로 밀고, motion.velocity 방향으로 쓸어낸다.
  void accumulateMotion(Particle particle) {
    motionAddX = 0;
    motionAddY = 0;
    motionHit = 0;
    float cell = MotionDetector.CELL_SIZE;
    int col = (int) (particle.home.x / cell);
    int row = (int) (particle.home.y / cell);
    if (col < 0 || row < 0 || col >= motionCols || row >= motionRows) return;
    int index = col + row * motionCols;
    float weight = motionWeight[index];
    float peak = motionPeak[index];
    if (weight <= 0.0001f || peak < MOTION_MIN_INTENSITY) return;

    float centerX = motionOriginX[index] / weight;
    float centerY = motionOriginY[index] / weight;
    float dx = particle.home.x - centerX;
    float dy = particle.home.y - centerY;
    float twist = particle.jitterX * MOTION_TWIST;
    float rx = dx - dy * twist;
    float ry = dy + dx * twist;
    float mag2 = rx * rx + ry * ry;
    if (mag2 < 1f) {
      rx = particle.jitterX;
      ry = particle.jitterY;
      mag2 = rx * rx + ry * ry;
      if (mag2 < 0.01f) mag2 = 0.01f;
    }
    float dist = (float) Math.sqrt(dx * dx + dy * dy);
    if (dist > MOTION_RADIUS) return;
    float falloff = 1f - dist / MOTION_RADIUS;
    falloff *= falloff;
    float inv = 1f / (float) Math.sqrt(mag2);
    float power = MOTION_FORCE * peak * falloff * (0.85f + 0.3f * particle.sizeBias) * radialScale;
    motionAddX = rx * inv * power + sweepX * peak * falloff;
    motionAddY = ry * inv * power + sweepY * peak * falloff;
    motionHit = falloff;
  }

  float motionLevel(Particle particle) {
    if (!motionHot || motionCols < 1) return 0;
    float cell = MotionDetector.CELL_SIZE;
    int col = (int) (particle.home.x / cell);
    int row = (int) (particle.home.y / cell);
    if (col < 0 || row < 0 || col >= motionCols || row >= motionRows) return 0;
    return motionPeak[col + row * motionCols];
  }

  boolean ensureGrid(int frameW, int frameH) {
    if (frameW == sourceWidth && frameH == sourceHeight && particles.length == count) return false;

    int cols = sampleCount(frameW);
    int rows = sampleCount(frameH);
    count = cols * rows;
    sourceWidth = frameW;
    sourceHeight = frameH;
    particles = new Particle[count];

    int index = 0;
    for (int py = SAMPLE_STEP / 2; py < frameH; py += SAMPLE_STEP) {
      for (int px = SAMPLE_STEP / 2; px < frameW; px += SAMPLE_STEP) {
        Particle particle = new Particle();
        particle.prepare(index, px, py);
        particles[index] = particle;
        index++;
      }
    }
    return true;
  }

  int sampleCount(int span) {
    if (span <= SAMPLE_STEP / 2) return 0;
    int samples = 0;
    for (int point = SAMPLE_STEP / 2; point < span; point += SAMPLE_STEP) {
      samples++;
    }
    return samples;
  }

  void applySample(int[] pixels, int frameW, int frameH, Particle particle, float spacing) {
    float luma = blurredLuma(pixels, frameW, frameH, particle.sampleX, particle.sampleY);
    int level = (int) (luma + 0.5f);
    if (level < 0) level = 0;
    if (level > 255) level = 255;
    float t = toneLut[level];

    float unit = spacing * (PARTICLE_SIZE / 6f);
    float sized = unit * particle.sizeBias * app.lerp(0.82, 1, t);
    if (particle.accent) sized *= 1.7;
    sized = app.constrain(sized, unit * 0.55f, spacing * 0.7f);

    float alpha = app.lerp(ALPHA_MIN, ALPHA_MAX, t);
    int ink = USE_SOURCE_COLOR
      ? sourceColor(pixels[particle.sampleY * frameW + particle.sampleX])
      : inkLut[level];
    particle.setAppearance(ink, sized, alpha);
  }

  float blurredLuma(int[] pixels, int frameW, int frameH, int x, int y) {
    int radius = BLUR_STRENGTH;
    int sum = 0;
    int weight = 0;
    int center = lumaAt(pixels, frameW, frameH, x, y);
    if (center >= 0) {
      sum += center * 2;
      weight += 2;
    }
    int east = lumaAt(pixels, frameW, frameH, x + radius, y);
    int west = lumaAt(pixels, frameW, frameH, x - radius, y);
    int south = lumaAt(pixels, frameW, frameH, x, y + radius);
    int north = lumaAt(pixels, frameW, frameH, x, y - radius);
    if (east >= 0) { sum += east; weight++; }
    if (west >= 0) { sum += west; weight++; }
    if (south >= 0) { sum += south; weight++; }
    if (north >= 0) { sum += north; weight++; }
    if (weight <= 0) return 0;
    return sum / (float) weight;
  }

  int lumaAt(int[] pixels, int frameW, int frameH, int x, int y) {
    if (x < 0 || y < 0 || x >= frameW || y >= frameH) return -1;
    int argb = pixels[y * frameW + x];
    int red = (argb >> 16) & 0xff;
    int green = (argb >> 8) & 0xff;
    int blue = argb & 0xff;
    return (red * 54 + green * 183 + blue * 19) >> 8;
  }

  int paletteColor(float t) {
    t = app.constrain(t, 0, 1);
    if (!PALETTE_SMOOTH) {
      int levels = app.max(2, BRIGHTNESS_LEVELS);
      int band = (int) (t * (levels - 1) + 0.5f);
      band = app.constrain(band, 0, levels - 1);
      t = band / (float) (levels - 1);
    }
    float scaled = t * (PALETTE.length - 1);
    int index = (int) scaled;
    if (index >= PALETTE.length - 1) return PALETTE[PALETTE.length - 1];
    return app.lerpColor(PALETTE[index], PALETTE[index + 1], scaled - index, app.RGB);
  }

  int sourceColor(int argb) {
    int red = app.constrain((argb >> 16) & 0xff, 0, 255);
    int green = app.constrain((argb >> 8) & 0xff, 0, 255);
    int blue = app.constrain(argb & 0xff, 0, 255);
    return app.color(red, green, blue);
  }

}
