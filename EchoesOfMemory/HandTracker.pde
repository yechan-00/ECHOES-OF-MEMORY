// HandTracker
//
// 담당:
// 카메라 프레임에서 손을 최대 두 개까지 찾아 손마다 관절 21개의 좌표를 낸다.
// 손동작 판별과 효과 연결은 이 결과를 받는 쪽에서 한다.
//
// 모델 (data/ 폴더, opencv_zoo에서 ONNX로 변환된 MediaPipe Hands, Apache 2.0):
//   palm_detection_mediapipe_2023feb.onnx       입력 192x192 RGB. 손바닥 상자와 손바닥 점 7개
//   handpose_estimation_mediapipe_2023feb.onnx  입력 224x224 RGB. 관절 21개, 신뢰도, 왼손/오른손
// 실행은 code/ 폴더의 ONNX Runtime Java jar가 한다. 외부 프로세스는 없다.
//
// 처리 순서 (새 카메라 프레임마다, 별도 스레드):
//   1. 추적 중인 손마다 이전 관절 위치를 최근 속도만큼 옮겨 회전된 정사각형 영역(ROI)을 잡고 관절 모델만 돌린다.
//      예측이 빗나가면 원래 자리로 한 번 더 찾는다.
//      신뢰도가 TRACK_SCORE보다 낮으면 그 손은 놓친 것으로 본다.
//   2. 추적 중인 손이 MAX_HANDS보다 적으면 손바닥 검출 모델로 새 손을 찾는다.
//      이미 추적 중인 손과 겹치는 손바닥은 건너뛴다.
//   3. 두 추적이 같은 손으로 모이면 하나를 버린다.
//   4. 관절 좌표를 One Euro 필터로 부드럽게 한 뒤 결과를 통째로 교체해 내보낸다.
//
// 좌표:
//   결과는 모두 카메라 원본 프레임 좌표다(거울 반전 전). 화면에 그릴 때는
//   CameraManager.frameToScreenX/Y()로 바꾼다.
//
// 스레드:
//   submit()은 draw()에서 호출한다. 새 프레임의 픽셀을 복사해 두기만 하고 바로 돌아온다.
//   추론은 작업 스레드에서 한다. 추론이 느리면 그 사이 프레임은 건너뛴다.
//   hands()는 마지막으로 완성된 결과를 돌려준다. 받는 쪽은 읽기만 한다.

import ai.onnxruntime.*;
import java.nio.FloatBuffer;
import java.util.Collections;

class HandTracker {
  static final String PALM_MODEL = "palm_detection_mediapipe_2023feb.onnx";
  static final String LANDMARK_MODEL = "handpose_estimation_mediapipe_2023feb.onnx";

  static final int MAX_HANDS = 2;
  static final int PALM_SIZE = 192;
  static final int LANDMARK_SIZE = 224;
  static final int ANCHOR_COUNT = 2016;

  static final float PALM_SCORE = 0.5f;          // 손바닥 검출 최소 점수
  static final float PALM_NMS_IOU = 0.3f;        // 이보다 많이 겹치는 손바닥 상자는 하나만 남긴다
  static final float DETECT_SCORE = 0.8f;        // 새로 찾은 손을 받아들이는 관절 신뢰도
  static final float TRACK_SCORE = 0.5f;         // 추적 중인 손을 유지하는 관절 신뢰도
  static final int DETECT_INTERVAL = 3;          // 손이 하나라도 잡혀 있으면 몇 프레임마다 새 손을 찾을지
  static final float ROI_SHIFT_Y = -0.4f;        // 손바닥 상자 높이 대비 손가락 쪽으로 옮기는 양
  static final float ROI_ENLARGE = 3.0f;         // 손바닥 상자를 손 전체 영역으로 키우는 배율
  static final float SAME_HAND_RATIO = 0.5f;     // 두 손의 중심 거리가 손바닥 크기의 이 비율보다 작으면 같은 손
  static final int STALE_MS = 500;               // 결과가 이보다 오래되면 손이 없는 것으로 본다
  // 빠르게 움직이는 손이 영역 밖으로 나가지 않도록, 최근 속도만큼 다음 영역을 미리 옮긴다
  static final float PREDICT_GAIN = 1.0f;        // 예측 이동량에 곱하는 값. 0이면 예측하지 않는다
  static final float PREDICT_MAX = 1.5f;         // 한 번에 옮기는 최대 거리 (× 손바닥 크기)
  static final float PREDICT_SMOOTH = 0.6f;      // 새 속도를 섞는 비율
  static final float PREDICT_RETRY = 0.25f;      // 이보다 많이 옮겼다가 놓치면 원래 자리로 한 번 더 찾는다 (× 손바닥 크기)

