// NeonEffects
//
// 담당:
// 입자가 흩어질 때 청록색과 보라색 네온 발광을 만든다.
// 입자의 물리에는 손대지 않는다. ParticleSystem을 읽어 빠르게 움직이는 입자 뒤에 빛 번짐을 그린다.
//
// 그리는 것:
//   빠르게 움직이는 입자마다 넓고 흐린 원(번짐)과 그보다 작은 밝은 원을 겹친다.
//   느린 쪽은 청록, 빠를수록 보라로 바뀐다. 움직임 감지로 보라색이 든 입자(motionTint)는 처음부터 보라 쪽이다.
//   움직이는 방향 뒤쪽으로 짧은 꼬리를 그어 속도감을 준다.
//
// 블렌드 모드를 바꾸지 않고 반투명 원을 겹쳐 그린다. 기본 렌더러(JAVA2D)에서 같은 모습이 나오게 하기 위해서다.

class NeonEffects {
  static final float MIN_SPEED = 2.5f;           // 이보다 느린 입자는 빛나지 않는다 (px/프레임)
  static final float FULL_SPEED = 12f;           // 이 속도에서 가장 밝다
  static final float HALO_SCALE = 3.4f;          // 번짐 지름 = 입자 크기 × 이 값
  static final float HALO_ALPHA = 46f;
  static final float CORE_SCALE = 1.6f;
  static final float CORE_ALPHA = 90f;
  static final float TAIL_LENGTH = 2.2f;         // 꼬리 길이 = 속도(px/프레임) × 이 값
  static final float TAIL_ALPHA = 70f;
  static final int MAX_GLOWS = 4000;             // 한 프레임에 빛낼 최대 입자 수 (느려지는 것을 막는다)

  static final int INK_SLOW = 0xFF38E8D5;
  static final int INK_FAST = 0xFFA78BFA;

  PApplet app;
  boolean enabled = true;
  int glowing = 0;                               // 지난 프레임에 빛난 입자 수 (디버그용)

  NeonEffects(PApplet app) {
    this.app = app;
  }

  // particles.draw() 전에 호출하면 번짐이 입자 뒤에 깔린다.
  void draw(ParticleSystem particles) {
    glowing = 0;
    if (!enabled || particles == null) return;
    float min2 = MIN_SPEED * MIN_SPEED;
    float span = particles.jitterSpan;
    app.pushStyle();
    app.strokeCap(PApplet.ROUND);
    for (int i = 0; i < particles.count && glowing < MAX_GLOWS; i++) {
      Particle p = particles.particles[i];
      if (!p.visible || p.speedSq < min2 || p.activation < 0.05f) continue;
      float speed = (float) Math.sqrt(p.speedSq);
      float t = (speed - MIN_SPEED) / (FULL_SPEED - MIN_SPEED);
      if (t > 1) t = 1;
      float hue = Math.max(t, p.motionTint);
      int ink = app.lerpColor(INK_SLOW, INK_FAST, hue);
      float strength = t * p.activation;
      float x = p.position.x + p.jitterX * span * p.activation;
      float y = p.position.y + p.jitterY * span * p.activation;

      float tail = speed * TAIL_LENGTH;
      app.stroke(ink, TAIL_ALPHA * strength);
      app.strokeWeight(Math.max(1f, p.size * 0.8f));
      app.line(x, y, x - p.velocity.x / speed * tail, y - p.velocity.y / speed * tail);

      app.noStroke();
      app.fill(ink, HALO_ALPHA * strength);
      app.circle(x, y, p.size * HALO_SCALE * (0.7f + 0.3f * t));
      app.fill(ink, CORE_ALPHA * strength);
      app.circle(x, y, p.size * CORE_SCALE);
      glowing++;
    }
    app.popStyle();
  }
}
