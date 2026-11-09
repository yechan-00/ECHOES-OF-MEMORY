// Particle
//
// 초상화를 이루는 빛 입자 하나.
// home은 화면상의 목표 좌표다. position은 스프링이 움직이는 현재 좌표다.
// 불규칙한 배치와 미세한 유영은 그릴 때만 더한다.

class Particle {
  PVector position = new PVector();
  PVector home = new PVector();
  PVector velocity = new PVector();
  PVector acceleration = new PVector();
  int sampleX = 0;
  int sampleY = 0;
  int fillColor = 0xFF080D18;
  float size = 2;
  float alpha = 0;
  float jitterX = 0;
  float jitterY = 0;
  float phase = 0;
  float sizeBias = 1;
  float presence = 0;
  float speedSq = 0;
  boolean accent = false;
  boolean anchored = false;
  boolean visible = false;

  void prepare(int index, int sourceX, int sourceY) {
    sampleX = sourceX;
    sampleY = sourceY;
    jitterX = unitHash(index * 13 + 1) * 2 - 1;
    jitterY = unitHash(index * 29 + 5) * 2 - 1;
    phase = unitHash(index * 47 + 11) * 6.2831855;
    sizeBias = 0.55 + unitHash(index * 31 + 9) * 0.45;
    accent = unitHash(index * 17 + 3) > 0.9;
    presence = 0;
    speedSq = 0;
    anchored = false;
    visible = false;
  }

  void place(float x, float y) {
    home.set(x, y);
    if (!anchored) {
      position.set(x, y);
      velocity.set(0, 0);
      acceleration.set(0, 0);
      speedSq = 0;
      anchored = true;
    }
  }

  void setAppearance(int nextColor, float nextSize, float nextAlpha) {
    fillColor = nextColor;
    size = nextSize;
    alpha = nextAlpha;
  }

  void hide() {
    visible = false;
    presence = 0;
  }

  void approachPresence(float target, float blend) {
    if (blend < 0) blend = 0;
    if (blend > 1) blend = 1;
    presence += (target - presence) * blend;
    if (presence < 0) presence = 0;
    if (presence > 1) presence = 1;
  }

  void stepPhysics(float step, float damp, float ax, float ay, float maxSpeed, float minX, float minY, float maxX, float maxY) {
    acceleration.x = ax;
    acceleration.y = ay;
    float vx = (velocity.x + ax * step) * damp;
    float vy = (velocity.y + ay * step) * damp;
    float maxSq = maxSpeed * maxSpeed;
    float sp = vx * vx + vy * vy;
    if (sp > maxSq && sp > 0) {
      float scale = maxSpeed / (float) Math.sqrt(sp);
      vx *= scale;
      vy *= scale;
      sp = maxSq;
    }
    float px = position.x + vx * step;
    float py = position.y + vy * step;
    if (px < minX) {
      px = minX;
      if (vx < 0) vx = 0;
    } else if (px > maxX) {
      px = maxX;
      if (vx > 0) vx = 0;
    }
    if (py < minY) {
      py = minY;
      if (vy < 0) vy = 0;
    } else if (py > maxY) {
      py = maxY;
      if (vy > 0) vy = 0;
    }
    if (px != px || py != py || vx != vx || vy != vy) {
      px = home.x;
      py = home.y;
      vx = 0;
      vy = 0;
      sp = 0;
    }
    velocity.x = vx;
    velocity.y = vy;
    speedSq = vx * vx + vy * vy;
    position.x = px;
    position.y = py;
  }

  void draw(PApplet app, float seconds, float jitterSpan) {
    float kick = speedSq * 0.0016f;
    if (kick > 0.22f) kick = 0.22f;
    float shown = alpha * presence * (1f + kick);
    if (shown > 255) shown = 255;
    if (!visible || shown <= 1 || size <= 0) return;
    float drift = seconds * ParticleSystem.FLOAT_SPEED;
    float ox = jitterX * jitterSpan + (float) Math.sin(drift + phase) * ParticleSystem.FLOAT_AMPLITUDE;
    float oy = jitterY * jitterSpan + (float) Math.cos(drift * 0.8 + phase) * ParticleSystem.FLOAT_AMPLITUDE;
    app.fill(fillColor, shown);
    app.circle(position.x + ox, position.y + oy, size);
  }

  float unitHash(int n) {
    int value = n * 1103515245 + 12345;
    value ^= value >>> 16;
    return (value & 0x7fffffff) / 2147483647f;
  }
}