  // 반전 전 원본 영상에서 모델 원값이 0.5보다 크면 실제 오른손이었다
  // (MediaPipe 테스트 사진 right_hands.jpg, victory.jpg로 확인). 실제 카메라에서 반대로 나오면 true로 바꾼다.
  static final boolean HANDEDNESS_FLIP = false;

  static final float FILTER_MIN_CUTOFF = 1.5f;   // One Euro: 멈춰 있을 때의 떨림 억제 (Hz)
  static final float FILTER_BETA = 0.01f;        // One Euro: 빠르게 움직일 때 지연을 줄이는 정도
  static final float FILTER_D_CUTOFF = 1.0f;

  // 관절 번호 (MediaPipe Hands)
  static final int WRIST = 0;
  static final int THUMB_TIP = 4;
  static final int INDEX_MCP = 5;
  static final int INDEX_TIP = 8;
  static final int MIDDLE_MCP = 9;
  static final int MIDDLE_TIP = 12;
  static final int RING_MCP = 13;
  static final int RING_TIP = 16;
  static final int PINKY_MCP = 17;
  static final int PINKY_TIP = 20;

  // 관절 21개에서 손바닥 검출 점 7개와 같은 위치: 손목, 검지·중지·약지·새끼 뿌리, 엄지 아래 두 마디
  final int[] PALM_POINT_IDS = {0, 5, 9, 13, 17, 1, 2};
  final int[] BONES = {
    0, 1, 1, 2, 2, 3, 3, 4,
    0, 5, 5, 6, 6, 7, 7, 8,
    5, 9, 9, 10, 10, 11, 11, 12,
    9, 13, 13, 14, 14, 15, 15, 16,
    13, 17, 0, 17, 17, 18, 18, 19, 19, 20
  };

  static final int COLOR_A = 0xFF38E8D5;
  static final int COLOR_B = 0xFFA78BFA;
  static final int COLOR_TEXT = 0xFFF4FBFF;
  static final int COLOR_PANEL = 0xCC080D18;

  PApplet app;
  boolean showDebug = false;
  volatile String status = "not started";
  boolean available = false;

  OrtEnvironment env;
  OrtSession palmSession;
  OrtSession landmarkSession;
  String palmInputName;
  String landmarkInputName;

  final float[] anchorX = new float[ANCHOR_COUNT];
  final float[] anchorY = new float[ANCHOR_COUNT];
  final float[] palmInput = new float[PALM_SIZE * PALM_SIZE * 3];
  final float[] landmarkInput = new float[LANDMARK_SIZE * LANDMARK_SIZE * 3];

  // ── 메인 스레드와 작업 스레드가 주고받는 것 ──
  final Object lock = new Object();
  int[] pendingPixels = new int[0];
  int pendingW = 0, pendingH = 0;
  boolean pendingReady = false;
  volatile boolean running = false;
  volatile boolean resetRequested = false;
  volatile HandFrame latest = new HandFrame(new Hand[0], 0, 0, 0, false, 0);
  Thread worker;

  // ── 작업 스레드만 쓰는 상태 ──
  int[] workPixels = new int[0];
  ArrayList<HandTrack> tracks = new ArrayList<HandTrack>();
  int nextId = 1;
  int framesSinceDetect = 0;

  PFont debugFont;

