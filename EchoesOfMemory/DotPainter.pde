// DotPainter
//
// 카메라 프레임에서 무작위 위치의 색을 골라 점을 찍는다.
// 점은 화면 크기의 캔버스에 쌓이므로, 프레임이 지날수록 모습이 점묘화처럼 드러난다.
// 점 크기는 마우스 x 위치로 정한다. 왼쪽은 작고 촘촘하게, 오른쪽은 크고 거칠게 찍힌다.
//
// CameraManager의 공개 메서드만 사용한다. read()와 loadPixels()는 호출하지 않는다.
// 색은 원본 프레임 좌표로 읽고, 위치는 frameToScreenX/Y로 바꿔 좌우 반전을 따른다.

class DotPainter {
  static final int DOTS_PER_FRAME = 400;
  static final int MIN_SIZE = 1;
  static final int MAX_SIZE = 50;
  static final int BACKGROUND = 0xFF080D18;

  PApplet app;
  PGraphics canvas;
  boolean enabled = true;
  int dotSize = MIN_SIZE;

  DotPainter(PApplet app) {
    this.app = app;
    canvas = app.createGraphics(app.width, app.height);
    clear();
  }

  void update(CameraManager camera) {
    dotSize = (int) PApplet.map(app.mouseX, 0, app.width, MIN_SIZE, MAX_SIZE);
    dotSize = PApplet.constrain(dotSize, MIN_SIZE, MAX_SIZE);
    if (!enabled || !camera.pixelsReady()) return;

    int frameW = camera.frameWidth();
    int frameH = camera.frameHeight();
    canvas.beginDraw();
    canvas.noStroke();
    for (int i = 0; i < DOTS_PER_FRAME; i++) {
      int fx = (int) app.random(frameW);
      int fy = (int) app.random(frameH);
      if (!camera.pixelInRange(fx, fy)) continue;
      canvas.fill(camera.pixelColor(fx, fy));
      canvas.ellipse(camera.frameToScreenX(fx), camera.frameToScreenY(fy), dotSize, dotSize);
    }
    canvas.endDraw();
  }

  void draw() {
    app.image(canvas, 0, 0, app.width, app.height);
  }

  void clear() {
    canvas.beginDraw();
    canvas.background(BACKGROUND);
    canvas.endDraw();
  }

  void toggle() {
    enabled = !enabled;
  }

  void save() {
    String stamp = PApplet.nf(PApplet.year(), 4) + PApplet.nf(PApplet.month(), 2) + PApplet.nf(PApplet.day(), 2)
      + "-" + PApplet.nf(PApplet.hour(), 2) + PApplet.nf(PApplet.minute(), 2) + PApplet.nf(PApplet.second(), 2);
    String path = app.sketchPath("captures/dots-" + stamp + ".png");
    canvas.save(path);
    PApplet.println("ECHOES saved " + path);
  }

  String statusLine() {
    return (enabled ? "Dots" : "Camera") + "  size " + dotSize;
  }
}
