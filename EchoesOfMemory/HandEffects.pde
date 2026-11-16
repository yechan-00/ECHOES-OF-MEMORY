// HandEffects
//
// 담당:
// GestureRecognizer가 판별한 손동작을 파티클 힘과 화면 효과로 바꾼다.
// 입자를 직접 움직이지 않는다. ParticleSystem.addHandField()로 힘을 등록하면 update()가 적용한다.
//
// 손동작 → 효과:
//   OPEN     손바닥 중심에서 바깥으로 미는 바람 (PUSH)
//   POINT    검지 끝 주변을 갈라 지나가는 힘 (PUSH, 작은 반지름) + 검지 끝을 따라 남는 네온 궤적
//   PINCH    집은 지점으로 입자를 끌어모아 소용돌이치게 한다 (GATHER + swirl)
//   FIST     손바닥 중심으로 입자를 압축해 붙잡는다 (GATHER, 강하게)
//   PINCH·FIST를 놓는 순간  모았던 입자를 튕겨 흩뿌린다 (BURST). 오래 쥘수록 세다
//   휘두르기  손바닥이 빠르게 움직이면 그 방향으로 쓸어낸다 (SWEEP). 쥐고 있을 때는 걸지 않는다
//   양손      두 손을 빠르게 벌리면 가운데서 흩뿌리고(PUSH), 모으면 가운데로 모은다(GATHER)
//   VICTORY  잔상 소환. EchoSystem이 직접 읽는다
//
// 크기는 모두 손바닥 크기(손목→중지 뿌리) 배수다. 손이 카메라에 가까우면 효과도 커진다.
// 좌표는 GestureRecognizer의 원본 프레임 좌표를 CameraManager.frameToScreenX/Y()로 바꿔 쓴다.

class HandEffects {
  // 손바닥 크기는 1 m 안쪽에서 640x480 프레임 기준 약 80~100 px, 전체 화면에서는 약 200 px이다.
  // 손바닥 바람
  static final float OPEN_RADIUS = 1.8f;        // × 손바닥 크기
  static final float OPEN_FORCE = 3.2f;
  // 검지 가르기
  static final float POINT_RADIUS = 0.5f;
  static final float POINT_FORCE = 4.0f;
  // 집기: 끌어모으기
  static final float PINCH_RADIUS = 1.8f;
  static final float PINCH_FORCE = 2.6f;
  static final float PINCH_CORE = 0.4f;         // 모인 입자가 머무는 반지름 (× 손바닥 크기)
  static final float PINCH_SWIRL = 0.7f;        // 중심을 도는 힘. 손마다 반대 방향 (0.7이면 초당 약 1바퀴)
  // 주먹: 압축
  static final float FIST_RADIUS = 1.6f;
  static final float FIST_FORCE = 4.5f;
  static final float FIST_CORE = 0.35f;
  // 놓는 순간 터뜨리기
  // 입자 속도는 ParticleSystem.MAX_SPEED(16 px/프레임)에서 잘려, 한 번 튕기기만으로는 약 80 px밖에 못 간다.
  // 그래서 놓는 순간 튕긴 뒤 BURST_PUSH_MS 동안 바깥으로 계속 민다.
  static final float BURST_RADIUS = 2.0f;
  static final float BURST_IMPULSE = 14f;       // 놓는 순간 속도에 더하는 양 (px/프레임)
  static final float BURST_PUSH = 4.0f;         // 이어서 미는 가속도. 시간이 지나며 0으로 줄어든다
  static final float BURST_PUSH_REACH = 1.6f;   // 미는 반지름 = BURST_RADIUS × 이 값 (퍼져 나가는 입자를 계속 민다)
  static final int BURST_PUSH_MS = 250;
  static final float BURST_MIN = 0.35f;         // 짧게 쥐었다 놓아도 이만큼은 터진다
  static final int BURST_FULL_HOLD_MS = 900;    // 이만큼 쥐면 최대 세기
  static final int MAX_BURSTS = 4;
  // 휘두르기: 손바닥이 움직이는 방향으로 쓸어낸다. 주먹·집기 중에는 모은 입자를 데려가므로 걸지 않는다
  static final float SWIPE_RADIUS = 1.8f;
  static final float SWIPE_FORCE = 3.5f;
  static final float SWIPE_FULL_SPEED = 16f;    // 이 빠르기(초당 손바닥 몇 개)에서 최대 세기
  // 양손: 빠르게 벌리면 가운데서 흩뿌리고, 빠르게 모으면 가운데로 모은다
  static final float PAIR_RATE_MIN = 1.5f;      // 초당 손바닥 몇 개만큼 거리가 변해야 반응하는지
  static final float PAIR_RATE_FULL = 6f;
  static final float PAIR_FORCE = 3.5f;
  static final float PAIR_CORE = 0.6f;          // 모을 때 머무는 반지름 (× 손바닥 크기)
  // 손이 잡혀 있는 동안 움직임 감지 힘에 곱하는 값
  static final float MOTION_SCALE_WITH_HANDS = 0.3f;

