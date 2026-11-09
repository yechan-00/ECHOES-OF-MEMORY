// ParticleSystem
//
// 카메라 밝기를 청록·보라 팔레트의 작은 빛 입자로 바꾼다.
// 기준 배경이 있으면 BackgroundMask의 전경 값으로 표시 강도를 줄인다.
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
  static final float PRESENCE_RESPONSE = 0.18;
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

  String motionLabel() {
    if (scatterHeld && pointerHot) return "spring + space + mouse";
    if (scatterHeld) return "spring + space";
    if (pointerHot) return "spring + mouse";
    return "spring";
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
    boolean pushing = scatterHeld || pointerHot || forceCount > 0;

    for (int i = 0; i < count; i++) {
      Particle particle = particles[i];
      if (!camera.pixelInRange(particle.sampleX, particle.sampleY)) {
        particle.approachPresence(0, blend);
        particle.visible = false;
        continue;
      }

      float sx = originX + (particle.sampleX + 0.5f) * scaleX;
      float sy = originY + (particle.sampleY + 0.5f) * scaleY;
      if (sx < 0 || sy < 0 || sx > app.width || sy > app.height) {
        particle.approachPresence(0, blend);
        particle.visible = particle.presence > 0.025f;
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
      boolean lively = target > 0.03f || particle.presence > 0.03f || particle.speedSq > 0.05f;
      if (pixels != null && lively) {
        applySample(pixels, frameW, frameH, particle, spacing);
      }
      particle.visible = particle.presence > 0.025f && particle.alpha > 1f;

      if (!lively) {
        if (particle.visible) drawn++;
        continue;
      }
      if (!particle.anchored) {
        if (particle.visible) drawn++;
        continue;
      }

      float ax = (particle.home.x - particle.position.x) * SPRING_STRENGTH;
      float ay = (particle.home.y - particle.position.y) * SPRING_STRENGTH;

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
    app.noStroke();
    for (int i = 0; i < count; i++) {
      particles[i].draw(app, seconds, jitterSpan);
    }
  }

  void drawDebug(BackgroundMask backgroundMask) {
    String stats = count + " particles    " + drawn + " shown    " + (int) app.frameRate + " fps";
    String motion = motionLabel();
    String state = backgroundMask == null ? "" : backgroundMask.statusLabel();
    String keys = "P Portrait    Space Scatter    Mouse Repel    B Background    V Mask    C R M H";

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