  HandTracker(PApplet app) {
    this.app = app;
    buildAnchors();
    try {
      env = OrtEnvironment.getEnvironment();
      OrtSession.SessionOptions options = new OrtSession.SessionOptions();
      options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT);
      options.setIntraOpNumThreads(2);
      palmSession = env.createSession(modelPath(PALM_MODEL), options);
      landmarkSession = env.createSession(modelPath(LANDMARK_MODEL), options);
      palmInputName = palmSession.getInputNames().iterator().next();
      landmarkInputName = landmarkSession.getInputNames().iterator().next();
      available = true;
      status = "ready";
    } catch (Throwable problem) {
      available = false;
      status = "model load failed: " + problem.getClass().getSimpleName() + ": " + problem.getMessage();
      PApplet.println("ECHOES hands: " + status);
    }
  }

  String modelPath(String name) {
    return app.dataPath(name);
  }

  // ── 메인 스레드에서 호출 ──

  void start() {
    if (!available || running) return;
    running = true;
    worker = new Thread(new Runnable() {
      public void run() {
        workLoop();
      }
    }, "ECHOES-hands");
    // daemon 스레드라 스케치가 끝나면 함께 끝난다. registerMethod("dispose")는 쓰지 않는다.
    // 이 클래스는 public이 아니어서 Processing이 종료 시 호출하지 못하고 IllegalAccessException을 낸다.
    worker.setDaemon(true);
    worker.start();
  }

  // draw()에서 camera.update() 다음에 매 프레임 한 번 호출한다.
  void submit(CameraManager camera) {
    if (!running || !camera.hasNewFrame() || !camera.pixelsReady()) return;
    PImage frame = camera.frame();
    if (frame == null || frame.pixels == null) return;
    int n = frame.width * frame.height;
    if (n <= 0 || frame.pixels.length < n) return;
    synchronized (lock) {
      if (pendingPixels.length != n) pendingPixels = new int[n];
      System.arraycopy(frame.pixels, 0, pendingPixels, 0, n);
      pendingW = frame.width;
      pendingH = frame.height;
      pendingReady = true;
      lock.notify();
    }
  }

  // 마지막 결과의 손들. 결과가 오래됐으면 빈 배열이다.
  Hand[] hands() {
    HandFrame current = latest;
    if (System.currentTimeMillis() - current.stamp > STALE_MS) return new Hand[0];
    return current.hands;
  }

  HandFrame latestFrame() {
    return latest;
  }

  void reset() {
    resetRequested = true;
    latest = new HandFrame(new Hand[0], 0, 0, 0, false, 0);
  }

  void handleKey(char command) {
    if (command == 't') showDebug = !showDebug;
  }

  public void dispose() {
    running = false;
    synchronized (lock) {
      lock.notifyAll();
    }
    try {
      if (worker != null) worker.join(500);
    } catch (InterruptedException ignored) {
    }
    try {
      if (palmSession != null) palmSession.close();
      if (landmarkSession != null) landmarkSession.close();
    } catch (Throwable ignored) {
    }
    palmSession = null;
    landmarkSession = null;
  }

  // ── 작업 스레드 ──

  void workLoop() {
    while (running) {
      int w, h;
      synchronized (lock) {
        while (running && !pendingReady) {
          try {
            lock.wait();
          } catch (InterruptedException e) {
            return;
          }
        }
        if (!running) return;
        int[] swap = workPixels;
        workPixels = pendingPixels;
        pendingPixels = swap;
        w = pendingW;
        h = pendingH;
        pendingReady = false;
      }
      try {
        latest = processFrame(workPixels, w, h);
        status = "running";
      } catch (Throwable problem) {
        tracks.clear();
        status = "inference failed: " + problem.getClass().getSimpleName();
        PApplet.println("ECHOES hands: " + status + ": " + problem.getMessage());
      }
    }
  }

  // 한 프레임을 처리해 결과를 만든다. 작업 스레드에서만 호출한다.
  HandFrame processFrame(int[] pixels, int w, int h) throws OrtException {
    long started = System.nanoTime();
    long nowMs = System.currentTimeMillis();
    if (resetRequested) {
      resetRequested = false;
      tracks.clear();
      framesSinceDetect = 0;
    }

    // 1. 추적 중인 손은 이전 관절 위치를 최근 속도만큼 옮겨 영역을 잡는다
    ArrayList<HandTrack> kept = new ArrayList<HandTrack>();
    for (HandTrack track : tracks) {
      float palm = track.palmSize();
      float shiftX = track.velX * (nowMs - track.lastMs) * PREDICT_GAIN;
      float shiftY = track.velY * (nowMs - track.lastMs) * PREDICT_GAIN;
      float shift = (float) Math.sqrt(shiftX * shiftX + shiftY * shiftY);
      float maxShift = palm * PREDICT_MAX;
      if (shift > maxShift) {
        shiftX *= maxShift / shift;
        shiftY *= maxShift / shift;
        shift = maxShift;
      }
      float[] px = new float[21];
      float[] py = new float[21];
      for (int k = 0; k < 21; k++) {
        px[k] = track.rawX[k] + shiftX;
        py[k] = track.rawY[k] + shiftY;
      }
      HandRoi roi = roiFromLandmarks(px, py);
      LandmarkResult result = roi == null ? null : runLandmarks(pixels, w, h, roi);
      if ((result == null || result.score < TRACK_SCORE) && shift > palm * PREDICT_RETRY) {
        // 예측이 빗나갔으면 (방향을 갑자기 바꾼 경우) 원래 자리에서 한 번 더 찾는다
        roi = roiFromLandmarks(track.rawX, track.rawY);
        result = roi == null ? null : runLandmarks(pixels, w, h, roi);
      }
      if (result == null || result.score < TRACK_SCORE) continue;
      track.accept(result, roi, nowMs);
      kept.add(track);
    }
    removeDuplicates(kept);

    // 2. 빈자리가 있으면 새 손을 찾는다
    boolean detected = false;
    framesSinceDetect++;
    if (kept.size() < MAX_HANDS && (kept.isEmpty() || framesSinceDetect >= DETECT_INTERVAL)) {
      framesSinceDetect = 0;
      detected = true;
      ArrayList<PalmBox> palms = runPalm(pixels, w, h);
      for (PalmBox palm : palms) {
        if (kept.size() >= MAX_HANDS) break;
        if (overlapsTrack(palm, kept)) continue;
        HandRoi roi = roiFromPoints(palm.px, palm.py);
        if (roi == null) continue;
        LandmarkResult result = runLandmarks(pixels, w, h, roi);
        if (result == null || result.score < DETECT_SCORE) continue;
        HandTrack track = new HandTrack(nextId++);
        track.accept(result, roi, nowMs);
        kept.add(track);
        removeDuplicates(kept);
      }
    }
    tracks = kept;

    Hand[] out = new Hand[tracks.size()];
    for (int i = 0; i < out.length; i++) out[i] = tracks.get(i).snapshot();
    float ms = (System.nanoTime() - started) / 1e6f;
    return new HandFrame(out, w, h, ms, detected, nowMs);
  }

  // ── 손바닥 검출 ──

  ArrayList<PalmBox> runPalm(int[] pixels, int w, int h) throws OrtException {
    // 비율을 유지해 192x192 안에 넣고 남는 곳은 검은색으로 둔다
    float side = Math.max(w, h);
    float padX = (side - w) / 2f;
    float padY = (side - h) / 2f;
    float unit = side / PALM_SIZE;
    int sub = subSamples(unit);
    int at = 0;
    for (int j = 0; j < PALM_SIZE; j++) {
      for (int i = 0; i < PALM_SIZE; i++) {
        float fx = (i + 0.5f) * unit - padX;
        float fy = (j + 0.5f) * unit - padY;
        sampleArea(pixels, w, h, fx, fy, unit, 0, 0, unit, sub, palmInput, at);
        at += 3;
      }
    }

    float[] raw;
    float[] scores;
    OnnxTensor input = OnnxTensor.createTensor(env, FloatBuffer.wrap(palmInput), new long[] {1, PALM_SIZE, PALM_SIZE, 3});
    OrtSession.Result result = null;
    try {
      result = palmSession.run(Collections.singletonMap(palmInputName, input));
      raw = readFloats(result, "Identity");
      scores = readFloats(result, "Identity_1");
    } finally {
      if (result != null) result.close();
      input.close();
    }

    ArrayList<PalmBox> candidates = new ArrayList<PalmBox>();
    for (int a = 0; a < ANCHOR_COUNT; a++) {
      float logit = Math.max(-80f, Math.min(80f, scores[a]));
      float score = 1f / (1f + (float) Math.exp(-logit));
      if (score < PALM_SCORE) continue;
      int base = a * 18;
      float cx = anchorX[a] + raw[base] / PALM_SIZE;
      float cy = anchorY[a] + raw[base + 1] / PALM_SIZE;
      float bw = raw[base + 2] / PALM_SIZE;
      float bh = raw[base + 3] / PALM_SIZE;
      PalmBox palm = new PalmBox();
      palm.score = score;
      palm.x1 = (cx - bw / 2f) * side - padX;
      palm.y1 = (cy - bh / 2f) * side - padY;
      palm.x2 = (cx + bw / 2f) * side - padX;
      palm.y2 = (cy + bh / 2f) * side - padY;
      for (int k = 0; k < 7; k++) {
        palm.px[k] = (anchorX[a] + raw[base + 4 + k * 2] / PALM_SIZE) * side - padX;
        palm.py[k] = (anchorY[a] + raw[base + 5 + k * 2] / PALM_SIZE) * side - padY;
      }
      candidates.add(palm);
    }

    // 점수 순으로 정렬한 뒤 많이 겹치는 상자를 버린다
    Collections.sort(candidates, new java.util.Comparator<PalmBox>() {
      public int compare(PalmBox p, PalmBox q) {
        return Float.compare(q.score, p.score);
      }
    });
    ArrayList<PalmBox> picked = new ArrayList<PalmBox>();
    for (PalmBox palm : candidates) {
      boolean clash = false;
      for (PalmBox other : picked) {
        if (iou(palm, other) > PALM_NMS_IOU) {
          clash = true;
          break;
        }
      }
      if (!clash) picked.add(palm);
      if (picked.size() >= MAX_HANDS * 2) break;
    }
    return picked;
  }

  float iou(PalmBox p, PalmBox q) {
    float ix = Math.max(0, Math.min(p.x2, q.x2) - Math.max(p.x1, q.x1));
    float iy = Math.max(0, Math.min(p.y2, q.y2) - Math.max(p.y1, q.y1));
    float inter = ix * iy;
    float union = (p.x2 - p.x1) * (p.y2 - p.y1) + (q.x2 - q.x1) * (q.y2 - q.y1) - inter;
    return union <= 0 ? 0 : inter / union;
  }

  boolean overlapsTrack(PalmBox palm, ArrayList<HandTrack> list) {
    float cx = (palm.x1 + palm.x2) / 2f;
    float cy = (palm.y1 + palm.y2) / 2f;
    float reach = Math.max(palm.x2 - palm.x1, palm.y2 - palm.y1) * 0.8f;
    for (HandTrack track : list) {
      float dx = track.palmCenterX() - cx;
      float dy = track.palmCenterY() - cy;
      float limit = Math.max(reach, track.palmSize() * 0.8f);
      if (dx * dx + dy * dy < limit * limit) return true;
    }
    return false;
  }

  // 두 추적이 같은 손으로 모이면 나중에 잡힌 쪽을 버린다.
  // 먼저 잡힌 손의 id를 남겨야 받는 쪽 효과가 끊기지 않는다.
  void removeDuplicates(ArrayList<HandTrack> list) {
    boolean changed = true;
    while (changed) {
      changed = false;
      for (int i = 0; i < list.size() && !changed; i++) {
        for (int j = i + 1; j < list.size() && !changed; j++) {
          HandTrack a = list.get(i);
          HandTrack b = list.get(j);
          float dx = a.palmCenterX() - b.palmCenterX();
          float dy = a.palmCenterY() - b.palmCenterY();
          float limit = Math.min(a.palmSize(), b.palmSize()) * SAME_HAND_RATIO;
          if (dx * dx + dy * dy < limit * limit) {
            list.remove(a.id < b.id ? b : a);
            changed = true;
          }
        }
      }
    }
  }

  // ── 관절 ──

  LandmarkResult runLandmarks(int[] pixels, int w, int h, HandRoi roi) throws OrtException {
    float unit = roi.side / LANDMARK_SIZE;
    int sub = subSamples(unit);
    int at = 0;
    for (int j = 0; j < LANDMARK_SIZE; j++) {
      float ly = roi.cy + ((j + 0.5f) / LANDMARK_SIZE - 0.5f) * roi.side;
      for (int i = 0; i < LANDMARK_SIZE; i++) {
        float lx = roi.cx + ((i + 0.5f) / LANDMARK_SIZE - 0.5f) * roi.side;
        float fx = lx * roi.rx + ly * roi.dx;
        float fy = lx * roi.ry + ly * roi.dy;
        sampleArea(pixels, w, h, fx, fy, unit * roi.rx, unit * roi.ry, unit * roi.dx, unit * roi.dy, sub, landmarkInput, at);
        at += 3;
      }
    }

    float[] coords;
    float score;
    float handedness;
    OnnxTensor input = OnnxTensor.createTensor(env, FloatBuffer.wrap(landmarkInput), new long[] {1, LANDMARK_SIZE, LANDMARK_SIZE, 3});
    OrtSession.Result result = null;
    try {
      result = landmarkSession.run(Collections.singletonMap(landmarkInputName, input));
      coords = readFloats(result, "Identity");
      score = readFloats(result, "Identity_1")[0];
      handedness = readFloats(result, "Identity_2")[0];
    } finally {
      if (result != null) result.close();
      input.close();
    }

    LandmarkResult out = new LandmarkResult();
    out.score = score;
    out.handedness = handedness;
    float scale = roi.side / LANDMARK_SIZE;
    for (int k = 0; k < 21; k++) {
      float lx = roi.cx + (coords[k * 3] - LANDMARK_SIZE / 2f) * scale;
      float ly = roi.cy + (coords[k * 3 + 1] - LANDMARK_SIZE / 2f) * scale;
      out.x[k] = lx * roi.rx + ly * roi.dx;
      out.y[k] = lx * roi.ry + ly * roi.dy;
      out.z[k] = coords[k * 3 + 2] * scale;
    }
    return out;
  }

  float[] readFloats(OrtSession.Result result, String name) throws OrtException {
    OnnxValue value = result.get(name).get();
    FloatBuffer buffer = ((OnnxTensor) value).getFloatBuffer();
    float[] out = new float[buffer.remaining()];
    buffer.get(out);
    return out;
  }

  // ── 영역 계산 ──

  HandRoi roiFromLandmarks(float[] x, float[] y) {
    float[] px = new float[7];
    float[] py = new float[7];
    for (int k = 0; k < 7; k++) {
      px[k] = x[PALM_POINT_IDS[k]];
      py[k] = y[PALM_POINT_IDS[k]];
    }
    return roiFromPoints(px, py);
  }

  // 손바닥 점 7개(0: 손목, 2: 중지 뿌리)로 손이 위를 향하도록 회전된 정사각형 영역을 만든다.
  // opencv_zoo mp_handpose.py의 회전, 이동(-0.4), 확대(3배)와 같은 계산이다.
  HandRoi roiFromPoints(float[] px, float[] py) {
    float ux = px[2] - px[0];
    float uy = py[2] - py[0];
    float len = (float) Math.sqrt(ux * ux + uy * uy);
    if (len < 1e-3f) return null;
    HandRoi roi = new HandRoi();
    // d: 손가락에서 손목 쪽(영역의 아래), r: 영역의 오른쪽
    roi.dx = -ux / len;
    roi.dy = -uy / len;
    roi.rx = roi.dy;
    roi.ry = -roi.dx;
    float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
    float minY = Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
    for (int k = 0; k < px.length; k++) {
      float lx = px[k] * roi.rx + py[k] * roi.ry;
      float ly = px[k] * roi.dx + py[k] * roi.dy;
      minX = Math.min(minX, lx);
      maxX = Math.max(maxX, lx);
      minY = Math.min(minY, ly);
      maxY = Math.max(maxY, ly);
    }
    float bw = maxX - minX;
    float bh = maxY - minY;
    roi.cx = (minX + maxX) / 2f;
    roi.cy = (minY + maxY) / 2f + ROI_SHIFT_Y * bh;
    roi.side = Math.max(bw, bh) * ROI_ENLARGE;
    if (roi.side < 8) return null;
    return roi;
  }

  // ── 픽셀 샘플링 ──

  int subSamples(float unit) {
    return Math.max(1, Math.min(4, (int) Math.ceil(unit)));
  }

  // (fx, fy)를 중심으로 축 (ax, ay), (bx, by)가 이루는 칸을 sub x sub 점으로 평균해 RGB 0~1로 쓴다.
  // 좌표는 픽셀 가장자리 기준(0이 왼쪽 끝)이다. 영상 밖은 검은색이다.
  void sampleArea(int[] pixels, int w, int h, float fx, float fy, float ax, float ay, float bx, float by, int sub, float[] out, int at) {
    float r = 0, g = 0, b = 0;
    for (int sj = 0; sj < sub; sj++) {
      float tj = (sj + 0.5f) / sub - 0.5f;
      for (int si = 0; si < sub; si++) {
        float ti = (si + 0.5f) / sub - 0.5f;
        float x = fx + ti * ax + tj * bx - 0.5f;
        float y = fy + ti * ay + tj * by - 0.5f;
        int x0 = (int) Math.floor(x);
        int y0 = (int) Math.floor(y);
        float wx = x - x0;
        float wy = y - y0;
        int c00 = pixelAt(pixels, w, h, x0, y0);
        int c10 = pixelAt(pixels, w, h, x0 + 1, y0);
        int c01 = pixelAt(pixels, w, h, x0, y0 + 1);
        int c11 = pixelAt(pixels, w, h, x0 + 1, y0 + 1);
        float w00 = (1 - wx) * (1 - wy);
        float w10 = wx * (1 - wy);
        float w01 = (1 - wx) * wy;
        float w11 = wx * wy;
        r += ((c00 >> 16) & 0xFF) * w00 + ((c10 >> 16) & 0xFF) * w10 + ((c01 >> 16) & 0xFF) * w01 + ((c11 >> 16) & 0xFF) * w11;
        g += ((c00 >> 8) & 0xFF) * w00 + ((c10 >> 8) & 0xFF) * w10 + ((c01 >> 8) & 0xFF) * w01 + ((c11 >> 8) & 0xFF) * w11;
        b += (c00 & 0xFF) * w00 + (c10 & 0xFF) * w10 + (c01 & 0xFF) * w01 + (c11 & 0xFF) * w11;
      }
    }
    float norm = 1f / (255f * sub * sub);
    out[at] = r * norm;
    out[at + 1] = g * norm;
    out[at + 2] = b * norm;
  }

  int pixelAt(int[] pixels, int w, int h, int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return 0;
    return pixels[y * w + x];
  }

  // 손바닥 모델의 앵커: 24x24 격자에 2개씩(stride 8), 12x12 격자에 6개씩(stride 16). 합계 2016개.
  void buildAnchors() {
    int at = 0;
    int[] grids = {24, 12};
    int[] perCell = {2, 6};
    for (int g = 0; g < grids.length; g++) {
      int n = grids[g];
      for (int row = 0; row < n; row++) {
        for (int col = 0; col < n; col++) {
          for (int k = 0; k < perCell[g]; k++) {
            anchorX[at] = (col + 0.5f) / n;
            anchorY[at] = (row + 0.5f) / n;
            at++;
          }
        }
      }
    }
  }

  // ── 디버그 표시 ──

  void drawDebug(CameraManager camera) {
    if (debugFont == null) debugFont = app.createFont("Monospaced", 13);
    HandFrame frame = latest;
    Hand[] list = hands();

    app.pushStyle();
    for (Hand hand : list) {
      int ink = hand.id % 2 == 1 ? COLOR_A : COLOR_B;
      // 관절 모델에 넣은 영역
      app.noFill();
      app.stroke(ink, 90);
      app.strokeWeight(1);
      app.beginShape();
      for (int c = 0; c < 4; c++) app.vertex(camera.frameToScreenX(hand.roiX[c]), camera.frameToScreenY(hand.roiY[c]));
      app.endShape(PApplet.CLOSE);
      // 뼈대
      app.stroke(ink, 230);
      app.strokeWeight(2.5f);
      for (int k = 0; k < BONES.length; k += 2) {
        int a = BONES[k];
        int b = BONES[k + 1];
        app.line(camera.frameToScreenX(hand.x[a]), camera.frameToScreenY(hand.y[a]),
          camera.frameToScreenX(hand.x[b]), camera.frameToScreenY(hand.y[b]));
      }
      app.noStroke();
      for (int k = 0; k < 21; k++) {
        boolean tip = k == THUMB_TIP || k == INDEX_TIP || k == MIDDLE_TIP || k == RING_TIP || k == PINKY_TIP;
        app.fill(tip ? COLOR_TEXT : ink);
        float d = tip ? 9 : 6;
        app.ellipse(camera.frameToScreenX(hand.x[k]), camera.frameToScreenY(hand.y[k]), d, d);
      }
      app.fill(COLOR_TEXT);
      app.textFont(debugFont);
      app.textAlign(PApplet.LEFT, PApplet.BOTTOM);
      app.text("#" + hand.id + " " + (hand.rightHand ? "R" : "L") + " " + PApplet.nf(hand.score, 1, 2),
        camera.frameToScreenX(hand.x[WRIST]) + 8, camera.frameToScreenY(hand.y[WRIST]) - 6);
    }

    String line1 = "HANDS " + list.length + "  " + PApplet.nf(frame.inferenceMs, 1, 1) + " ms" + (frame.detected ? "  +detect" : "");
    String line2 = status;
    app.textFont(debugFont);
    float boxW = Math.max(app.textWidth(line1), app.textWidth(line2)) + 24;
    app.noStroke();
    app.fill(COLOR_PANEL);
    app.rect(16, app.height - 76, boxW, 52, 6);
    app.fill(COLOR_TEXT);
    app.textAlign(PApplet.LEFT, PApplet.TOP);
    app.text(line1, 28, app.height - 68);
    app.text(line2, 28, app.height - 48);
    app.popStyle();
  }
}

