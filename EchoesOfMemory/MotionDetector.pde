// MotionDetector
//
// 담당:
// 연속된 카메라 프레임을 비교해(프레임 차분) 화면의 어느 위치가 얼마나 움직였는지 계산한다.
// 이 결과는 입자의 흩어짐, 상태 전환, 네온 파동의 시작점을 결정하는 데 쓰인다.
//
// 처리 순서 (새 카메라 프레임마다):
//   1. 흑백 변환: 프레임 전체를 밝기(0~255) 배열로 바꾼다.
//   2. 이전 프레임의 밝기와 픽셀별 차이를 구한다.
//   3. 차이가 임계값보다 크면 1, 아니면 0으로 판정한다. 작은 노이즈는 여기서 걸러진다.
//   4. 화면을 CELL_SIZE 칸으로 나누고, 칸 안에서 1로 판정된 샘플의 비율(0~1)을 구한다.
//      비율이 MIN_CELL_RATIO보다 작으면 칸 모서리만 스친 것으로 보고 0으로 버린다.
//   5. 그 비율을 그대로 칸 값으로 쓴다. 감쇠(여운)는 없어서 움직임이 멈추면 다음 프레임에 0이 된다.
//      여운이 필요한 효과는 이 값을 받는 쪽에서 따로 만든다.
//
// 출력 (다른 모듈은 읽기만 한다):
//   cols, rows : 격자 크기. 1280×720, CELL_SIZE 8이면 160×90.
//   grid       : 칸별 움직임 강도 0~1. 인덱스는 col + row * cols.
//   total      : 영상이 놓인 칸들의 평균 강도 0~1.
//   center     : 이번 카메라 프레임에서 감지된 값으로 구한 움직임 중심(화면 좌표). 움직임이 없으면 null.
//
// 좌표:
//   grid와 center는 모두 화면 좌표(1280×720) 기준이다. 거울 반전과 Fit/Fill 배치는
//   CameraManager.screenToFrameX/Y()로 여기서 처리하므로, 받는 쪽은 신경 쓰지 않는다.
//   Fit 배치의 좌우 여백처럼 영상이 없는 칸은 항상 0이다.
//
// 카메라 프레임은 CameraManager.frame()으로 읽기만 한다. read(), start(), stop()은 호출하지 않는다.

class MotionDetector {
  static final int   CELL_SIZE        = 8;      // 칸 크기(화면 px). 작을수록 정밀하고 노이즈에 민감하다
  static final int   PIXEL_STEP       = 2;      // 칸 안에서 몇 화면 px 간격으로 검사할지
  static final float DIFF_THRESHOLD   = 30;     // 밝기 차이 임계값 기본값 (0~255)
  static final float MIN_CELL_RATIO   = 0.1;    // 칸 안 움직인 샘플 비율이 이보다 작으면 0
  static final float CENTER_MIN_TOTAL = 0.01;   // total이 이보다 작으면 center = null
  static final float THRESHOLD_STEP   = 5;      // [ ] 키로 임계값을 바꾸는 폭
  static final float THRESHOLD_MIN    = 5;
  static final float THRESHOLD_MAX    = 120;

  static final int COLOR_LOW   = 0xFF38E8D5;    // 약한 움직임 (청록)
  static final int COLOR_HIGH  = 0xFFA78BFA;    // 강한 움직임 (보라)
  static final int COLOR_TEXT  = 0xFFF4FBFF;
  static final int COLOR_PANEL = 0xCC080D18;

  PApplet app;
  CameraManager camera;

  // ── 출력 ──
  int cols, rows;
  float[] grid;
  float total = 0;
  PVector center = null;

  // ── 내부 상태 ──
  float diffThreshold = DIFF_THRESHOLD;
  boolean showDebug = false;
  boolean[] cellHasVideo;     // 영상이 덮고 있는 칸인지
  int[] prevGray;             // 이전 프레임 밝기 (원본 프레임 좌표)
  int[] currGray;             // 현재 프레임 밝기
  int grayW = 0, grayH = 0;
  boolean hasPrev = false;

  // 이번 카메라 프레임에서 새로 감지된 값의 합계 (center 계산용)
  float freshSum = 0;
  float freshX = 0;
  float freshY = 0;

  // 샘플 위치의 화면 → 원본 좌표 변환표. 새 프레임마다 다시 만든다 (-1이면 영상 밖).
  int[] sampleFrameX;
  int[] sampleFrameY;

