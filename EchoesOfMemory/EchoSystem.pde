// EchoSystem
//
// 담당:
// 초상화의 과거 모습을 잠깐씩 저장해 두었다가, 잔상(echo)으로 떠올렸다 사라지게 한다.
// 입자의 물리에는 손대지 않는다. 저장한 모습을 따로 그린다.
//
// 저장:
//   SNAPSHOT_MS마다 초상화를 이루는 입자(밝게 켜진 것)의 화면 위치, 색, 크기, 밝기를 저장한다.
//   SLOTS개를 돌려 쓰므로 최근 SLOTS × SNAPSHOT_MS 동안의 모습이 남는다.
//   인물이 없거나 흩어지는 중이면(움직이는 입자가 많으면) 저장하지 않는다. 흐트러진 모습은 기억으로 남기지 않는다.
//
// 떠올리기:
//   큰 움직임  motion.total이 MOTION_TRIGGER를 넘으면 MOTION_DELAY_MS 전 모습을 하나 띄운다. 쿨다운이 있다.
//   V 사인     V 사인이 확정되는 순간 저장된 모습을 최근 것부터 SUMMON_COUNT개 차례로 띄운다 (기억 소환).
//
// 잔상 하나는 ECHO_LIFE_MS 동안 보라색 쪽으로 물들며 천천히 떠오르고, 중심에서 조금씩 퍼지며 사라진다.

class EchoSystem {
  static final int SNAPSHOT_MS = 400;
  static final int SLOTS = 10;                   // 최근 4초
  static final int STRIDE = 3;                   // 입자 몇 개 중 하나만 저장할지. 클수록 잔상이 성기고 가볍다
  static final float MIN_ACTIVATION = 0.5f;      // 이보다 밝게 켜진 입자만 저장한다
  static final int MIN_POINTS = 150;             // 저장한 점이 이보다 적으면 인물이 없는 것으로 보고 버린다
  static final float CALM_SPEED = 1.5f;          // 이보다 빠른 입자는 흩어지는 중으로 본다 (px/프레임)
  static final float CALM_RATIO = 0.05f;         // 흩어지는 입자가 이 비율을 넘으면 저장하지 않는다

  static final int ECHO_LIFE_MS = 2600;
  static final float ECHO_FADE_IN = 0.12f;       // 수명 중 나타나는 데 쓰는 비율
  static final float ECHO_RISE = 46f;            // 수명 동안 떠오르는 거리 (화면 px)
  static final float ECHO_SPREAD = 0.14f;        // 수명 동안 중심에서 퍼지는 비율
  static final float ECHO_ALPHA = 0.5f;          // 원래 밝기 대비
  static final float ECHO_SIZE = 1.15f;
  static final int MAX_ECHOES = 6;               // V 사인 소환(5개)이 한꺼번에 보일 수 있어야 한다

  // 큰 움직임으로 띄우기. motion.total 실측 전 추정값이다. G 디버그 화면의 total을 보고 조정한다
  static final float MOTION_TRIGGER = 0.05f;
  static final int MOTION_DELAY_MS = 800;        // 움직이기 직전 모습을 띄운다
  static final int MOTION_COOLDOWN_MS = 1500;
  // V 사인으로 소환하기
  static final int SUMMON_COUNT = 5;
  static final int SUMMON_STAGGER_MS = 160;
  static final int SUMMON_COOLDOWN_MS = 1200;

  static final int ECHO_INK = 0xFFA78BFA;
  static final int ECHO_INK_LATE = 0xFF6D4AA8;

  PApplet app;
  EchoShape[] slots = new EchoShape[SLOTS];
  EchoShape scratch = new EchoShape();
  int slotNext = 0;
  int lastSnapshotAt = -SNAPSHOT_MS;
  int lastMotionEchoAt = -MOTION_COOLDOWN_MS;
  int lastSummonAt = -SUMMON_COOLDOWN_MS;
  ArrayList<Echo> echoes = new ArrayList<Echo>();
  boolean motionEnabled = true;

  EchoSystem(PApplet app) {
    this.app = app;
  }

  // particles.update() 다음에 매 프레임 호출한다. motion과 gestures는 없어도 된다(null).
  void update(ParticleSystem particles, MotionDetector motion, GestureRecognizer gestures) {
    int now = app.millis();
    if (particles != null && now - lastSnapshotAt >= SNAPSHOT_MS) {
      lastSnapshotAt = now;
      capture(particles, now);
    }

    if (motionEnabled && motion != null && motion.total > MOTION_TRIGGER && now - lastMotionEchoAt >= MOTION_COOLDOWN_MS) {
      EchoShape shape = shapeAt(now - MOTION_DELAY_MS);
      if (shape != null) {
        lastMotionEchoAt = now;
        spawn(shape, now, 1f);
      }
    }

    if (gestures != null && now - lastSummonAt >= SUMMON_COOLDOWN_MS) {
      for (HandGesture state : gestures.states) {
        if (state.justChanged && state.gesture == GestureRecognizer.VICTORY) {
          summon(now);
          break;
        }
      }
    }

    for (int i = echoes.size() - 1; i >= 0; i--) {
      if (now - echoes.get(i).start >= ECHO_LIFE_MS) echoes.remove(i);
    }
  }