  // 검지 궤적
  static final int TRAIL_MS = 900;              // 궤적 한 점이 사라지기까지
  static final int TRAIL_MAX = 96;              // 손 하나가 가질 수 있는 점 개수
  static final float TRAIL_MIN_STEP = 2f;       // 이보다 적게 움직이면 점을 더하지 않는다 (화면 px)

  static final int COLOR_A = 0xFF38E8D5;
  static final int COLOR_B = 0xFFA78BFA;
  static final int COLOR_CORE = 0xFFE9FFFC;

  PApplet app;
  ArrayList<HandTrail> trails = new ArrayList<HandTrail>();
  // draw()에서 쓸 집기 표시. apply()에서 채운다
  float[] glowX = new float[4];
  float[] glowY = new float[4];
  float[] glowAmount = new float[4];
  float[] glowSize = new float[4];
  boolean[] glowHeld = new boolean[4];
  int glowCount = 0;
  // 놓은 뒤 이어서 미는 중인 터짐 (화면 좌표)
  float[] burstX = new float[MAX_BURSTS];
  float[] burstY = new float[MAX_BURSTS];
  float[] burstR = new float[MAX_BURSTS];
  float[] burstScale = new float[MAX_BURSTS];
  int[] burstStart = new int[MAX_BURSTS];
  int burstCount = 0;

  HandEffects(PApplet app) {
    this.app = app;
  }

  // particles.update() 전에 매 프레임 호출한다. gestures.update()가 같은 draw()에서 먼저 돌아야 한다.
  void apply(ParticleSystem particles, GestureRecognizer gestures, CameraManager camera) {
    glowCount = 0;
    if (particles == null || gestures == null || camera == null) return;
    HandGesture[] states = gestures.gestures();
    particles.setMotionScale(states.length > 0 ? MOTION_SCALE_WITH_HANDS : 1);
    float unit = screenScale(camera);
    if (unit <= 0) return;
    int now = app.millis();
    continueBursts(particles, now);

    for (HandGesture state : states) {
      float palm = state.palmSize * unit;
      float swirlSign = state.handId % 2 == 1 ? 1 : -1;
      float palmX = camera.frameToScreenX(state.palmX);
      float palmY = camera.frameToScreenY(state.palmY);
      float pinchX = camera.frameToScreenX(state.pinchX);
      float pinchY = camera.frameToScreenY(state.pinchY);

      // 놓는 순간: 바로 전 손동작이 모으기였으면 그 자리에서 터뜨린다
      if (state.justChanged && (state.previous == GestureRecognizer.PINCH || state.previous == GestureRecognizer.FIST)) {
        float held = Math.min(1f, state.previousHeldMs / (float) BURST_FULL_HOLD_MS);
        float scale = BURST_MIN + (1f - BURST_MIN) * held;
        boolean wasPinch = state.previous == GestureRecognizer.PINCH;
        float bx = wasPinch ? pinchX : palmX;
        float by = wasPinch ? pinchY : palmY;
        particles.addHandField(ParticleSystem.FIELD_BURST, bx, by, palm * BURST_RADIUS, BURST_IMPULSE * scale, 0, 0);
        startBurst(bx, by, palm * BURST_RADIUS * BURST_PUSH_REACH, scale, now);
      }

      int gesture = state.gesture;
      if (gesture == GestureRecognizer.OPEN) {
        particles.addHandField(ParticleSystem.FIELD_PUSH, palmX, palmY, palm * OPEN_RADIUS, OPEN_FORCE, 0, 0);
      } else if (gesture == GestureRecognizer.POINT) {
        float tipX = camera.frameToScreenX(state.pointX);
        float tipY = camera.frameToScreenY(state.pointY);
        particles.addHandField(ParticleSystem.FIELD_PUSH, tipX, tipY, palm * POINT_RADIUS, POINT_FORCE, 0, 0);
        trailFor(state.handId).add(tipX, tipY, now);
      } else if (gesture == GestureRecognizer.PINCH) {
        particles.addHandField(ParticleSystem.FIELD_GATHER, pinchX, pinchY, palm * PINCH_RADIUS, PINCH_FORCE,
          palm * PINCH_CORE, PINCH_SWIRL * swirlSign);
      } else if (gesture == GestureRecognizer.FIST) {
        particles.addHandField(ParticleSystem.FIELD_GATHER, palmX, palmY, palm * FIST_RADIUS, FIST_FORCE,
          palm * FIST_CORE, 0);
      }

      boolean holding = gesture == GestureRecognizer.PINCH || gesture == GestureRecognizer.FIST;
      if (state.swiping && !holding) {
        // 프레임 방향을 화면 방향으로 바꾼다 (거울 반전이면 x가 뒤집힌다)
        float aheadX = camera.frameToScreenX(state.palmX + state.velX * 0.05f) - palmX;
        float aheadY = camera.frameToScreenY(state.palmY + state.velY * 0.05f) - palmY;
        float amount = Math.min(1f, (state.speed - GestureRecognizer.SWIPE_END)
          / (SWIPE_FULL_SPEED - GestureRecognizer.SWIPE_END));
        particles.addSweepField(palmX, palmY, palm * SWIPE_RADIUS, SWIPE_FORCE * amount, aheadX, aheadY);
      }

      // 집기 직전부터 집는 동안 엄지와 검지 사이에 빛을 모은다
      if (glowCount < glowX.length && (state.pinchStrength > 0.05f || gesture == GestureRecognizer.PINCH)) {
        glowX[glowCount] = pinchX;
        glowY[glowCount] = pinchY;
        glowAmount[glowCount] = gesture == GestureRecognizer.PINCH ? 1 : state.pinchStrength;
        glowSize[glowCount] = palm;
        glowHeld[glowCount] = gesture == GestureRecognizer.PINCH;
        glowCount++;
      }
    }
    applyPair(particles, gestures, camera, unit);
  }

