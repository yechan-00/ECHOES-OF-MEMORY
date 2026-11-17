// GestureRecognizer
//
// 담당:
// HandTracker가 낸 관절 21개로 손마다 지금 어떤 손동작인지 판별한다.
// 효과는 만들지 않는다. 파티클이나 잔상은 이 결과를 읽어 반응한다.
//
// 판별하는 손동작:
//   OPEN     손바닥 펴기. 네 손가락이 모두 펴짐 (엄지는 보지 않는다)
//   FIST     주먹. 네 손가락이 모두 굽고 엄지도 접힘
//   POINT    검지로 가리키기. 검지만 펴짐
//   VICTORY  V 사인. 검지와 중지만 펴짐
//   PINCH    집기. 엄지 끝과 검지 끝이 붙음. 다른 동작보다 먼저 본다
//   NONE     위 어느 것도 아님 (엄지 척, 손가락 셋 등)
//
// 판별 기준 (회전과 손 크기에 영향받지 않게 모두 비율로 본다):
//   손가락이 펴졌는지: 손목→손가락 끝 거리 / 손목→둘째 마디(PIP) 거리 > EXTEND_RATIO
//   엄지가 펴졌는지:   엄지 끝→검지 뿌리 거리 / palmSize > THUMB_OUT_RATIO
//   집기:              엄지 끝→검지 끝 거리 / palmSize < PINCH_ON 이면 시작, > PINCH_OFF 이면 끝
//                      주먹에서 엄지가 검지 위에 얹힌 경우를 빼려고, 검지 끝이 손바닥 중심에서
//                      PINCH_INDEX_REACH 이상 떨어져 있어야 시작으로 본다
//
// 흔들림 방지:
//   같은 판별이 HOLD_MS 동안 이어져야 gesture가 바뀐다. 바뀐 그 draw 프레임에만 justChanged가 true다.
//   손을 놓치면 그 손의 상태는 사라진다.
//
// 좌표는 모두 카메라 원본 프레임 기준이다. 화면에는 CameraManager.frameToScreenX/Y()로 바꾼다.

class GestureRecognizer {
  static final int NONE = 0;
  static final int OPEN = 1;
  static final int FIST = 2;
  static final int POINT = 3;
  static final int VICTORY = 4;
  static final int PINCH = 5;

  // 테스트 사진 측정값(2026-11-16): 굽힌 손가락 0.54~0.75, 편 손가락 1.30~1.39
  static final float EXTEND_RATIO = 1.05f;       // 손목→끝 / 손목→PIP. 이보다 크면 펴진 손가락
  // 접은 엄지 0.05~0.41, 편 손의 엄지 0.65, 엄지 척 0.83
  static final float THUMB_OUT_RATIO = 0.55f;    // 엄지 끝→검지 뿌리 / palmSize. 이보다 크면 엄지가 펴짐
  static final float PINCH_ON = 0.30f;           // 엄지 끝→검지 끝 / palmSize. 이보다 작으면 집기 시작
  static final float PINCH_OFF = 0.45f;          // 이보다 커지면 집기 끝 (시작보다 넉넉하게 두어 깜빡임을 막는다)
  // 주먹 0.41~0.45, 엄지 척 0.38. 주먹은 엄지 끝→검지 끝이 0.18이라 이 조건이 없으면 집기로 잡힌다
  static final float PINCH_INDEX_REACH = 0.7f;   // 검지 끝→손바닥 중심 / palmSize. 집기 시작에 필요한 최소값
  static final int HOLD_MS = 120;                // 판별이 이 시간 동안 같아야 gesture를 바꾼다

  // 휘두르기: 손바닥 중심 속도를 "초당 손바닥 크기 몇 개"로 잰다. 1 m 안쪽에서 손바닥은 약 9 cm라
  // 천천히 흔들기(0.5 m/s)가 약 5.5, 빠르게 휘두르기(1.5 m/s)가 약 16이다. 실측 전 추정값이다.
  static final float SWIPE_START = 7f;           // 이보다 빠르면 휘두르기 시작
  static final float SWIPE_END = 4f;             // 이보다 느려지면 끝
  static final float VELOCITY_SMOOTH = 0.5f;     // 새 속도를 섞는 비율
  static final int VELOCITY_HOLD_MS = 150;       // 손 위치가 이 시간 동안 안 바뀌면 속도를 줄인다
  // 양손 거리: 두 손바닥 중심 사이 거리를 평균 손바닥 크기로 나눈 값의 변화 속도 (초당)
  static final float PAIR_SMOOTH = 0.5f;