// ── 결과 자료형 ──

// 손 하나. 내보낸 뒤에는 바뀌지 않는다. 좌표는 원본 프레임 기준이다.
class Hand {
  int id;                     // 추적이 이어지는 동안 유지되는 번호
  float[] x = new float[21];  // 관절 좌표 (필터 적용)
  float[] y = new float[21];
  float[] z = new float[21];  // 손목 기준 상대 깊이. 작을수록 카메라에 가깝다
  float score;                // 관절 신뢰도 0~1
  float handedness;           // 모델 원값 0~1. 원본 영상에서는 0.5보다 크면 오른손
  boolean rightHand;          // HANDEDNESS_FLIP을 반영한 관람객 기준 오른손 여부
  float palmSize;             // 손목에서 중지 뿌리까지 거리 (px). 손 크기 기준으로 쓴다
  int trackedMs;              // 이 손을 추적한 시간
  float[] roiX = new float[4];
  float[] roiY = new float[4];
}

class HandFrame {
  Hand[] hands;
  int frameW, frameH;
  float inferenceMs;
  boolean detected;           // 이 프레임에서 손바닥 검출을 돌렸는지
  long stamp;                 // System.currentTimeMillis()

  HandFrame(Hand[] hands, int frameW, int frameH, float inferenceMs, boolean detected, long stamp) {
    this.hands = hands;
    this.frameW = frameW;
    this.frameH = frameH;
    this.inferenceMs = inferenceMs;
    this.detected = detected;
    this.stamp = stamp;
  }
}