  // 저장된 모습을 최근 것부터 차례로 띄운다. 오래된 기억일수록 흐리다.
  void summon(int now) {
    lastSummonAt = now;
    int spawned = 0;
    for (int k = 0; k < SLOTS && spawned < SUMMON_COUNT; k++) {
      int index = (slotNext - 1 - k + SLOTS * 2) % SLOTS;
      EchoShape shape = slots[index];
      if (shape == null || shape.count == 0) continue;
      float strength = 1f - 0.12f * spawned;
      spawn(shape, now + spawned * SUMMON_STAGGER_MS, strength);
      spawned++;
    }
  }

  // 임시 버퍼에 먼저 담고, 기준을 통과할 때만 슬롯과 바꾼다. 실패해도 이전 모습이 망가지지 않는다.
  void capture(ParticleSystem particles, int now) {
    EchoShape shape = scratch;
    shape.ensure(particles.count / STRIDE + 1);
    int n = 0;
    int lit = 0;
    int moving = 0;
    float sumX = 0, sumY = 0;
    float span = particles.jitterSpan;
    float calm2 = CALM_SPEED * CALM_SPEED;
    for (int i = 0; i < particles.count; i++) {
      Particle p = particles.particles[i];
      if (!p.visible || p.activation < MIN_ACTIVATION) continue;
      lit++;
      if (p.speedSq > calm2) moving++;
      if (i % STRIDE != 0) continue;
      float x = p.position.x + p.jitterX * span * p.activation;
      float y = p.position.y + p.jitterY * span * p.activation;
      shape.x[n] = x;
      shape.y[n] = y;
      shape.ink[n] = p.fillColor;
      shape.size[n] = p.size;
      shape.alpha[n] = p.alpha * p.activation;
      sumX += x;
      sumY += y;
      n++;
    }
    if (n < MIN_POINTS || (lit > 0 && moving > lit * CALM_RATIO)) return;
    shape.count = n;
    shape.centerX = sumX / n;
    shape.centerY = sumY / n;
    shape.takenAt = now;
    EchoShape old = slots[slotNext];
    slots[slotNext] = shape;
    scratch = old != null ? old : new EchoShape();
    slotNext = (slotNext + 1) % SLOTS;
  }

  // when 시각에 가장 가까운(그보다 앞선) 저장 모습
  EchoShape shapeAt(int when) {
    EchoShape best = null;
    for (EchoShape shape : slots) {
      if (shape == null || shape.count == 0 || shape.takenAt > when) continue;
      if (best == null || shape.takenAt > best.takenAt) best = shape;
    }
    return best;
  }

  void spawn(EchoShape shape, int start, float strength) {
    if (echoes.size() >= MAX_ECHOES) echoes.remove(0);
    echoes.add(new Echo(shape.copy(), start, strength));
  }

  void reset() {
    echoes.clear();
    for (int i = 0; i < SLOTS; i++) slots[i] = null;
    slotNext = 0;
  }

  // particles.draw() 전에 호출해 잔상이 지금 모습 뒤에 보이게 한다.
  void draw() {
    if (echoes.isEmpty()) return;
    int now = app.millis();
    app.pushStyle();
    app.noStroke();
    for (Echo echo : echoes) {
      float t = (now - echo.start) / (float) ECHO_LIFE_MS;
      if (t < 0 || t >= 1) continue;
      float appear = Math.min(1f, t / ECHO_FADE_IN);
      float fade = (1f - t) * (1f - t);
      float envelope = appear * fade * ECHO_ALPHA * echo.strength;
      if (envelope <= 0.004f) continue;
      EchoShape s = echo.shape;
      float grow = 1f + ECHO_SPREAD * t;
      float rise = ECHO_RISE * t;
      int tint = app.lerpColor(ECHO_INK, ECHO_INK_LATE, t);
      float tintAmount = 0.45f + 0.45f * t;
      for (int i = 0; i < s.count; i++) {
        float alpha = s.alpha[i] * envelope;
        if (alpha < 1.5f) continue;
        float x = s.centerX + (s.x[i] - s.centerX) * grow;
        float y = s.centerY + (s.y[i] - s.centerY) * grow - rise;
        app.fill(app.lerpColor(s.ink[i], tint, tintAmount), alpha);
        app.circle(x, y, s.size[i] * ECHO_SIZE);
      }
    }
    app.popStyle();
  }
}

// 저장한 모습 하나. 화면 좌표.
class EchoShape {
  float[] x = new float[0];
  float[] y = new float[0];
  float[] size = new float[0];
  float[] alpha = new float[0];
  int[] ink = new int[0];
  int count = 0;
  float centerX, centerY;
  int takenAt;

  void ensure(int capacity) {
    if (x.length >= capacity) return;
    x = new float[capacity];
    y = new float[capacity];
    size = new float[capacity];
    alpha = new float[capacity];
    ink = new int[capacity];
  }

  EchoShape copy() {
    EchoShape out = new EchoShape();
    out.ensure(count);
    System.arraycopy(x, 0, out.x, 0, count);
    System.arraycopy(y, 0, out.y, 0, count);
    System.arraycopy(size, 0, out.size, 0, count);
    System.arraycopy(alpha, 0, out.alpha, 0, count);
    System.arraycopy(ink, 0, out.ink, 0, count);
    out.count = count;
    out.centerX = centerX;
    out.centerY = centerY;
    out.takenAt = takenAt;
    return out;
  }
}

class Echo {
  EchoShape shape;
  int start;
  float strength;

  Echo(EchoShape shape, int start, float strength) {
    this.shape = shape;
    this.start = start;
    this.strength = strength;
  }
}