  final String[] NAMES = {"NONE", "OPEN", "FIST", "POINT", "VICTORY", "PINCH"};
  // 손가락별 관절 번호: 엄지, 검지, 중지, 약지, 새끼
  final int[] FINGER_PIP = {2, 6, 10, 14, 18};
  final int[] FINGER_TIP = {4, 8, 12, 16, 20};

  static final int COLOR_A = 0xFF38E8D5;
  static final int COLOR_B = 0xFFA78BFA;
  static final int COLOR_TEXT = 0xFFF4FBFF;

  PApplet app;
  ArrayList<HandGesture> states = new ArrayList<HandGesture>();
  PFont debugFont;

  // 양손이 모두 잡혀 있을 때만 pairActive가 true다. 좌표는 원본 프레임 기준.
  boolean pairActive = false;
  float pairDistance = 0;        // 두 손바닥 중심 거리 / 평균 손바닥 크기
  float pairRate = 0;            // pairDistance의 초당 변화. 벌리면 +, 모으면 -
  float pairMidX = 0, pairMidY = 0;
  float pairPixels = 0;          // 두 손바닥 중심 거리 (프레임 px)
  float pairPalm = 0;            // 두 손의 평균 손바닥 크기 (프레임 px)
  int pairChangedAt = 0;
  int pairFirstId = -1, pairSecondId = -1;

  GestureRecognizer(PApplet app) {
    this.app = app;
  }

  // draw()에서 매 프레임 한 번 호출한다.
  void update(Hand[] hands) {
    update(hands, app.millis());
  }

  void update(Hand[] hands, int now) {
    ArrayList<HandGesture> next = new ArrayList<HandGesture>();
    for (Hand hand : hands) {
      HandGesture state = find(hand.id);
      if (state == null) state = new HandGesture(hand.id, now);
      measure(hand, state);
      measureVelocity(state, now);
      int raw = classify(state);
      state.raw = raw;
      state.justChanged = false;
      if (raw != state.candidate) {
        state.candidate = raw;
        state.candidateSince = now;
      }
      if (state.candidate != state.gesture && now - state.candidateSince >= HOLD_MS) {
        state.previousHeldMs = now - state.changedAt;
        state.previous = state.gesture;
        state.gesture = state.candidate;
        state.changedAt = now;
        state.justChanged = true;
      }
      next.add(state);
    }
    states = next;
    measurePair(now);
  }

  // 손 위치는 카메라 프레임마다(약 30 fps) 바뀌고 update()는 draw마다(60 fps) 불린다.
  // 그래서 위치가 실제로 바뀐 때만 속도를 새로 구한다.
  void measureVelocity(HandGesture state, int now) {
    if (!state.hasLast) {
      state.hasLast = true;
      state.lastPalmX = state.palmX;
      state.lastPalmY = state.palmY;
      state.lastMoveAt = now;
      return;
    }
    float dx = state.palmX - state.lastPalmX;
    float dy = state.palmY - state.lastPalmY;
    int dt = now - state.lastMoveAt;
    if (dx != 0 || dy != 0) {
      if (dt > 0) {
        float vx = dx * 1000f / dt;
        float vy = dy * 1000f / dt;
        state.velX += (vx - state.velX) * VELOCITY_SMOOTH;
        state.velY += (vy - state.velY) * VELOCITY_SMOOTH;
      }
      state.lastPalmX = state.palmX;
      state.lastPalmY = state.palmY;
      state.lastMoveAt = now;
    } else if (dt > VELOCITY_HOLD_MS) {
      state.velX *= 0.5f;
      state.velY *= 0.5f;
    }
    state.speed = (float) Math.sqrt(state.velX * state.velX + state.velY * state.velY) / state.palmSize;
    if (state.swiping) state.swiping = state.speed > SWIPE_END;
    else state.swiping = state.speed > SWIPE_START;
  }