  PFont debugFont;

  MotionDetector(PApplet app, CameraManager camera) {
    this.app = app;
    this.camera = camera;
    cols = ceil(app.width / (float) CELL_SIZE);
    rows = ceil(app.height / (float) CELL_SIZE);
    grid = new float[cols * rows];
    cellHasVideo = new boolean[cols * rows];
    sampleFrameX = new int[app.width];
    sampleFrameY = new int[app.height];
    debugFont = app.createFont("Monospaced", 13);
  }

  // draw()에서 camera.update() 다음에 매 프레임 한 번 호출한다.
  void update() {
    if (!camera.pixelsReady()) {
      reset();
      return;
    }

    // 감쇠 없음: 새 카메라 프레임이 오면 값을 통째로 바꾸고, 그 사이 draw 프레임에서는 유지한다.
    // 수신이 끊기면(약 2초) 마지막 움직임이 남지 않도록 비운다.
    if (camera.connectionState().equals("interrupted")) {
      reset();
      return;
    }

    if (camera.hasNewFrame()) {
      PImage frame = camera.frame();
      if (frame.width != grayW || frame.height != grayH) {
        allocateGray(frame.width, frame.height);
      }
      toGray(frame.pixels, currGray);
      if (hasPrev) {
        buildSampleMap();
        compareCells();
      }
      // 현재 밝기를 다음 비교의 기준으로 넘긴다 (배열만 교환, 복사 없음)
      int[] swap = prevGray;
      prevGray = currGray;
      currGray = swap;
      hasPrev = true;
    }

    summarize();
  }

  // ── 받는 쪽이 쓰는 조회 함수 ──

  // 화면 좌표 (x, y)가 속한 칸의 강도 0~1. 화면 밖이면 0.
  float intensityAt(float x, float y) {
    if (x < 0 || y < 0 || x >= app.width || y >= app.height) return 0;
    int c = min((int) (x / CELL_SIZE), cols - 1);
    int r = min((int) (y / CELL_SIZE), rows - 1);
    return grid[c + r * cols];
  }

  // 칸 번호로 직접 조회. 범위 밖이면 0.
  float cellIntensity(int col, int row) {
    if (col < 0 || row < 0 || col >= cols || row >= rows) return 0;
    return grid[col + row * cols];
  }

  // 카메라 전환·재검색처럼 이전 프레임과 비교하면 안 될 때 호출한다.
  void reset() {
    hasPrev = false;
    for (int i = 0; i < grid.length; i++) {
      grid[i] = 0;
      cellHasVideo[i] = false;
    }
    total = 0;
    center = null;
    freshSum = 0;
    freshX = 0;
    freshY = 0;
  }

  // ── 1. 흑백 변환 ──

  void allocateGray(int w, int h) {
    grayW = w;
    grayH = h;
    prevGray = new int[w * h];
    currGray = new int[w * h];
    hasPrev = false;
  }

  // 정수 연산으로 밝기를 구한다 (0.30R + 0.59G + 0.11B 근사).
  void toGray(int[] pixels, int[] out) {
    int n = min(out.length, pixels.length);
    for (int i = 0; i < n; i++) {
      int argb = pixels[i];
      int r = (argb >> 16) & 0xFF;
      int g = (argb >> 8) & 0xFF;
      int b = argb & 0xFF;
      out[i] = (r * 77 + g * 151 + b * 28) >> 8;
    }
  }

  // ── 좌표 변환표 ──

  // 화면 x, y를 각각 원본 프레임 좌표로 바꿔 둔다. 거울 반전과 Fit/Fill이 여기서 반영된다.
  void buildSampleMap() {
    for (int x = 0; x < app.width; x++) {
      int fx = floor(camera.screenToFrameX(x + 0.5));
      sampleFrameX[x] = (fx >= 0 && fx < grayW) ? fx : -1;
    }
    for (int y = 0; y < app.height; y++) {
      int fy = floor(camera.screenToFrameY(y + 0.5));
      sampleFrameY[y] = (fy >= 0 && fy < grayH) ? fy : -1;
    }
  }

  // ── 2~5. 차이 → 0/1 판정 → 칸별 비율 ──

