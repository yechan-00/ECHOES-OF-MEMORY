// BackgroundMask
//
// 고정된 카메라에서 기준 배경을 평균한 뒤, 현재 프레임과 색이 다른 영역을 전경 후보로 둔다.
// 사람 인식이 아니다. 움직임 양과 방향은 MotionDetector의 역할이다.
// 좌표는 거울 반전 전의 카메라 원본 픽셀이다.

class BackgroundMask {
  static final int PHASE_IDLE = 0;
  static final int PHASE_COUNTDOWN = 1;
  static final int PHASE_SAMPLING = 2;

  static final int COUNTDOWN_MS = 3000;
  static final int CAPTURE_FRAMES = 8;
  static final int SAMPLE_GAP_MS = 2000;
  static final int MASK_CELL = 4;
  static final int DIFF_THRESHOLD = 32;
  static final int DIFF_SOFTNESS = 30;
  static final float TEMPORAL_BLEND = 0.5;
  static final int SUCCESS_MS = 4000;

  PApplet app;
  PFont titleFont;
  PFont bodyFont;

  int phase = PHASE_IDLE;
  int countdownStart = 0;
  int lastSampleAt = 0;
  int samplesCollected = 0;
  int sampleW = 0;
  int sampleH = 0;
  int successUntil = 0;

  boolean ready = false;
  boolean maskReset = true;
  boolean maskDirty = false;
  int boundIndex = -999;
  String boundLabel = null;
  String errorText = "";
  String flashText = "";
  int flashUntil = 0;

  byte[] bgR;
  byte[] bgG;
  byte[] bgB;
  int[] sumR;
  int[] sumG;
  int[] sumB;
  int bgW = 0;
  int bgH = 0;

  int maskW = 0;
  int maskH = 0;
  int[] cellDiff;
  float[] rawMask;
  float[] workMask;
  float[] blurredMask;
  float[] stable;
  PImage debugImage;

  BackgroundMask(PApplet app) {
    this.app = app;
    titleFont = app.createFont("SansSerif", 64);
    bodyFont = app.createFont("SansSerif", 22);
  }

  boolean isReady() {
    return ready && stable != null;
  }

  float maskAt(int sourceX, int sourceY) {
    if (!isReady()) return 0;
    int mx = sourceX / MASK_CELL;
    int my = sourceY / MASK_CELL;
    if (mx < 0 || my < 0 || mx >= maskW || my >= maskH) return 0;
    return stable[my * maskW + mx];
  }

  String statusLabel() {
    if (phase == PHASE_COUNTDOWN) return "Countdown";
    if (phase == PHASE_SAMPLING) return "Sampling " + samplesCollected + "/" + CAPTURE_FRAMES;
    if (!ready && errorText.length() > 0) return "Recalibration needed";
    if (ready) return "Background ready";
    return "Background not set";
  }

  void beginCapture(CameraManager camera) {
    if (phase != PHASE_IDLE) return;
    if (camera == null || !camera.pixelsReady() || !"live".equals(camera.connectionState())) {
      flash("카메라 영상이 있을 때만 보정할 수 있습니다.");
      return;
    }
    errorText = "";
    flashText = "";
    successUntil = 0;
    samplesCollected = 0;
    countdownStart = app.millis();
    phase = PHASE_COUNTDOWN;
  }

  void update(CameraManager camera) {
    if (camera == null) {
      if (phase != PHASE_IDLE) cancelCalibration("카메라가 없어 보정을 중단했습니다.");
      return;
    }

    int seenIndex = camera.activeIndex;
    String seenLabel = camera.activeLabel();
    if (boundLabel == null) {
      boundIndex = seenIndex;
      boundLabel = seenLabel;
    } else if (seenIndex != boundIndex || !boundLabel.equals(seenLabel)) {
      boundIndex = seenIndex;
      boundLabel = seenLabel;
      if (ready || phase != PHASE_IDLE) {
        invalidate("카메라가 바뀌어 기준 배경을 지웠습니다. B로 다시 보정하세요.");
      }
    }

    if (!camera.pixelsReady() || !"live".equals(camera.connectionState())) {
      if (phase != PHASE_IDLE) {
        cancelCalibration("카메라가 끊겨 보정을 중단했습니다. B로 다시 시도하세요.");
      }
      return;
    }

    int w = camera.frameWidth();
    int h = camera.frameHeight();
    if (w <= 0 || h <= 0) return;

    if (ready && (w != bgW || h != bgH)) {
      invalidate("카메라 해상도가 바뀌어 기준 배경을 지웠습니다. B로 다시 보정하세요.");
    }
    if (phase == PHASE_SAMPLING && (w != sampleW || h != sampleH)) {
      cancelCalibration("해상도가 바뀌어 보정을 중단했습니다. B로 다시 시도하세요.");
      return;
    }

    PImage source = camera.frame();
    int[] pixels = source == null ? null : source.pixels;
    boolean fresh = camera.hasNewFrame() && pixels != null && pixels.length >= w * h;

    if (phase == PHASE_COUNTDOWN && app.millis() - countdownStart >= COUNTDOWN_MS) {
      startSampling(w, h);
    }

    if (phase == PHASE_SAMPLING && fresh) {
      accumulate(pixels, w * h);
      if (samplesCollected >= CAPTURE_FRAMES) {
        commit(w, h);
        computeMask(pixels, w, h);
        return;
      }
    } else if (phase == PHASE_SAMPLING && samplesCollected > 0 && app.millis() - lastSampleAt > SAMPLE_GAP_MS) {
      cancelCalibration("프레임이 멈춰 보정을 중단했습니다. B로 다시 시도하세요.");
      return;
    }

    if (ready && phase == PHASE_IDLE && fresh) {
      computeMask(pixels, w, h);
    }
  }

