// CameraManager
//
// 카메라 목록 검색, 연결, 전환, 프레임 수신, 상태와 오류, 종료를 담당한다.
// Particle, MotionDetector, EchoSystem, NeonEffects는 호출하지 않는다.
//
// 프레임은 Capture 객체 하나를 그대로 돌려준다. 다른 모듈은 read(), start(), stop()을
// 호출하지 않는다. 표시용 좌우 반전은 픽셀 버퍼를 바꾸지 않고, 그릴 때만 적용한다.
// pixelColor()의 좌표는 원본 프레임 기준이다.

import java.util.ArrayList;
import processing.video.*;

class CameraManager {
  static final int FIT = 0;
  static final int FILL = 1;

  static final int STATE_SEARCHING = 0;
  static final int STATE_WAITING = 1;
  static final int STATE_LIVE = 2;
  static final int STATE_NO_DEVICE = 3;
  static final int STATE_FAILED = 4;
  static final int STATE_NO_FRAMES = 5;
  static final int STATE_INTERRUPTED = 6;

  static final int TARGET_WIDTH = 640;
  static final int TARGET_HEIGHT = 480;
  static final float TARGET_FPS = 30;
  static final int FIRST_FRAME_MS = 4000;
  static final int STALL_MS = 2000;

  static final int COLOR_TITLE = 0xFFF4FBFF;
  static final int COLOR_ACCENT = 0xFF38E8D5;
  static final int COLOR_SECONDARY = 0xFFA78BFA;
  static final int COLOR_BAR = 0xCC080D18;

  PApplet app;
  Capture capture;
  CameraDevice[] devices = new CameraDevice[0];
  int activeIndex = -1;
  int state = STATE_SEARCHING;
  int viewMode = FIT;
  boolean mirror = true;
  boolean showHelp = false;
  boolean registered = false;
  boolean hadFrame = false;
  boolean newFrame = false;
  boolean pixelsPrepared = false;

  int openedAt = 0;
  int lastFrameAt = 0;
  int fpsWindowStart = 0;
  int fpsWindowCount = 0;
  float measuredFps = 0;

  float placedX = 0;
  float placedY = 0;
  float placedW = 0;
  float placedH = 0;

  String errorLine = "";
  String statusNote = "";

  PFont titleFont;
  PFont subtitleFont;
  PFont bodyFont;

  String[] builtinHints = {
    "built-in", "builtin", "built in", "integrated", "internal", "facetime", "isight"
  };
  String[] virtualHints = {
    "virtual", "obs", "manycam", "snap camera", "camo", "epoccam",
    "ndi", "mmhmm", "continuity"
  };

  CameraManager(PApplet app) {
    this.app = app;
  }

  void begin() {
    if (!registered) {
      app.registerMethod("dispose", this);
      registered = true;
    }
    if (titleFont == null) {
      titleFont = app.createFont("SansSerif", 48);
      subtitleFont = app.createFont("SansSerif", 20);
      bodyFont = app.createFont("Monospaced", 14);
    }
    scanAndConnect();
  }

  public void dispose() {
    releaseCapture();
  }

  void update() {
    newFrame = false;
    if (capture == null) return;

    try {
      if (capture.available()) {
        capture.read();
        if (capture.width > 0 && capture.height > 0) {
          hadFrame = true;
          newFrame = true;
          lastFrameAt = app.millis();
          noteArrival();
          preparePixels();
          if (state == STATE_WAITING || state == STATE_NO_FRAMES || state == STATE_INTERRUPTED || state == STATE_LIVE) {
            state = STATE_LIVE;
            errorLine = "";
          }
        }
      }
    } catch (Throwable problem) {
      PApplet.println("ECHOES frame read failed: " + describe(problem));
      errorLine = "The frame could not be read.";
      state = STATE_FAILED;
      releaseCapture();
      return;
    }

    if (!hadFrame && state == STATE_WAITING && app.millis() - openedAt > FIRST_FRAME_MS) {
      state = STATE_NO_FRAMES;
      errorLine = "No frames received yet.";
    } else if (hadFrame && state == STATE_LIVE && app.millis() - lastFrameAt > STALL_MS) {
      state = STATE_INTERRUPTED;
    }
  }