  void measurePair(int now) {
    if (states.size() != 2) {
      pairActive = false;
      pairRate = 0;
      pairFirstId = -1;
      return;
    }
    HandGesture a = states.get(0);
    HandGesture b = states.get(1);
    float dx = a.palmX - b.palmX;
    float dy = a.palmY - b.palmY;
    float pixels = (float) Math.sqrt(dx * dx + dy * dy);
    float palm = Math.max(1f, (a.palmSize + b.palmSize) / 2f);
    float distance = pixels / palm;
    boolean samePair = pairActive && pairFirstId == a.handId && pairSecondId == b.handId;
    if (samePair && distance != pairDistance) {
      int dt = now - pairChangedAt;
      if (dt > 0) {
        float rate = (distance - pairDistance) * 1000f / dt;
        pairRate += (rate - pairRate) * PAIR_SMOOTH;
      }
      pairChangedAt = now;
    } else if (!samePair) {
      pairRate = 0;
      pairChangedAt = now;
    } else if (now - pairChangedAt > VELOCITY_HOLD_MS) {
      pairRate *= 0.5f;
    }
    pairActive = true;
    pairFirstId = a.handId;
    pairSecondId = b.handId;
    pairDistance = distance;
    pairPixels = pixels;
    pairPalm = palm;
    pairMidX = (a.palmX + b.palmX) / 2f;
    pairMidY = (a.palmY + b.palmY) / 2f;
  }

  HandGesture[] gestures() {
    return states.toArray(new HandGesture[states.size()]);
  }

  HandGesture find(int handId) {
    for (HandGesture state : states) {
      if (state.handId == handId) return state;
    }
    return null;
  }

  String name(int gesture) {
    if (gesture < 0 || gesture >= NAMES.length) return "?";
    return NAMES[gesture];
  }

  void reset() {
    states.clear();
    pairActive = false;
    pairRate = 0;
    pairFirstId = -1;
  }

  // ── 측정 ──

  void measure(Hand hand, HandGesture state) {
    float palm = Math.max(hand.palmSize, 1f);
    state.palmSize = palm;
    state.rightHand = hand.rightHand;
    state.palmX = (hand.x[0] + hand.x[5] + hand.x[9] + hand.x[13] + hand.x[17]) / 5f;
    state.palmY = (hand.y[0] + hand.y[5] + hand.y[9] + hand.y[13] + hand.y[17]) / 5f;

    for (int f = 1; f < 5; f++) {
      float toTip = dist(hand, 0, FINGER_TIP[f]);
      float toPip = Math.max(dist(hand, 0, FINGER_PIP[f]), 1f);
      state.fingerRatio[f] = toTip / toPip;
      state.extended[f] = state.fingerRatio[f] > EXTEND_RATIO;
    }
    state.fingerRatio[0] = dist(hand, 4, 5) / palm;
    state.extended[0] = state.fingerRatio[0] > THUMB_OUT_RATIO;

    state.pinchDistance = dist(hand, 4, 8) / palm;
    float ix = hand.x[8] - state.palmX;
    float iy = hand.y[8] - state.palmY;
    state.indexReach = (float) Math.sqrt(ix * ix + iy * iy) / palm;
    state.pinchX = (hand.x[4] + hand.x[8]) / 2f;
    state.pinchY = (hand.y[4] + hand.y[8]) / 2f;
    state.pointX = hand.x[8];
    state.pointY = hand.y[8];
    float strength = (PINCH_OFF - state.pinchDistance) / (PINCH_OFF - PINCH_ON);
    state.pinchStrength = Math.max(0f, Math.min(1f, strength));
  }

  float dist(Hand hand, int a, int b) {
    float dx = hand.x[a] - hand.x[b];
    float dy = hand.y[a] - hand.y[b];
    return (float) Math.sqrt(dx * dx + dy * dy);
  }

  // 이번 측정값만으로 판별한다. 집기는 이전 상태를 보고 시작과 끝 기준을 다르게 쓴다.
  int classify(HandGesture state) {
    if (state.pinched) {
      state.pinched = state.pinchDistance < PINCH_OFF;
    } else {
      state.pinched = state.pinchDistance < PINCH_ON && state.indexReach > PINCH_INDEX_REACH;
    }
    if (state.pinched) return PINCH;

    boolean index = state.extended[1];
    boolean middle = state.extended[2];
    boolean ring = state.extended[3];
    boolean pinky = state.extended[4];
    boolean thumb = state.extended[0];

    if (index && middle && ring && pinky) return OPEN;
    if (!index && !middle && !ring && !pinky) return thumb ? NONE : FIST;
    if (index && !middle && !ring && !pinky) return POINT;
    if (index && middle && !ring && !pinky) return VICTORY;
    return NONE;
  }

  // ── 디버그 표시 ──
  // HandTracker.drawDebug() 다음에 그린다. 손목 이름표 아래에 손동작을 쓴다.