class HandRoi {
  float cx, cy;               // 회전된 좌표계에서의 중심
  float side;                 // 한 변 길이 (px)
  float rx, ry;               // 영역의 오른쪽 방향 (단위 벡터)
  float dx, dy;               // 영역의 아래쪽 방향 = 손가락에서 손목 쪽 (단위 벡터)
}

class PalmBox {
  float x1, y1, x2, y2, score;
  float[] px = new float[7];
  float[] py = new float[7];
}

class LandmarkResult {
  float[] x = new float[21];
  float[] y = new float[21];
  float[] z = new float[21];
  float score;
  float handedness;
}

// 작업 스레드에서만 쓰는 추적 상태
class HandTrack {
  int id;
  long startedMs;
  float[] rawX = new float[21];   // 필터 전 좌표. 다음 프레임의 영역을 잡는 데 쓴다
  float[] rawY = new float[21];
  float[] rawZ = new float[21];
  OneEuro[] fx = new OneEuro[21];
  OneEuro[] fy = new OneEuro[21];
  float score;
  float handedness;
  HandRoi roi;
  float velX, velY;               // 손바닥 중심 속도 (원본 프레임 px/ms). 다음 영역 예측에 쓴다
  long lastMs;

  HandTrack(int id) {
    this.id = id;
    for (int k = 0; k < 21; k++) {
      fx[k] = new OneEuro();
      fy[k] = new OneEuro();
    }
  }