  void drawView() {
    if ((state == STATE_LIVE || state == STATE_INTERRUPTED) && isReady()) {
      drawFrame();
      drawLiveChrome();
      return;
    }
    drawMessage();
  }

  void handleKey(char typed) {
    char command = Character.toLowerCase(typed);
    if (command == 'c') {
      selectNext();
    } else if (command == 'r') {
      statusNote = "";
      scanAndConnect();
    } else if (command == 'm') {
      mirror = !mirror;
      statusNote = mirror ? "Mirror on" : "Mirror off";
    } else if (command == 'h') {
      showHelp = !showHelp;
    }
  }

  public PImage frame() {
    if (!isReady()) return null;
    return capture;
  }

  public int frameWidth() {
    if (!isReady()) return 0;
    return capture.width;
  }

  public int frameHeight() {
    if (!isReady()) return 0;
    return capture.height;
  }

  public boolean hasNewFrame() {
    return newFrame;
  }

  public boolean isReady() {
    return hadFrame && capture != null && capture.width > 0 && capture.height > 0;
  }

  public boolean pixelsReady() {
    return pixelsPrepared && isReady() && capture.pixels != null;
  }

  public boolean pixelInRange(int x, int y) {
    return pixelsReady() && x >= 0 && y >= 0 && x < capture.width && y < capture.height;
  }

  public int pixelColor(int x, int y) {
    if (!pixelInRange(x, y)) return 0;
    int index = y * capture.width + x;
    if (index < 0 || index >= capture.pixels.length) return 0;
    return capture.pixels[index];
  }

  public boolean isConnected() {
    return capture != null && (state == STATE_WAITING || state == STATE_LIVE || state == STATE_NO_FRAMES || state == STATE_INTERRUPTED);
  }

  public String connectionState() {
    if (state == STATE_SEARCHING) return "searching";
    if (state == STATE_WAITING) return "waiting";
    if (state == STATE_LIVE) return "live";
    if (state == STATE_NO_DEVICE) return "no-device";
    if (state == STATE_FAILED) return "failed";
    if (state == STATE_NO_FRAMES) return "no-frames";
    if (state == STATE_INTERRUPTED) return "interrupted";
    return "unknown";
  }

  public boolean mirrorEnabled() {
    return mirror;
  }

  public float frameToScreenX(float pixelX) {
    if (!isReady()) return -1;
    layout(capture.width, capture.height);
    if (placedW == 0) return -1;
    float nx = pixelX / (float) capture.width;
    if (mirror) return placedX + placedW * (1 - nx);
    return placedX + nx * placedW;
  }

  public float frameToScreenY(float pixelY) {
    if (!isReady()) return -1;
    layout(capture.width, capture.height);
    if (placedH == 0) return -1;
    float ny = pixelY / (float) capture.height;
    return placedY + ny * placedH;
  }

  public float screenToFrameX(float screenX) {
    if (!isReady()) return -1;
    layout(capture.width, capture.height);
    if (placedW == 0) return -1;
    float nx = mirror
      ? (placedX + placedW - screenX) / placedW
      : (screenX - placedX) / placedW;
    return nx * capture.width;
  }

  public float screenToFrameY(float screenY) {
    if (!isReady()) return -1;
    layout(capture.width, capture.height);
    if (placedH == 0) return -1;
    return ((screenY - placedY) / placedH) * capture.height;
  }

