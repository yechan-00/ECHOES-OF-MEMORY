// ECHOES OF MEMORY
// 1단계: 시작 화면만 표시한다.
// 카메라, 파티클, 움직임 감지, 잔상, 네온 효과는 이 단계에서 구현하지 않는다.

PFont titleFont;
PFont subtitleFont;
PFont statusFont;

void setup() {
  size(1280, 720);
  pixelDensity(displayDensity());
  surface.setTitle("ECHOES OF MEMORY");

  titleFont = createFont("SansSerif", 54);
  subtitleFont = createFont("SansSerif", 18);
  statusFont = createFont("Monospaced", 13);

  textAlign(CENTER, CENTER);
  noStroke();
}

void draw() {
  background(#080D18);

  fill(#F4FBFF);
  textFont(titleFont);
  text("ECHOES OF MEMORY", width / 2.0, height / 2.0 - 24);

  fill(#B7A4FF);
  textFont(subtitleFont);
  text("Interactive Particle Portrait", width / 2.0, height / 2.0 + 28);

  fill(#7F8DA3);
  textFont(statusFont);
  text("SYSTEM INITIALIZED", width / 2.0, height - 40);
}