  void accept(LandmarkResult result, HandRoi usedRoi, long nowMs) {
    if (startedMs == 0) startedMs = nowMs;
    float oldX = palmCenterX();
    float oldY = palmCenterY();
    System.arraycopy(result.x, 0, rawX, 0, 21);
    System.arraycopy(result.y, 0, rawY, 0, 21);
    System.arraycopy(result.z, 0, rawZ, 0, 21);
    long dt = nowMs - lastMs;
    if (lastMs != 0 && dt > 0) {
      velX += ((palmCenterX() - oldX) / dt - velX) * HandTracker.PREDICT_SMOOTH;
      velY += ((palmCenterY() - oldY) / dt - velY) * HandTracker.PREDICT_SMOOTH;
    }
    lastMs = nowMs;
    // 왼손/오른손 판정은 흔들리지 않게 천천히 섞는다
    handedness = score == 0 ? result.handedness : handedness * 0.8f + result.handedness * 0.2f;
    score = result.score;
    roi = usedRoi;
    for (int k = 0; k < 21; k++) {
      fx[k].filter(result.x[k], nowMs);
      fy[k].filter(result.y[k], nowMs);
    }
  }

  float palmCenterX() {
    return (rawX[0] + rawX[5] + rawX[9] + rawX[13] + rawX[17]) / 5f;
  }