  void scanAndConnect() {
    state = STATE_SEARCHING;
    errorLine = "";
    activeIndex = -1;
    releaseCapture();

    String[] listed;
    try {
      listed = Capture.list();
    } catch (Throwable problem) {
      devices = new CameraDevice[0];
      state = STATE_FAILED;
      errorLine = "The camera list could not be read.";
      PApplet.println("ECHOES camera list failed: " + describe(problem));
      problem.printStackTrace();
      return;
    }

    if (listed == null) listed = new String[0];
    PApplet.println("ECHOES camera list: " + listed.length);
    for (int i = 0; i < listed.length; i++) {
      PApplet.println("  [" + i + "] " + listed[i]);
    }

    devices = buildDevices(listed);
    for (int i = 0; i < devices.length; i++) {
      CameraDevice device = devices[i];
      String mode = device.capsKnown ? "reported mode" : "default request";
      PApplet.println("ECHOES choice " + i + ": " + device.label
        + " | " + device.width + "x" + device.height + " @ " + (int) device.fps
        + " | " + mode);
    }

    if (devices.length == 0) {
      state = STATE_NO_DEVICE;
      errorLine = "No camera was found.";
      return;
    }

    int preferred = preferredIndex();
    PApplet.println("ECHOES prefer [" + preferred + "] " + devices[preferred].label);
    if (connectIndex(preferred)) return;

    for (int i = 0; i < devices.length; i++) {
      if (i == preferred) continue;
      if (connectIndex(i)) return;
    }
  }

  boolean connectIndex(int index) {
    if (index < 0 || index >= devices.length) return false;
    releaseCapture();
    activeIndex = index;
    CameraDevice device = devices[index];
    Capture opened = null;

    try {
      opened = openCapture(device);
      opened.start();
      capture = opened;
    } catch (Throwable problem) {
      if (opened != null) {
        capture = opened;
        releaseCapture();
      }
      state = STATE_FAILED;
      errorLine = "The camera could not be opened.";
      PApplet.println("ECHOES open error (" + device.label + "): " + describe(problem));
      problem.printStackTrace();
      return false;
    }

    openedAt = app.millis();
    lastFrameAt = openedAt;
    fpsWindowStart = 0;
    fpsWindowCount = 0;
    measuredFps = 0;
    state = STATE_WAITING;
    errorLine = "";
    PApplet.println("ECHOES opened: " + device.label
      + " " + device.width + "x" + device.height + " @ " + (int) device.fps);
    return true;
  }

  void selectNext() {
    if (devices.length == 0) {
      statusNote = "No camera list yet. Press R to search.";
      return;
    }
    if (devices.length == 1) {
      statusNote = "Only one camera is available.";
      if (state == STATE_FAILED || state == STATE_NO_FRAMES || state == STATE_NO_DEVICE) {
        connectIndex(0);
      }
      return;
    }

    int next = activeIndex + 1;
    if (next < 0 || next >= devices.length) next = 0;
    statusNote = "";
    connectIndex(next);
  }

  Capture openCapture(CameraDevice device) {
    if (device.fps < 1) device.fps = TARGET_FPS;
    RuntimeException last = null;

    try {
      return new Capture(app, device.width, device.height, device.openName, device.fps);
    } catch (RuntimeException problem) {
      last = problem;
      PApplet.println("ECHOES open failed: " + describe(problem));
    }

    if (!device.openName.equals(device.listName)) {
      try {
        return new Capture(app, device.width, device.height, device.listName, device.fps);
      } catch (RuntimeException problem) {
        last = problem;
        PApplet.println("ECHOES open failed: " + describe(problem));
      }
    }

    if (!device.capsKnown) {
      try {
        return new Capture(app, device.listName);
      } catch (RuntimeException problem) {
        last = problem;
        PApplet.println("ECHOES open failed: " + describe(problem));
      }
    }

    if (last == null) last = new RuntimeException("Could not open camera");
    throw last;
  }