  void drawMask(CameraManager camera) {
    if (!isReady() || camera == null || !camera.isReady()) return;
    if (debugImage == null || maskDirty) paintDebugImage();
    if (debugImage == null) return;

    float x0 = camera.frameToScreenX(0);
    float x1 = camera.frameToScreenX(camera.frameWidth());
    float y0 = camera.frameToScreenY(0);
    float y1 = camera.frameToScreenY(camera.frameHeight());
    float left = app.min(x0, x1);
    float top = app.min(y0, y1);
    float placedW = app.abs(x1 - x0);
    float placedH = app.abs(y1 - y0);
    if (placedW <= 1 || placedH <= 1) return;

    app.imageMode(PApplet.CORNER);
    app.pushMatrix();
    if (camera.mirrorEnabled()) {
      app.translate(left + placedW, top);
      app.scale(-1, 1);
      app.image(debugImage, 0, 0, placedW, placedH);
    } else {
      app.image(debugImage, left, top, placedW, placedH);
    }
    app.popMatrix();
  }

  void drawNotice(boolean debugOn) {
    if (phase == PHASE_COUNTDOWN) {
      int remain = COUNTDOWN_MS - (app.millis() - countdownStart);
      int seconds = (remain + 999) / 1000;
      if (seconds < 1) seconds = 1;
      if (seconds > 3) seconds = 3;
      drawCard("화면 앞에서 잠시 벗어나 주세요", seconds, "사람이 없는 장면이 기준 배경이 됩니다");
      return;
    }
    if (phase == PHASE_SAMPLING) {
      drawCard("배경을 기록하는 중", samplesCollected + " / " + CAPTURE_FRAMES, "그대로 화면 밖에 있어 주세요");
      return;
    }
    if (errorText.length() > 0) {
      drawCard(errorText, "", "");
      return;
    }
    if (ready && app.millis() < successUntil) {
      drawCard("배경 보정 완료", "다시 카메라 앞으로 들어오세요", "사람이 배경에 들어갔거나 조명이 바뀌면 B로 다시 찍으세요");
      return;
    }
    if (flashText.length() > 0 && app.millis() < flashUntil) {
      drawCard(flashText, "", "");
      return;
    }
    if (!ready && !debugOn) {
      drawBottomHint("화면 앞에서 벗어난 뒤 B를 누르면 배경을 보정합니다");
    }
  }

  void flash(String message) {
    flashText = message;
    flashUntil = app.millis() + 2800;
  }

  void cancelCalibration(String message) {
    phase = PHASE_IDLE;
    samplesCollected = 0;
    successUntil = 0;
    flashUntil = 0;
    errorText = message;
  }

  void invalidate(String message) {
    ready = false;
    maskReset = true;
    maskDirty = false;
    phase = PHASE_IDLE;
    samplesCollected = 0;
    successUntil = 0;
    flashUntil = 0;
    errorText = message;
    debugImage = null;
  }

  void startSampling(int w, int h) {
    int n = w * h;
    if (sumR == null || sumR.length != n) {
      sumR = new int[n];
      sumG = new int[n];
      sumB = new int[n];
    } else {
      for (int i = 0; i < n; i++) {
        sumR[i] = 0;
        sumG[i] = 0;
        sumB[i] = 0;
      }
    }
    sampleW = w;
    sampleH = h;
    samplesCollected = 0;
    lastSampleAt = app.millis();
    phase = PHASE_SAMPLING;
  }