  float palmCenterY() {
    return (rawY[0] + rawY[5] + rawY[9] + rawY[13] + rawY[17]) / 5f;
  }

  float palmSize() {
    float dx = rawX[9] - rawX[0];
    float dy = rawY[9] - rawY[0];
    return (float) Math.sqrt(dx * dx + dy * dy);
  }

  Hand snapshot() {
    Hand hand = new Hand();
    hand.id = id;
    for (int k = 0; k < 21; k++) {
      hand.x[k] = fx[k].value;
      hand.y[k] = fy[k].value;
      hand.z[k] = rawZ[k];
    }
    hand.score = score;
    hand.handedness = handedness;
    hand.rightHand = (handedness > 0.5f) != HandTracker.HANDEDNESS_FLIP;
    float dx = hand.x[9] - hand.x[0];
    float dy = hand.y[9] - hand.y[0];
    hand.palmSize = (float) Math.sqrt(dx * dx + dy * dy);
    hand.trackedMs = (int) (System.currentTimeMillis() - startedMs);
    if (roi != null) {
      float[] cornerI = {-0.5f, 0.5f, 0.5f, -0.5f};
      float[] cornerJ = {-0.5f, -0.5f, 0.5f, 0.5f};
      for (int c = 0; c < 4; c++) {
        float lx = roi.cx + cornerI[c] * roi.side;
        float ly = roi.cy + cornerJ[c] * roi.side;
        hand.roiX[c] = lx * roi.rx + ly * roi.dx;
        hand.roiY[c] = lx * roi.ry + ly * roi.dy;
      }
    }
    return hand;
  }
}

// One Euro 필터: 느릴 때는 떨림을 강하게 누르고, 빠를 때는 지연을 줄인다.
class OneEuro {
  float value, derivative;
  long lastMs = 0;

  float filter(float input, long nowMs) {
    if (lastMs == 0) {
      lastMs = nowMs;
      value = input;
      derivative = 0;
      return value;
    }
    float dt = Math.max(1, nowMs - lastMs) / 1000f;
    lastMs = nowMs;
    float rawDerivative = (input - value) / dt;
    float aD = alpha(HandTracker.FILTER_D_CUTOFF, dt);
    derivative = derivative + aD * (rawDerivative - derivative);
    float cutoff = HandTracker.FILTER_MIN_CUTOFF + HandTracker.FILTER_BETA * Math.abs(derivative);
    float a = alpha(cutoff, dt);
    value = value + a * (input - value);
    return value;
  }

  float alpha(float cutoff, float dt) {
    float tau = 1f / (2f * (float) Math.PI * cutoff);
    return 1f / (1f + tau / dt);
  }
}
