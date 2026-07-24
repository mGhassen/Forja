// Faithful Flutter port of franky-adl/fractal-glass-gradients fragment.glsl + noise.glsl
// https://github.com/franky-adl/fractal-glass-gradients
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uPixelRatio;
uniform float uTime;
uniform float uWarpStrength;
uniform float uNoiseScaleX;
uniform float uNoiseScaleY;
uniform float uWarpSpeed;
uniform float uGrainStrength;
uniform float uFluteWidth;
uniform float uFluteStrength;
uniform float uToneMapExposure;
uniform float uAlgo; // 0 = Algo1 blobs, 1 = Algo2 ellipses
uniform vec3 uC1;
uniform vec3 uC2;
uniform vec3 uC3;
uniform vec3 uC4;
uniform vec3 uC5;
uniform vec3 uC6;
uniform vec3 uC7;
uniform sampler2D uGrain;

out vec4 fragColor;

// ── simplex noise (ashima / stegu) — same as repo snoise2d.glsl ──────────────

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289(((x * 34.0) + 10.0) * x);
}

float snoise(vec2 v) {
  const vec4 C = vec4(
      0.211324865405187,
      0.366025403784439,
      -0.577350269189626,
      0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

/// Repo noise.glsl — samples like the 256² noise FBO at screen UV.
vec2 warpNoise(vec2 vUv) {
  float t = uTime * uWarpSpeed;
  float nx = snoise(vUv * vec2(uNoiseScaleX, uNoiseScaleY) + t * 0.5);
  float ny = snoise(vUv * vec2(uNoiseScaleX, uNoiseScaleY) * 0.93 - t * 0.3);
  return vec2(nx, ny);
}

float safeAtanh(float x) {
  x = clamp(x, -0.999999, 0.999999);
  return 0.5 * log((1.0 + x) / (1.0 - x));
}

vec2 rotate2d(vec2 v, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat2(c, -s, s, c) * v;
}

/// Repo GaussianBlobs (Algo1) — warp from screen vUv, color from flutedUv.
vec3 GaussianBlobs(vec2 flutedUv, vec2 vUv) {
  float t = uTime * 0.6 + 3.5;
  vec2 p1 = vec2(-0.28 + sin(t * 0.7 + 0.5) * 0.15, 0.06 + cos(t * 0.5) * 0.12);
  vec2 p2 = vec2(-0.06 + sin(t * 0.4 + 1.2) * 0.18, 0.16 + cos(t * 0.6) * 0.15);
  vec2 p3 = vec2(0.07 + sin(t * 0.5 + 3.4) * 0.2, 0.00 + cos(t * 0.4) * 0.14);
  vec2 p4 = vec2(0.22 + sin(t * 0.3 + 2.3) * 0.24, -0.10 + cos(t * 0.7) * 0.14);
  vec2 p5 = vec2(0.30 + sin(t * 0.6 + 1.1) * 0.18, 0.06 + cos(t * 0.4) * 0.13);
  // Extra Forja stops (green / amber) — black pads contribute nothing.
  vec2 p6 = vec2(-0.18 + sin(t * 0.55 + 2.1) * 0.16, -0.14 + cos(t * 0.45) * 0.12);
  vec2 p7 = vec2(0.14 + sin(t * 0.65 + 0.9) * 0.17, 0.20 + cos(t * 0.55 + 1.4) * 0.11);

  vec2 n = warpNoise(vUv);
  vec2 warpedUv = flutedUv + n * uWarpStrength;
  float d1 = dot(warpedUv - p1, warpedUv - p1);
  float d2 = dot(warpedUv - p2, warpedUv - p2);
  float d3 = dot(warpedUv - p3, warpedUv - p3);
  float d4 = dot(warpedUv - p4, warpedUv - p4);
  float d5 = dot(warpedUv - p5, warpedUv - p5);
  float d6 = dot(warpedUv - p6, warpedUv - p6);
  float d7 = dot(warpedUv - p7, warpedUv - p7);

  vec3 color = vec3(0.005, 0.010, 0.055);
  color += uC1 * exp(-d1 * 12.0) * 1.4;
  color += uC2 * exp(-d2 * 20.0) * 2.0;
  color += uC3 * exp(-d3 * 9.0) * 1.6;
  color += uC4 * exp(-d4 * 15.0) * 1.3;
  color += uC5 * exp(-d5 * 25.0) * 0.8;
  color += uC6 * exp(-d6 * 14.0) * 1.5;
  color += uC7 * exp(-d7 * 16.0) * 1.4;
  return color;
}

/// Repo GaussianEllipses (Algo2).
vec3 GaussianEllipses(vec2 flutedUv, vec2 vUv) {
  float t = uTime * 0.6 + 3.5;
  vec2 p1 = vec2(-0.32 + sin(t * 0.5 + 1.8) * 0.20, -0.12 + cos(t * 0.8 + 0.3) * 0.16);
  vec2 p2 = vec2(0.10 + sin(t * 0.6 + 2.5) * 0.14, 0.24 + cos(t * 0.3 + 1.7) * 0.18);
  vec2 p3 = vec2(-0.15 + sin(t * 0.9 + 0.7) * 0.22, -0.08 + cos(t * 0.5 + 2.9) * 0.11);
  vec2 p4 = vec2(0.28 + sin(t * 0.4 + 3.1) * 0.17, 0.18 + cos(t * 0.6 + 0.9) * 0.20);
  vec2 p5 = vec2(-0.05 + sin(t * 0.7 + 4.2) * 0.13, -0.20 + cos(t * 0.9 + 1.5) * 0.15);
  vec2 p6 = vec2(-0.22 + sin(t * 0.55 + 2.1) * 0.15, 0.10 + cos(t * 0.45) * 0.12);
  vec2 p7 = vec2(0.18 + sin(t * 0.65 + 0.9) * 0.16, -0.16 + cos(t * 0.55 + 1.4) * 0.13);

  vec2 n = warpNoise(vUv);
  vec2 warpedUv = flutedUv + vec2(n.x * uWarpStrength, n.y * uWarpStrength * 0.2);
  vec2 r1 = rotate2d(warpedUv - p1, 0.3);
  vec2 r2 = rotate2d(warpedUv - p2, -1.1);
  vec2 r3 = rotate2d(warpedUv - p3, 0.8);
  vec2 r4 = rotate2d(warpedUv - p4, -0.5);
  vec2 r5 = rotate2d(warpedUv - p5, 1.4);
  vec2 r6 = rotate2d(warpedUv - p6, -0.7);
  vec2 r7 = rotate2d(warpedUv - p7, 1.0);

  float e1 = r1.x * r1.x * 8.0 + r1.y * r1.y * 1.0;
  float e2 = r2.x * r2.x * 25.0 + r2.y * r2.y * 12.0;
  float e3 = r3.x * r3.x * 6.0 + r3.y * r3.y * 14.0;
  float e4 = r4.x * r4.x * 20.0 + r4.y * r4.y * 8.0;
  float e5 = r5.x * r5.x * 30.0 + r5.y * r5.y * 15.0;
  float e6 = r6.x * r6.x * 12.0 + r6.y * r6.y * 7.0;
  float e7 = r7.x * r7.x * 18.0 + r7.y * r7.y * 10.0;

  vec3 color = vec3(0.005, 0.010, 0.055);
  color += uC1 * exp(-e1) * 1.4;
  color += uC2 * exp(-e2) * 2.0;
  color += uC3 * exp(-e3) * 1.6;
  color += uC4 * exp(-e4) * 1.3;
  color += uC5 * exp(-e5) * 0.8;
  color += uC6 * exp(-e6) * 1.5;
  color += uC7 * exp(-e7) * 1.4;
  return color;
}

void main() {
  // FlutterFragCoord is local paint coords (logical px), NOT gl_FragCoord / physical.
  // Do not divide by uPixelRatio — that zooms into the center and feels "cropped".
  vec2 logicalXY = FlutterFragCoord().xy;
  vec2 mappedCoords = logicalXY - uResolution * 0.5;
  vec2 vUv = logicalXY / max(uResolution, vec2(1.0));

  // Fluted / reeded refraction (repo formula; fluteWidth is logical px).
  vec2 scaledUv = mappedCoords / vec2(max(uFluteWidth, 1.0), max(uFluteWidth, 1.0));
  vec2 fractUv = vec2(fract(scaledUv.x), scaledUv.y);
  float flutedX = uFluteStrength * (fractUv.x - 0.5);
  float flutedY = -uFluteStrength * safeAtanh(pow(clamp(fractUv.x, 0.0, 1.0), 6.0));
  vec2 flutedCoords = vec2(mappedCoords.x + flutedX, mappedCoords.y + flutedY);

  // Repo /1000 assumes ~1920 CSS width. Scale so smaller TV panels keep the same framing.
  float unit = max(uResolution.x, 1.0) * (1000.0 / 1920.0);
  vec2 flutedUv = flutedCoords / max(unit, 1.0);

  // Grain UV (repo vUvA) — tile so clamp samplers still look dense.
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 vUvA = vUv;
  if (aspect < 1.0 || aspect > 2.3) {
    vUvA = logicalXY / vec2(960.0, 630.0);
  }

  vec3 color = (uAlgo < 0.5)
      ? GaussianBlobs(flutedUv, vUv)
      : GaussianEllipses(flutedUv, vUv);

  color = 1.0 - exp(-color * uToneMapExposure);

  float grain = texture(uGrain, fract(vUvA)).r * 2.0 - 1.0;
  color += grain * uGrainStrength * max(color.r, max(color.g, color.b));
  color = clamp(color, 0.0, 1.0);

  fragColor = vec4(color, 1.0);
}