  void accumulate(int[] pixels, int n) {
    for (int i = 0; i < n; i++) {
      int colorValue = pixels[i];
      sumR[i] += (colorValue >> 16) & 0xff;
      sumG[i] += (colorValue >> 8) & 0xff;
      sumB[i] += colorValue & 0xff;
    }
    samplesCollected++;
    lastSampleAt = app.millis();
  }

  void commit(int w, int h) {
    int n = w * h;
    if (sumR == null || samplesCollected <= 0 || sumR.length < n) {
      cancelCalibration("배경을 저장하지 못했습니다. B로 다시 시도하세요.");
      return;
    }
    byte[] nextR = new byte[n];
    byte[] nextG = new byte[n];
    byte[] nextB = new byte[n];
    int samples = samplesCollected;
    for (int i = 0; i < n; i++) {
      nextR[i] = (byte) (sumR[i] / samples);
      nextG[i] = (byte) (sumG[i] / samples);
      nextB[i] = (byte) (sumB[i] / samples);
    }
    bgR = nextR;
    bgG = nextG;
    bgB = nextB;
    bgW = w;
    bgH = h;
    ready = true;
    phase = PHASE_IDLE;
    samplesCollected = 0;
    maskReset = true;
    errorText = "";
    successUntil = app.millis() + SUCCESS_MS;
  }

  void computeMask(int[] pixels, int w, int h) {
    if (!ready || bgR == null || w != bgW || h != bgH) return;
    if (pixels == null || pixels.length < w * h) return;

    int columns = (w + MASK_CELL - 1) / MASK_CELL;
    int rows = (h + MASK_CELL - 1) / MASK_CELL;
    ensureMask(columns, rows);

    int index = 0;
    for (int my = 0; my < rows; my++) {
      int y0 = my * MASK_CELL;
      int y1 = y0 + MASK_CELL;
      if (y1 > h) y1 = h;
      for (int mx = 0; mx < columns; mx++) {
        int x0 = mx * MASK_CELL;
        int x1 = x0 + MASK_CELL;
        if (x1 > w) x1 = w;
        int diff = cellDifference(pixels, w, x0, x1, y0, y1);
        cellDiff[index] = diff;
        rawMask[index] = soften(diff);
        index++;
      }
    }

    despeckle(rawMask, workMask, columns, rows);
    blur(workMask, blurredMask, columns, rows);
    mixTemporal(blurredMask, columns * rows);
    maskDirty = true;
  }

  int cellDifference(int[] pixels, int frameW, int x0, int x1, int y0, int y1) {
    int sum = 0;
    int count = 0;
    for (int y = y0; y < y1; y++) {
      int row = y * frameW;
      for (int x = x0; x < x1; x++) {
        int current = pixels[row + x];
        int backgroundIndex = row + x;
        int dr = ((current >> 16) & 0xff) - (bgR[backgroundIndex] & 0xff);
        int dg = ((current >> 8) & 0xff) - (bgG[backgroundIndex] & 0xff);
        int db = (current & 0xff) - (bgB[backgroundIndex] & 0xff);
        if (dr < 0) dr = -dr;
        if (dg < 0) dg = -dg;
        if (db < 0) db = -db;
        int mean = (dr + dg + db) / 3;
        int peak = dr;
        if (dg > peak) peak = dg;
        if (db > peak) peak = db;
        sum += (mean * 2 + peak) / 3;
        count++;
      }
    }
    if (count == 0) return 0;
    return sum / count;
  }

  float soften(int diff) {
    if (diff <= DIFF_THRESHOLD) return 0;
    if (diff >= DIFF_THRESHOLD + DIFF_SOFTNESS) return 1;
    return (diff - DIFF_THRESHOLD) / (float) DIFF_SOFTNESS;
  }