  CameraDevice[] buildDevices(String[] listed) {
    ArrayList<CameraDevice> built = new ArrayList<CameraDevice>();
    for (int i = 0; i < listed.length; i++) {
      if (listed[i] == null) continue;
      String raw = listed[i].trim();
      if (raw.length() == 0 || alreadyListed(built, raw)) continue;

      CameraDevice device = new CameraDevice();
      device.listName = raw;
      device.label = extractLabel(raw);
      device.openName = device.label;
      applyMode(device);
      if (!device.embeddedMode) device.openName = device.listName;
      mergeOrAdd(built, device);
    }

    CameraDevice[] result = new CameraDevice[built.size()];
    built.toArray(result);
    return result;
  }

  boolean alreadyListed(ArrayList<CameraDevice> built, String raw) {
    for (int i = 0; i < built.size(); i++) {
      if (raw.equals(built.get(i).listName)) return true;
    }
    return false;
  }

  void mergeOrAdd(ArrayList<CameraDevice> built, CameraDevice candidate) {
    if (!candidate.embeddedMode) {
      built.add(candidate);
      return;
    }
    for (int i = 0; i < built.size(); i++) {
      CameraDevice existing = built.get(i);
      if (!existing.embeddedMode) continue;
      if (!existing.label.equalsIgnoreCase(candidate.label)) continue;
      if (scoreMode(candidate.width, candidate.height, candidate.fps)
          > scoreMode(existing.width, existing.height, existing.fps)) {
        built.set(i, candidate);
      }
      return;
    }
    built.add(candidate);
  }

  void applyMode(CameraDevice device) {
    int[] embedded = parseSizeFps(device.listName);
    if (embedded != null && (device.listName.toLowerCase().indexOf("size=") >= 0 || device.listName.toLowerCase().indexOf("fps=") >= 0)) {
      device.embeddedMode = true;
      device.capsKnown = true;
      device.width = embedded[0];
      device.height = embedded[1];
      device.fps = embedded[2] > 0 ? embedded[2] : TARGET_FPS;
      return;
    }

    String[] caps = new String[0];
    try {
      caps = Capture.getCapabilities(device.listName);
    } catch (Throwable problem) {
      PApplet.println("ECHOES capabilities unavailable for " + device.label + ": " + describe(problem));
    }
    if (caps == null) caps = new String[0];

    int shown = 0;
    for (int i = 0; i < caps.length && shown < 4; i++) {
      if (caps[i] == null) continue;
      PApplet.println("    " + caps[i]);
      shown++;
    }
    if (caps.length > shown) {
      PApplet.println("    ... " + (caps.length - shown) + " more");
    }

    int[] chosen = chooseMode(caps, true);
    if (chosen == null) chosen = chooseMode(caps, false);
    boolean found = chosen != null;
    int bestW = found ? chosen[0] : TARGET_WIDTH;
    int bestH = found ? chosen[1] : TARGET_HEIGHT;
    float bestFps = found && chosen[2] > 0 ? chosen[2] : TARGET_FPS;

    device.capsKnown = found;
    device.width = bestW;
    device.height = bestH;
    device.fps = bestFps;
  }