  // 양손 사이 거리가 빠르게 변할 때만 반응한다. 한 손이라도 쥐고 있으면 걸지 않는다.
  void applyPair(ParticleSystem particles, GestureRecognizer gestures, CameraManager camera, float unit) {
    if (!gestures.pairActive) return;
    for (HandGesture state : gestures.states) {
      if (state.gesture == GestureRecognizer.PINCH || state.gesture == GestureRecognizer.FIST) return;
    }
    float rate = gestures.pairRate;
    float speed = Math.abs(rate);
    if (speed < PAIR_RATE_MIN) return;
    float amount = Math.min(1f, (speed - PAIR_RATE_MIN) / (PAIR_RATE_FULL - PAIR_RATE_MIN));
    float midX = camera.frameToScreenX(gestures.pairMidX);
    float midY = camera.frameToScreenY(gestures.pairMidY);
    float palm = gestures.pairPalm * unit;
    float radius = gestures.pairPixels * unit / 2f + palm;
    if (rate > 0) {
      particles.addHandField(ParticleSystem.FIELD_PUSH, midX, midY, radius, PAIR_FORCE * amount, 0, 0);
    } else {
      particles.addHandField(ParticleSystem.FIELD_GATHER, midX, midY, radius, PAIR_FORCE * amount, palm * PAIR_CORE, 0);
    }
  }

  void startBurst(float x, float y, float radius, float scale, int now) {
    if (burstCount >= MAX_BURSTS) {
      // 가장 오래된 것을 버린다
      for (int i = 1; i < burstCount; i++) {
        burstX[i - 1] = burstX[i];
        burstY[i - 1] = burstY[i];
        burstR[i - 1] = burstR[i];
        burstScale[i - 1] = burstScale[i];
        burstStart[i - 1] = burstStart[i];
      }
      burstCount--;
    }
    burstX[burstCount] = x;
    burstY[burstCount] = y;
    burstR[burstCount] = radius;
    burstScale[burstCount] = scale;
    burstStart[burstCount] = now;
    burstCount++;
  }

  void continueBursts(ParticleSystem particles, int now) {
    int kept = 0;
    for (int i = 0; i < burstCount; i++) {
      float t = (now - burstStart[i]) / (float) BURST_PUSH_MS;
      if (t >= 1) continue;
      particles.addHandField(ParticleSystem.FIELD_PUSH, burstX[i], burstY[i], burstR[i], BURST_PUSH * burstScale[i] * (1f - t), 0, 0);
      burstX[kept] = burstX[i];
      burstY[kept] = burstY[i];
      burstR[kept] = burstR[i];
      burstScale[kept] = burstScale[i];
      burstStart[kept] = burstStart[i];
      kept++;
    }
    burstCount = kept;
  }