  void compareCells() {
    freshSum = 0;
    freshX = 0;
    freshY = 0;
    for (int r = 0; r < rows; r++) {
      int y0 = r * CELL_SIZE;
      int y1 = min(y0 + CELL_SIZE, app.height);
      for (int c = 0; c < cols; c++) {
        int x0 = c * CELL_SIZE;
        int x1 = min(x0 + CELL_SIZE, app.width);

        int samples = 0;
        int moved = 0;
        for (int y = y0; y < y1; y += PIXEL_STEP) {
          int fy = sampleFrameY[y];
          if (fy < 0) continue;
          int rowOffset = fy * grayW;
          for (int x = x0; x < x1; x += PIXEL_STEP) {
            int fx = sampleFrameX[x];
            if (fx < 0) continue;
            int i = rowOffset + fx;
            samples++;
            if (abs(currGray[i] - prevGray[i]) > diffThreshold) moved++;
          }
        }

        int index = c + r * cols;
        cellHasVideo[index] = samples > 0;
        if (samples == 0) {
          grid[index] = 0;
          continue;
        }
        float ratio = moved / (float) samples;
        if (ratio < MIN_CELL_RATIO) {
          grid[index] = 0;
          continue;
        }
        grid[index] = ratio;
        freshSum += ratio;
        freshX += ratio * (c + 0.5) * CELL_SIZE;
        freshY += ratio * (r + 0.5) * CELL_SIZE;
      }
    }
    updateCenter();
  }

  // 새로 감지된 값만으로 중심을 구한다. 새 카메라 프레임이 없을 때는 직전 중심을 유지한다.
  void updateCenter() {
    int videoCells = 0;
    for (int i = 0; i < cellHasVideo.length; i++) {
      if (cellHasVideo[i]) videoCells++;
    }
    float freshTotal = videoCells > 0 ? freshSum / videoCells : 0;
    if (freshTotal < CENTER_MIN_TOTAL || freshSum <= 0) {
      center = null;
    } else if (center == null) {
      center = new PVector(freshX / freshSum, freshY / freshSum);
    } else {
      center.set(freshX / freshSum, freshY / freshSum);
    }
  }

  // ── 요약값 ──

  void summarize() {
    float sum = 0;
    int videoCells = 0;
    for (int i = 0; i < grid.length; i++) {
      if (!cellHasVideo[i]) continue;
      videoCells++;
      sum += grid[i];
    }
    total = videoCells > 0 ? sum / videoCells : 0;
  }

  // ── 디버그 표시 (G 키) ──

  void handleKey(char typed) {
    char command = Character.toLowerCase(typed);
    if (command == 'g') {
      showDebug = !showDebug;
    } else if (showDebug && typed == '[') {
      diffThreshold = max(THRESHOLD_MIN, diffThreshold - THRESHOLD_STEP);
    } else if (showDebug && typed == ']') {
      diffThreshold = min(THRESHOLD_MAX, diffThreshold + THRESHOLD_STEP);
    }
  }

  void drawDebug() {
    if (!showDebug) return;

    app.pushStyle();
    app.noStroke();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        float v = grid[c + r * cols];
        if (v < 0.02) continue;
        int tint = app.lerpColor(COLOR_LOW, COLOR_HIGH, v);
        app.fill(tint, 60 + 180 * v);
        app.rect(c * CELL_SIZE, r * CELL_SIZE, CELL_SIZE, CELL_SIZE);
      }
    }

    if (center != null) {
      app.stroke(COLOR_TEXT);
      app.strokeWeight(2);
      app.noFill();
      app.ellipse(center.x, center.y, 28, 28);
      app.line(center.x - 20, center.y, center.x + 20, center.y);
      app.line(center.x, center.y - 20, center.x, center.y + 20);
    }

    String line1 = "MOTION  total " + nf(total, 1, 3)
      + "   center " + (center == null ? "-" : (int) center.x + "," + (int) center.y);
    String line2 = "grid " + cols + "x" + rows + "   cell " + CELL_SIZE + "px   threshold "
      + (int) diffThreshold + "   [ ] adjust   G hide";
    float panelW = 540;
    float panelH = 46;
    float panelX = 16;
    float panelY = app.height - panelH - 16;
    app.noStroke();
    app.fill(COLOR_PANEL);
    app.rect(panelX, panelY, panelW, panelH, 6);
    app.textFont(debugFont);
    app.textAlign(LEFT, TOP);
    app.fill(COLOR_TEXT);
    app.text(line1, panelX + 10, panelY + 6);
    app.fill(COLOR_LOW);
    app.text(line2, panelX + 10, panelY + 24);
    app.popStyle();
  }
}