  int preferredIndex() {
    int best = 0;
    int bestScore = Integer.MIN_VALUE;
    for (int i = 0; i < devices.length; i++) {
      int score = preferenceScore(devices[i]);
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  int preferenceScore(CameraDevice device) {
    String name = device.label.toLowerCase();
    int score = 0;
    if (containsHint(name, virtualHints)) score -= 100;
    if (containsHint(name, builtinHints)) score += 50;
    if (device.capsKnown && device.width == TARGET_WIDTH && device.height == TARGET_HEIGHT) score += 20;
    return score;
  }

  boolean containsHint(String name, String[] hints) {
    for (int i = 0; i < hints.length; i++) {
      if (name.indexOf(hints[i]) >= 0) return true;
    }
    return false;
  }

  int[] chooseMode(String[] caps, boolean limitFps) {
    int bestScore = Integer.MIN_VALUE;
    int[] best = null;
    for (int i = 0; i < caps.length; i++) {
      int[] parsed = parseSizeFps(caps[i]);
      if (parsed == null) continue;
      if (limitFps && (parsed[2] <= 0 || parsed[2] > 120)) continue;
      int score = scoreMode(parsed[0], parsed[1], parsed[2]);
      if (score > bestScore) {
        bestScore = score;
        best = parsed;
      }
    }
    return best;
  }

  int scoreMode(int w, int h, float fps) {
    float usedFps = fps > 0 ? fps : TARGET_FPS;
    int score = 2000;
    score -= Math.abs(w - TARGET_WIDTH);
    score -= Math.abs(h - TARGET_HEIGHT);
    float aspect = w / (float) h;
    score -= Math.round(Math.abs(aspect - (4f / 3f)) * 300f);
    score -= Math.round(Math.abs(usedFps - TARGET_FPS) * 3f);
    if (w < 160 || h < 120) score -= 800;
    if (w * h > 1280 * 720) score -= 120;
    return score;
  }

  int[] parseSizeFps(String text) {
    if (text == null) return null;
    int width = -1;
    int height = -1;
    for (int i = 0; i < text.length(); i++) {
      if (!Character.isDigit(text.charAt(i))) continue;
      int widthEnd = i;
      while (widthEnd < text.length() && Character.isDigit(text.charAt(widthEnd))) widthEnd++;
      if (widthEnd >= text.length()) break;
      char mark = text.charAt(widthEnd);
      if (mark != 'x' && mark != 'X') continue;
      int heightStart = widthEnd + 1;
      if (heightStart >= text.length() || !Character.isDigit(text.charAt(heightStart))) continue;
      int heightEnd = heightStart;
      while (heightEnd < text.length() && Character.isDigit(text.charAt(heightEnd))) heightEnd++;
      int parsedWidth = Integer.parseInt(text.substring(i, widthEnd));
      int parsedHeight = Integer.parseInt(text.substring(heightStart, heightEnd));
      if (parsedWidth >= 16 && parsedHeight >= 16) {
        width = parsedWidth;
        height = parsedHeight;
        break;
      }
    }
    if (width < 16 || height < 16) return null;

    int fps = -1;
    String lower = text.toLowerCase();
    int fpsAt = lower.indexOf("fps");
    if (fpsAt >= 0) {
      int start = fpsAt + 3;
      while (start < text.length() && !Character.isDigit(text.charAt(start))) start++;
      int end = start;
      while (end < text.length() && (Character.isDigit(text.charAt(end)) || text.charAt(end) == '.')) end++;
      if (end > start) {
        try {
          fps = Math.round(Float.parseFloat(text.substring(start, end)));
        } catch (NumberFormatException ignored) {
          fps = -1;
        }
      }
    }
    return new int[] { width, height, fps };
  }

  String extractLabel(String raw) {
    String trimmed = raw.trim();
    String lower = trimmed.toLowerCase();
    int nameAt = lower.indexOf("name=");
    if (nameAt >= 0) {
      String rest = trimmed.substring(nameAt + 5).trim();
      int cut = rest.indexOf(',');
      if (cut < 0) cut = rest.toLowerCase().indexOf("size=");
      if (cut >= 0) rest = rest.substring(0, cut).trim();
      if (rest.length() > 0) return rest;
    }
    return trimmed;
  }

  void releaseCapture() {
    Capture current = capture;
    capture = null;
    hadFrame = false;
    newFrame = false;
    pixelsPrepared = false;
    if (current == null) return;

    try {
      if (current.pipeline != null && current.isCapturing()) current.stop();
    } catch (Throwable problem) {
      PApplet.println("ECHOES stop: " + describe(problem));
    }
    try {
      current.dispose();
    } catch (Throwable problem) {
      PApplet.println("ECHOES release: " + describe(problem));
    }
    try {
      current.pipeline = null;
    } catch (Throwable problem) {
      PApplet.println("ECHOES release: " + describe(problem));
    }
  }

  void preparePixels() {
    pixelsPrepared = false;
    if (capture == null || capture.width <= 0 || capture.height <= 0) return;
    try {
      capture.loadPixels();
    } catch (Throwable problem) {
      PApplet.println("ECHOES pixels: " + describe(problem));
      return;
    }
    int needed = capture.width * capture.height;
    if (capture.pixels != null && needed > 0 && capture.pixels.length >= needed) {
      pixelsPrepared = true;
    }
  }

  void noteArrival() {
    int now = app.millis();
    if (fpsWindowStart == 0) fpsWindowStart = now;
    fpsWindowCount++;
    int elapsed = now - fpsWindowStart;
    if (elapsed >= 1000) {
      measuredFps = fpsWindowCount * 1000f / elapsed;
      fpsWindowCount = 0;
      fpsWindowStart = now;
    }
  }

  void layout(int frameW, int frameH) {
    float viewW = app.width;
    float viewH = app.height;
    float frameAspect = frameW / (float) frameH;
    float viewAspect = viewW / (float) viewH;
    boolean wider = frameAspect > viewAspect;

    if (viewMode == FILL) {
      if (wider) {
        placedH = viewH;
        placedW = viewH * frameAspect;
      } else {
        placedW = viewW;
        placedH = viewW / frameAspect;
      }
    } else if (wider) {
      placedW = viewW;
      placedH = viewW / frameAspect;
    } else {
      placedH = viewH;
      placedW = viewH * frameAspect;
    }

    placedX = (viewW - placedW) / 2f;
    placedY = (viewH - placedH) / 2f;
  }

  void drawFrame() {
    layout(capture.width, capture.height);
    app.pushMatrix();
    app.imageMode(PApplet.CORNER);
    if (mirror) {
      app.translate(placedX + placedW, placedY);
      app.scale(-1, 1);
      app.image(capture, 0, 0, placedW, placedH);
    } else {
      app.image(capture, placedX, placedY, placedW, placedH);
    }
    app.popMatrix();

    app.rectMode(PApplet.CORNER);
    app.noFill();
    app.stroke(COLOR_ACCENT);
    app.strokeWeight(1);
    app.rect(placedX, placedY, placedW, placedH);
    app.noStroke();
  }

  void drawLiveChrome() {
    if (state == STATE_INTERRUPTED) {
      app.noStroke();
      app.fill(COLOR_BAR);
      app.rectMode(PApplet.CORNER);
      app.rect(0, 14, app.width, 28);
      textLine(bodyFont, COLOR_ACCENT, PApplet.CENTER, "SIGNAL INTERRUPTED", app.width / 2f, 28);
    }

    String status = activeLabel() + "  " + frameWidth() + "x" + frameHeight();
    if (statusNote.length() > 0) status += "  " + statusNote;
    float statusY = state == STATE_INTERRUPTED ? 52 : 28;
    app.textFont(bodyFont);
    float statusW = app.textWidth(status) + 28;
    app.noStroke();
    app.fill(COLOR_BAR);
    app.rectMode(PApplet.CORNER);
    app.rect(12, statusY - 14, statusW, 28);
    textLine(bodyFont, COLOR_ACCENT, PApplet.LEFT, status, 24, statusY);

    app.noStroke();
    app.fill(COLOR_BAR);
    app.rectMode(PApplet.CORNER);
    app.rect(0, app.height - 36, app.width, 36);
    textLine(bodyFont, COLOR_SECONDARY, PApplet.CENTER, shortcutLine(), app.width / 2f, app.height - 18);

    if (showHelp) drawHelp();
  }

  void drawHelp() {
    String sizeLine = "Request " + requestedSize();
    if (isReady()) sizeLine = "Frame " + frameWidth() + "x" + frameHeight();
    String viewLabel = viewMode == FILL ? "Fill" : "Fit";
    String[] lines = {
      "Render " + (int) app.frameRate + " fps",
      "Camera " + (measuredFps > 0 ? (int) measuredFps + " fps" : "--"),
      sizeLine,
      "Mirror " + (mirror ? "on" : "off"),
      viewLabel + "   " + (activeIndex + 1) + "/" + devices.length
    };

    float panelW = 280;
    float panelH = 28 + lines.length * 20;
    float panelX = 16;
    float panelY = app.height - 36 - 12 - panelH;
    app.noStroke();
    app.fill(COLOR_BAR);
    app.rect(panelX, panelY, panelW, panelH);
    for (int i = 0; i < lines.length; i++) {
      textLine(bodyFont, COLOR_ACCENT, PApplet.LEFT, lines[i], panelX + 16, panelY + 22 + i * 20);
    }
  }

  void drawMessage() {
    String heading = "INITIALIZING CAMERA";
    String[] lines = messageLines();
    if (state == STATE_NO_DEVICE || state == STATE_FAILED) heading = "CAMERA UNAVAILABLE";

    textLine(titleFont, COLOR_TITLE, PApplet.CENTER, "ECHOES OF MEMORY", app.width / 2f, app.height / 2f - 108);
    textLine(subtitleFont, COLOR_ACCENT, PApplet.CENTER, heading, app.width / 2f, app.height / 2f - 48);
    for (int i = 0; i < lines.length; i++) {
      textLine(bodyFont, COLOR_SECONDARY, PApplet.CENTER, lines[i], app.width / 2f, app.height / 2f + i * 26);
    }
    textLine(bodyFont, COLOR_ACCENT, PApplet.CENTER, shortcutLine(), app.width / 2f, app.height - 28);
  }

  String[] messageLines() {
    String selected = activeIndex >= 0 ? activeLabel() + "  " + requestedSize() : "Searching for cameras";
    if (statusNote.length() > 0) selected = selected + "  " + statusNote;

    if (state == STATE_NO_DEVICE) {
      return new String[] {
        "No camera was found.",
        "It may be disconnected, or Processing may not have permission.",
        "macOS: Privacy & Security > Camera",
        "Windows: allow desktop apps to use the camera, then press R."
      };
    }
    if (state == STATE_FAILED) {
      return new String[] {
        errorLine.length() > 0 ? errorLine : "The camera could not be opened.",
        "It may be in use, permission may be denied, or the mode may be unsupported.",
        "Press C to try another camera.",
        "Press R to search again."
      };
    }
    if (state == STATE_NO_FRAMES) {
      return new String[] {
        "No frames received yet.",
        selected,
        "The camera may be busy, or still starting.",
        "Press R to search again. Press C to try another camera."
      };
    }
    if (state == STATE_SEARCHING) {
      return new String[] {
        "Searching for cameras.",
        "The list is read once, not every frame.",
        "",
        ""
      };
    }
    return new String[] {
      "Opening the camera.",
      selected,
      "Waiting for the first frame.",
      ""
    };
  }

  String shortcutLine() {
    return "C: Camera    R: Retry    M: Mirror    H: Help";
  }

  String activeLabel() {
    if (activeIndex < 0 || activeIndex >= devices.length) return "No camera";
    return devices[activeIndex].label;
  }

  String requestedSize() {
    if (activeIndex < 0 || activeIndex >= devices.length) return "";
    CameraDevice device = devices[activeIndex];
    String source = device.capsKnown ? "reported" : "requested";
    return device.width + "x" + device.height + " @ " + (int) device.fps + " " + source;
  }

  void textLine(PFont font, int ink, int align, String message, float x, float y) {
    if (message == null || message.length() == 0) return;
    app.textFont(font);
    app.fill(ink);
    app.textAlign(align, PApplet.CENTER);
    app.text(message, x, y);
  }

  String describe(Throwable problem) {
    String message = problem.getMessage();
    if (message == null || message.length() == 0) return problem.getClass().getSimpleName();
    return problem.getClass().getSimpleName() + ": " + message;
  }
}

class CameraDevice {
  String listName = "";
  String label = "";
  String openName = "";
  int width = 640;
  int height = 480;
  float fps = 30;
  boolean capsKnown = false;
  boolean embeddedMode = false;
}