  void despeckle(float[] src, float[] dst, int w, int h) {
    for (int y = 0; y < h; y++) {
      int row = y * w;
      for (int x = 0; x < w; x++) {
        int index = row + x;
        float value = src[index];
        if (value <= 0.4f) {
          dst[index] = value;
          continue;
        }
        int friends = 0;
        for (int dy = -1; dy <= 1; dy++) {
          int ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          int nrow = ny * w;
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            if (src[nrow + nx] >= 0.2f) friends++;
          }
        }
        dst[index] = friends == 0 ? 0 : value;
      }
    }
  }

  void blur(float[] src, float[] dst, int w, int h) {
    for (int y = 0; y < h; y++) {
      int row = y * w;
      for (int x = 0; x < w; x++) {
        float sum = 0;
        int weight = 0;
        for (int dy = -1; dy <= 1; dy++) {
          int ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          int nrow = ny * w;
          for (int dx = -1; dx <= 1; dx++) {
            int nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            sum += src[nrow + nx];
            weight++;
          }
        }
        dst[row + x] = weight == 0 ? 0 : sum / weight;
      }
    }
  }

  void mixTemporal(float[] current, int n) {
    if (maskReset || stable == null) {
      for (int i = 0; i < n; i++) stable[i] = current[i];
      maskReset = false;
      return;
    }
    float keep = 1 - TEMPORAL_BLEND;
    for (int i = 0; i < n; i++) {
      float value = stable[i] * keep + current[i] * TEMPORAL_BLEND;
      if (value < 0.05f && current[i] < 0.05f) value = 0;
      stable[i] = value;
    }
  }

  void ensureMask(int columns, int rows) {
    int n = columns * rows;
    if (stable != null && maskW == columns && maskH == rows && stable.length == n) return;
    maskW = columns;
    maskH = rows;
    cellDiff = new int[n];
    rawMask = new float[n];
    workMask = new float[n];
    blurredMask = new float[n];
    stable = new float[n];
    maskReset = true;
    debugImage = null;
  }

  void paintDebugImage() {
    if (maskW <= 0 || maskH <= 0 || stable == null) return;
    if (debugImage == null || debugImage.width != maskW || debugImage.height != maskH) {
      debugImage = app.createImage(maskW, maskH, PApplet.ARGB);
    }
    debugImage.loadPixels();
    int[] out = debugImage.pixels;
    int n = maskW * maskH;
    for (int i = 0; i < n; i++) {
      float amount = stable[i];
      if (amount < 0) amount = 0;
      if (amount > 1) amount = 1;
      int red = (int) (8 + 48 * amount);
      int green = (int) (13 + 219 * amount);
      int blue = (int) (24 + 189 * amount);
      out[i] = 0xff000000 | (red << 16) | (green << 8) | blue;
    }
    debugImage.updatePixels();
    maskDirty = false;
  }

  void drawBottomHint(String message) {
    app.textFont(bodyFont);
    float cardW = app.min(app.textWidth(message) + 48, app.width - 48);
    float cardY = app.height - 92;
    app.noStroke();
    app.rectMode(PApplet.CORNER);
    app.fill(8, 13, 24, 210);
    app.rect((app.width - cardW) / 2f, cardY, cardW, 40, 8);
    app.fill(#A5FFF2);
    app.textAlign(PApplet.CENTER, PApplet.CENTER);
    app.text(message, app.width / 2f, cardY + 20);
  }

  void drawCard(String title, String body, String detail) {
    app.textFont(bodyFont);
    float titleW = title == null ? 0 : app.textWidth(title);
    float bodyW = body == null || body.length() == 0 ? 0 : app.textWidth(body);
    float detailW = detail == null || detail.length() == 0 ? 0 : app.textWidth(detail);
    float cardW = app.max(titleW, app.max(bodyW, detailW)) + 64;
    if (cardW < 280) cardW = 280;
    if (cardW > app.width - 48) cardW = app.width - 48;

    boolean numeric = body.length() > 0 && body.length() <= 2 && body.charAt(0) >= '0' && body.charAt(0) <= '9' && phase == PHASE_COUNTDOWN;
    float cardH = 88;
    if (body.length() > 0) cardH += numeric ? 72 : 36;
    if (detail.length() > 0) cardH += 32;

    float cardX = (app.width - cardW) / 2f;
    float cardY = (app.height - cardH) / 2f;
    app.noStroke();
    app.rectMode(PApplet.CORNER);
    app.fill(8, 13, 24, 220);
    app.rect(cardX, cardY, cardW, cardH, 8);

    float cursor = cardY + 36;
    app.textAlign(PApplet.CENTER, PApplet.CENTER);
    app.fill(#A5FFF2);
    app.textFont(bodyFont);
    if (title != null && title.length() > 0) {
      app.text(title, app.width / 2f, cursor);
      cursor += 40;
    }
    if (body != null && body.length() > 0) {
      if (numeric) {
        app.textFont(titleFont);
        app.fill(#38E8D5);
        app.text(body, app.width / 2f, cursor + 16);
        cursor += 72;
      } else {
        app.textFont(bodyFont);
        app.fill(#38E8D5);
        app.text(body, app.width / 2f, cursor);
        cursor += 36;
      }
    }
    if (detail != null && detail.length() > 0) {
      app.textFont(bodyFont);
      app.fill(#A78BFA);
      app.text(detail, app.width / 2f, cursor);
    }
  }

  void drawCard(String title, int seconds, String detail) {
    drawCard(title, String.valueOf(seconds), detail);
  }
}