  // 프레임 1 px이 화면에서 몇 px인지
  float screenScale(CameraManager camera) {
    float a = camera.frameToScreenX(0);
    float b = camera.frameToScreenX(100);
    return Math.abs(b - a) / 100f;
  }

  HandTrail trailFor(int handId) {
    for (HandTrail trail : trails) {
      if (trail.handId == handId) return trail;
    }
    HandTrail trail = new HandTrail(handId);
    trails.add(trail);
    return trail;
  }

  void reset() {
    trails.clear();
    glowCount = 0;
    burstCount = 0;
  }

  // particles.draw() 다음에 호출한다.
  void draw() {
    int now = app.millis();
    app.pushStyle();
    app.noFill();
    app.strokeCap(PApplet.ROUND);
    for (int t = trails.size() - 1; t >= 0; t--) {
      HandTrail trail = trails.get(t);
      trail.expire(now);
      if (trail.count < 2) {
        if (trail.count == 0) trails.remove(t);
        continue;
      }
      drawTrail(trail, now);
    }

    float pulse = 0.5f + 0.5f * (float) Math.sin(now * 0.012f);
    app.noStroke();
    for (int g = 0; g < glowCount; g++) {
      float amount = glowAmount[g];
      float size = glowSize[g];
      if (glowHeld[g]) {
        app.fill(COLOR_A, 40 + 30 * pulse);
        app.circle(glowX[g], glowY[g], size * (0.9f + 0.15f * pulse));
        app.fill(COLOR_CORE, 170);
        app.circle(glowX[g], glowY[g], size * 0.18f);
      } else {
        // 손가락이 가까워질수록 고리가 좁아지고 밝아진다
        app.noFill();
        app.stroke(COLOR_A, 150 * amount);
        app.strokeWeight(1.5f);
        app.circle(glowX[g], glowY[g], size * (1.6f - 0.9f * amount));
        app.noStroke();
      }
    }
    app.popStyle();
  }

  // 넓고 흐린 선, 중간 선, 가는 밝은 선을 겹쳐 네온처럼 보이게 한다.
  // 오래된 점일수록 흐려지고 청록에서 보라로 바뀐다.
  void drawTrail(HandTrail trail, int now) {
    float[] widths = {16f, 7f, 2.2f};
    float[] alphas = {28f, 70f, 235f};
    for (int pass = 0; pass < 3; pass++) {
      app.strokeWeight(widths[pass]);
      for (int i = 1; i < trail.count; i++) {
        int a = trail.index(i - 1);
        int b = trail.index(i);
        float age = (now - trail.time[b]) / (float) TRAIL_MS;
        if (age >= 1) continue;
        float life = 1f - age;
        life *= life;
        int ink = pass == 2 ? app.lerpColor(COLOR_CORE, COLOR_B, age) : app.lerpColor(COLOR_A, COLOR_B, age);
        app.stroke(ink, alphas[pass] * life);
        app.line(trail.x[a], trail.y[a], trail.x[b], trail.y[b]);
      }
    }
  }
}

// 손 하나의 검지 궤적. 오래된 점부터 링 버퍼에 쌓는다. 화면 좌표다.
class HandTrail {
  int handId;
  float[] x = new float[HandEffects.TRAIL_MAX];
  float[] y = new float[HandEffects.TRAIL_MAX];
  int[] time = new int[HandEffects.TRAIL_MAX];
  int start = 0;
  int count = 0;

  HandTrail(int handId) {
    this.handId = handId;
  }

  int index(int i) {
    return (start + i) % x.length;
  }

  void add(float px, float py, int now) {
    if (count > 0) {
      int last = index(count - 1);
      float dx = px - x[last];
      float dy = py - y[last];
      if (dx * dx + dy * dy < HandEffects.TRAIL_MIN_STEP * HandEffects.TRAIL_MIN_STEP) {
        time[last] = now;
        return;
      }
    }
    if (count == x.length) {
      start = (start + 1) % x.length;
      count--;
    }
    int at = index(count);
    x[at] = px;
    y[at] = py;
    time[at] = now;
    count++;
  }

  void expire(int now) {
    while (count > 0 && now - time[start] >= HandEffects.TRAIL_MS) {
      start = (start + 1) % x.length;
      count--;
    }
  }
}