  void drawDebug(CameraManager camera, Hand[] hands) {
    if (debugFont == null) debugFont = app.createFont("Monospaced", 13);
    app.pushStyle();
    app.textFont(debugFont);
    for (Hand hand : hands) {
      HandGesture state = find(hand.id);
      if (state == null) continue;
      int ink = hand.id % 2 == 1 ? COLOR_A : COLOR_B;

      // 집기 정도: 엄지 끝과 검지 끝을 잇는 선이 진해진다
      float tx = camera.frameToScreenX(hand.x[4]);
      float ty = camera.frameToScreenY(hand.y[4]);
      float ix = camera.frameToScreenX(hand.x[8]);
      float iy = camera.frameToScreenY(hand.y[8]);
      app.stroke(COLOR_TEXT, 60 + 195 * state.pinchStrength);
      app.strokeWeight(1 + 3 * state.pinchStrength);
      app.line(tx, ty, ix, iy);
      if (state.gesture == PINCH) {
        app.noFill();
        app.stroke(ink);
        app.strokeWeight(2);
        float px = camera.frameToScreenX(state.pinchX);
        float py = camera.frameToScreenY(state.pinchY);
        app.ellipse(px, py, 26, 26);
      }

      String fingers = "";
      for (int f = 0; f < 5; f++) fingers += state.extended[f] ? "|" : ".";
      String label = name(state.gesture) + (state.raw != state.gesture ? " (" + name(state.raw) + ")" : "") + "  " + fingers
        + "  " + PApplet.nf(state.speed, 1, 1) + (state.swiping ? " SWIPE" : "");
      app.noStroke();
      app.fill(state.justChanged ? ink : COLOR_TEXT);
      app.textAlign(PApplet.LEFT, PApplet.TOP);
      app.text(label, camera.frameToScreenX(hand.x[0]) + 8, camera.frameToScreenY(hand.y[0]) + 4);
    }
    if (pairActive) {
      float mx = camera.frameToScreenX(pairMidX);
      float my = camera.frameToScreenY(pairMidY);
      app.fill(COLOR_TEXT);
      app.textAlign(PApplet.CENTER, PApplet.BOTTOM);
      app.text("PAIR " + PApplet.nf(pairDistance, 1, 1) + "  " + (pairRate >= 0 ? "+" : "") + PApplet.nf(pairRate, 1, 1) + "/s", mx, my - 6);
    }
    app.popStyle();
  }
}

// 손 하나의 손동작 상태. HandTracker의 Hand.id로 구분한다.
class HandGesture {
  int handId;
  int gesture = GestureRecognizer.NONE;    // 흔들림을 걸러낸 현재 손동작
  int previous = GestureRecognizer.NONE;   // 바로 전 손동작 (justChanged일 때 무엇에서 바뀌었는지)
  int previousHeldMs;                      // 바로 전 손동작이 이어졌던 시간 (예: 집기를 놓을 때 얼마나 오래 쥐었는지)
  int raw = GestureRecognizer.NONE;        // 이번 프레임 판별값 (걸러내기 전)
  int candidate = GestureRecognizer.NONE;
  int candidateSince;
  int changedAt;                           // gesture가 바뀐 시각 (millis)
  boolean justChanged;                     // 이번 update()에서 gesture가 바뀌었는지

  boolean rightHand;
  float palmX, palmY;                      // 손바닥 중심 (손목과 네 손가락 뿌리 평균)
  float palmSize;                          // 손목→중지 뿌리 거리 (px)
  float pinchX, pinchY;                    // 엄지 끝과 검지 끝의 중간
  float pointX, pointY;                    // 검지 끝
  float pinchStrength;                     // 0~1. 엄지와 검지가 가까울수록 1

  // 손바닥 중심 속도 (프레임 px/초)와 빠르기 (초당 손바닥 크기 몇 개)
  float velX, velY;
  float speed;
  boolean swiping;                         // SWIPE_START를 넘으면 true, SWIPE_END 밑으로 내려가면 false
  boolean hasLast;
  float lastPalmX, lastPalmY;
  int lastMoveAt;

  // 판별에 쓴 측정값 (조정과 디버그용)
  boolean pinched;
  float pinchDistance;                     // 엄지 끝→검지 끝 / palmSize
  float indexReach;                        // 검지 끝→손바닥 중심 / palmSize
  float[] fingerRatio = new float[5];      // 엄지는 엄지 끝→검지 뿌리 / palmSize, 나머지는 손목→끝 / 손목→PIP
  boolean[] extended = new boolean[5];

  HandGesture(int handId, int now) {
    this.handId = handId;
    this.candidateSince = now;
    this.changedAt = now;
  }

  int heldMs(int now) {
    return now - changedAt;
  }
}
