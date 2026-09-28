import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// octopus_english_brand/reference/octopus_scene.js dosyasının ('splash' modu)
// birebir Flutter portu. Sabitler, rastgele sayı sırası ve çizim sırası
// referansla aynı tutulmalıdır.

const double _tau = math.pi * 2;
const double _tCurl = 1.9;
const double _r = 100;
const int _n = 112;

double _clamp(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _smooth(double v) {
  v = _clamp(v);
  return v * v * (3 - 2 * v);
}

// JS: 'hsla(' + h.toFixed(1) + ',' + s + '%,' + l + '%,' + a + ')'
Color _col(double h, double s, double l, [double a = 1]) {
  final hue = double.parse(h.toStringAsFixed(1)) % 360;
  return HSLColor.fromAHSL(a, hue, s / 100, l / 100).toColor();
}

class _Spec {
  const _Spec(this.dr, this.arc, this.w, this.sp, this.lc, this.tr);
  final double dr, arc, w, sp, lc, tr;
}

const List<_Spec> _specs = [
  _Spec(14, 262, 28, 0.18, 60, 5.5),
  _Spec(4, 228, 24, 0.4, 52, 5),
  _Spec(-6, 196, 20, 0.64, 44, 4.5),
  _Spec(-15, 150, 16, 0.9, 36, 4),
];

// [width fraction, saturation, lightness, alpha, offset toward light]
const List<List<double>> _bands = [
  [0.86, 56, 22, 1, 0],
  [0.68, 58, 31, 1, 0.05],
  [0.5, 60, 41, 1, 0.12],
  [0.33, 62, 53, 1, 0.19],
  [0.17, 70, 70, 0.75, 0.25],
  [0.06, 80, 88, 0.6, 0.28],
];

double _widthAt(double w0, double s) {
  final f1 = 1 - 0.5 * math.pow(s, 1.3);
  final f2 = s < 0.8 ? 1 : 1 - 0.9 * math.pow((s - 0.8) / 0.2, 1.2);
  var w = w0 * f1 * f2 + 0.8;
  if (s < 0.06) w *= 1 + (0.06 - s) * 3;
  return w;
}

class _Sucker {
  const _Sucker(this.l, this.off, this.rr);
  final double l, off, rr;
}

class _Spot {
  const _Spot(this.l, this.u, this.r, this.light);
  final double l, u, r;
  final bool light;
}

class _MantleSpot {
  const _MantleSpot(this.x, this.y, this.r, this.light);
  final double x, y, r;
  final bool light;
}

class _Particle {
  const _Particle(this.x, this.y, this.z, this.ph);
  final double x, y, z, ph;
}

class _Arm {
  _Arm({
    required this.mir,
    required this.j,
    required this.ri,
    required this.la,
    required this.lc,
    required this.l,
    required this.w0,
    required this.sp,
    required this.x0,
    required this.y0,
    required this.ph,
    required this.delay,
    required this.hue,
  });

  final bool mir;
  final int j;
  final double ri, la, lc, l, w0, sp, x0, y0, ph, delay, hue;
  final Float32List thC = Float32List(_n);
  final Float32List pts = Float32List((_n + 1) * 2);
  final Float32List ths = Float32List(_n);
  final Float32List nx = Float32List(_n + 1);
  final Float32List ny = Float32List(_n + 1);
  final Float32List ws = Float32List(_n + 1);
  final List<_Sucker> suck = [];
  final List<_Spot> spots = [];

  // Zamandan bağımsız renkler (her karede yeniden hesaplanmasın diye).
  late final Color bodyColor = _col(hue - 10, 55, 11);
  late final List<List<Color>> bandColors = [
    for (final b in _bands)
      [
        for (var k = 0; k < _n; k += 4)
          _col(hue - 50 * (math.min(_n, k + 2) / _n), b[1], b[2], b[3]),
      ],
  ];
}

/// Ahtapot sahnesinin durumu. Bir kez oluşturulur, her karede [paint] ile çizilir.
class OctopusScene {
  OctopusScene() {
    var seed = 11;
    double rnd() {
      seed = (seed * 16807) % 2147483647;
      return (seed - 1) / 2147483646;
    }

    for (var side = 0; side < 2; side++) {
      for (var j = 0; j < 4; j++) {
        final sp = _specs[j];
        final ri = _r + sp.dr + (side == 1 ? 2.5 : 0);
        final arc = (sp.arc + (side == 1 ? rnd() * 16 - 8 : 0)) * math.pi / 180;
        final la = ri * arc, l = la + sp.lc;
        final spd = sp.sp + (side == 1 ? rnd() * 0.08 : 0);
        final ph = rnd() * _tau;
        final delay = j * 0.07 + side * 0.06 + rnd() * 0.05;
        final hue = 262 + rnd() * 8 - 4;
        final a = _Arm(
          mir: side == 1,
          j: j,
          ri: ri,
          la: la,
          lc: sp.lc,
          l: l,
          w0: sp.w,
          sp: spd,
          x0: 3 + j * 3.5,
          y0: -ri,
          ph: ph,
          delay: delay,
          hue: hue,
        );
        final dl = l / _n;
        var th = 0.0;
        for (var k = 0; k < _n; k++) {
          final ll = (k + 0.5) * dl;
          var kap = 1 / ri;
          if (ll > la) {
            kap += (1 / sp.tr - 1 / ri) * math.pow((ll - la) / sp.lc, 1.4);
          }
          a.thC[k] = th + kap * dl * 0.5;
          th += kap * dl;
        }
        var ll = 0.05 * l;
        var n = 0;
        while (ll < 0.95 * l) {
          final sN = ll / l, w = _widthAt(sp.w, sN), two = sN < 0.5;
          final rr = two ? 0.15 : 0.19;
          a.suck.add(_Sucker(ll, two ? (n % 2 == 1 ? 0.17 : 0.37) : 0.29, rr));
          ll += math.max((two ? 1.3 : 2.3) * rr * w, 1.4);
          n++;
        }
        for (var q = 0; q < 50; q++) {
          final sl = (0.03 + rnd() * 0.85) * l;
          final u = -0.44 + rnd() * 0.5;
          final r = 0.04 + rnd() * 0.07;
          final light = rnd() < 0.35;
          a.spots.add(_Spot(sl, u, r, light));
        }
        // widthAt yalnızca k'ye bağlı; JS'de her pose'da aynı değer yazılıyor.
        for (var k = 0; k <= _n; k++) {
          a.ws[k] = _widthAt(a.w0, k / _n);
        }
        _arms.add(a);
      }
    }
    for (var m = 0; m < 60; m++) {
      final x = rnd() * 90 - 45;
      final y = -212 + rnd() * 112;
      final r = 0.8 + rnd() * 3;
      final light = rnd() < 0.3;
      _mspots.add(_MantleSpot(x, y, r, light));
    }
    for (var p = 0; p < 70; p++) {
      final x = rnd();
      final y = rnd();
      final z = 0.25 + rnd() * 0.75;
      final ph = rnd() * _tau;
      _parts.add(_Particle(x, y, z, ph));
    }
  }

  final List<_Arm> _arms = [];
  final List<_MantleSpot> _mspots = [];
  final List<_Particle> _parts = [];

  /// Sahnenin ölçek birimi (JS: unit = min(W * 0.27, H * 0.13) / 100).
  static double unitFor(Size size) =>
      math.min(size.width * 0.27, size.height * 0.13) / 100;

  /// Referans sahnede (390x844) birim.
  static final double referenceUnit = unitFor(const Size(390, 844));

  // Geçerli karenin ahtapot dönüşümü; gölge ofsetlerini yerel koordinata
  // çevirmek için kullanılır (canvas shadow'ları dönüşümden etkilenmez).
  double _k = 1, _rot = 0;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static const Color _shadowArm = Color.fromRGBO(3, 4, 22, 0.6);
  static const Color _shadowEye = Color.fromRGBO(3, 4, 22, 0.55);
  static final Color _spotLight = _col(232, 85, 82, 0.35);
  static final Color _spotDark = _col(256, 60, 10, 0.32);
  static final Color _suckRim = _col(272, 45, 16, 0.9);
  static final Color _suckBody = _col(290, 48, 78);
  static final Color _suckInner = _col(288, 36, 56);
  static final Color _suckCore = _col(280, 40, 30);
  static const Color _suckGlint = Color.fromRGBO(255, 245, 255, 0.7);
  static final Color _mspotLight = _col(240, 85, 84, 0.3);
  static final Color _mspotDark = _col(258, 60, 12, 0.3);
  static final Color _mantleLine = _col(258, 55, 16, 0.45);
  static final Color _lidTop = _col(270, 50, 40);
  static final Color _lidEdge = _col(260, 60, 11);
  static final Color _irisRing = _col(262, 60, 9);
  static final Color _browDark = _col(264, 55, 18, 0.8);
  static final Color _browLight = _col(280, 60, 72, 0.45);
  static final List<Color> _gillColors = [_col(266, 50, 36), _col(258, 55, 13)];
  static final List<Color> _mantleColors = [
    _col(286, 62, 78),
    _col(272, 55, 56),
    _col(250, 60, 33),
    _col(234, 66, 15),
  ];
  static final List<Color> _eyeColors = [
    _col(280, 55, 66),
    _col(262, 54, 42),
    _col(240, 62, 15),
  ];
  static const List<Color> _irisColors = [
    Color(0xFFFFF0B8),
    Color(0xFFE6B24C),
    Color(0xFF7A4A12),
  ];

  void _circ(Canvas g, double x, double y, double r, Color color) {
    _fill
      ..shader = null
      ..color = color;
    g.drawCircle(Offset(x, y), r, _fill);
  }

  /// Canvas shadowOffsetY (ekran px) değerinin geçerli yerel koordinattaki karşılığı.
  Offset _shadowOffset(double offY, {bool mirrored = false, double sx = 1, double sy = 1}) {
    final dx = offY * math.sin(_rot) / _k / sx;
    final dy = offY * math.cos(_rot) / _k / sy;
    return Offset(mirrored ? -dx : dx, dy);
  }

  /// Canvas shadowBlur (ekran px) -> yerel koordinatta MaskFilter sigma'sı.
  Paint _shadowPaint(Color color, double shadowBlur, {double sx = 1, double sy = 1}) {
    return Paint()
      ..isAntiAlias = true
      ..color = color
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        shadowBlur / 2 / (_k * math.sqrt(sx * sy)),
      );
  }

  void _pose(_Arm a, double t) {
    final dl = a.l / _n, pulse = math.sin(t * 5 + a.j * 0.35);
    final th0 = math.pi / 2 - a.sp * (1 + 0.45 * pulse);
    double x = a.x0, y = a.y0;
    final p = a.pts;
    p[0] = x;
    p[1] = y;
    for (var k = 0; k < _n; k++) {
      final s = (k + 0.5) / _n;
      final thA = th0 + 0.75 * s + 0.7 * s * math.sin(7.5 * s - t * 4.4 + a.ph);
      double thC = a.thC[k];
      final lc = (s * a.l - a.la) / a.lc;
      if (lc > 0) thC += 0.25 * lc * lc * math.sin(t * 1.8 + a.ph);
      final b = _smooth((t - _tCurl - a.delay - 0.5 * s) / 0.8);
      final th = thA + (thC - thA) * b;
      a.ths[k] = th;
      x += dl * math.cos(th);
      y += dl * math.sin(th);
      p[2 * k + 2] = x;
      p[2 * k + 3] = y;
    }
    for (var k = 0; k <= _n; k++) {
      final tt = (a.ths[k > 0 ? k - 1 : 0] + a.ths[k < _n ? k : _n - 1]) / 2;
      a.nx[k] = -math.sin(tt);
      a.ny[k] = math.cos(tt);
    }
  }

  void _drawArm(Canvas g, _Arm a, double lx, double ly) {
    final p = a.pts, nx = a.nx, ny = a.ny, ws = a.ws;
    final body = Path()
      ..moveTo(p[0] + nx[0] * ws[0] * 0.5, p[1] + ny[0] * ws[0] * 0.5);
    for (var k = 1; k <= _n; k++) {
      body.lineTo(p[2 * k] + nx[k] * ws[k] * 0.5, p[2 * k + 1] + ny[k] * ws[k] * 0.5);
    }
    for (var k = _n; k >= 0; k--) {
      body.lineTo(p[2 * k] - nx[k] * ws[k] * 0.5, p[2 * k + 1] - ny[k] * ws[k] * 0.5);
    }
    body.close();

    // shadowBlur 9, shadowOffsetY 4 — hem gövde hem kök dairesi için ayrı gölge.
    final shadow = _shadowPaint(_shadowArm, 9);
    final so = _shadowOffset(4, mirrored: a.mir);
    g.drawPath(body.shift(so), shadow);
    _fill
      ..shader = null
      ..color = a.bodyColor;
    g.drawPath(body, _fill);
    g.drawCircle(Offset(p[0], p[1]) + so, ws[0] * 0.5, shadow);
    _circ(g, p[0], p[1], ws[0] * 0.5, a.bodyColor);

    for (var b = 0; b < _bands.length; b++) {
      final band = _bands[b];
      for (var k = 0; k < _n; k += 4) {
        final k2 = math.min(_n, k + 4), mid = math.min(_n, k + 2);
        final seg = Path();
        for (var i = k; i <= k2; i++) {
          final d = (nx[i] * lx + ny[i] * ly) * band[4] * ws[i];
          final px = p[2 * i] + nx[i] * d, py = p[2 * i + 1] + ny[i] * d;
          if (i == k) {
            seg.moveTo(px, py);
          } else {
            seg.lineTo(px, py);
          }
        }
        _stroke
          ..strokeWidth = band[0] * ws[mid]
          ..color = a.bandColors[b][k ~/ 4];
        g.drawPath(seg, _stroke);
      }
    }
    for (final s in a.spots) {
      final kk = (s.l / a.l * _n).round(), w = ws[kk];
      _circ(
        g,
        p[2 * kk] + nx[kk] * s.u * w,
        p[2 * kk + 1] + ny[kk] * s.u * w,
        s.r * w * (s.light ? 0.5 : 1),
        s.light ? _spotLight : _spotDark,
      );
    }
    for (final su in a.suck) {
      final fk = su.l / a.l * _n;
      final k0 = fk.floor(), f = fk - k0, k1 = math.min(_n, k0 + 1);
      final w2 = ws[k0] + (ws[k1] - ws[k0]) * f;
      final r = su.rr * w2;
      if (r < 0.45) continue;
      final cx = p[2 * k0] + (p[2 * k1] - p[2 * k0]) * f + nx[k0] * su.off * w2;
      final cy = p[2 * k0 + 1] + (p[2 * k1 + 1] - p[2 * k0 + 1]) * f + ny[k0] * su.off * w2;
      _circ(g, cx, cy + r * 0.12, r * 1.14, _suckRim);
      _circ(g, cx, cy, r, _suckBody);
      if (r > 1.1) {
        _circ(g, cx, cy, r * 0.46, _suckInner);
        _circ(g, cx, cy, r * 0.2, _suckCore);
      }
      _circ(g, cx + lx * r * 0.45, cy + ly * r * 0.45, r * 0.22, _suckGlint);
    }
  }

  static Path _mantlePath() => Path()
    ..moveTo(-40, -104)
    ..cubicTo(-57, -148, -41, -213, 0, -215)
    ..cubicTo(41, -213, 57, -148, 40, -104)
    ..cubicTo(26, -90, -26, -90, -40, -104)
    ..close();

  static double _blinkAt(double t) {
    if (t < 3.5) return 0;
    final tt = (t - 3.5) % 4.3;
    return tt < 0.22 ? 1 - (tt - 0.11).abs() / 0.11 : 0;
  }

  static Rect _ellipse(double x, double y, double rx, double ry) =>
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2);

  void _drawHead(Canvas g, double t) {
    final br = math.sin(t * 2.2) * 0.03;
    _fill.color = const Color(0xFF000000); // shader varken rengin alfası opaklığı etkiler
    _fill.shader = ui.Gradient.radial(
      const Offset(0, -96), 46, _gillColors, null, TileMode.clamp, null,
      const Offset(-4, -102), 2,
    );
    g.drawOval(_ellipse(0, -95, 43, 18), _fill);

    g.save();
    final sx = 1 - br * 0.5, sy = 1 + br;
    g.translate(0, -100);
    g.scale(sx, sy);
    g.translate(0, 100);
    final mantle = _mantlePath();
    // shadowBlur 14, shadowOffsetY 6
    g.drawPath(
      mantle.shift(_shadowOffset(6, sx: sx, sy: sy)),
      _shadowPaint(_shadowArm, 14, sx: sx, sy: sy),
    );
    _fill.color = const Color(0xFF000000); // shader varken rengin alfası opaklığı etkiler
    _fill.shader = ui.Gradient.radial(
      const Offset(-4, -152), 84, _mantleColors, const [0, 0.3, 0.7, 1], TileMode.clamp, null,
      const Offset(-17, -178), 3,
    );
    g.drawPath(mantle, _fill);

    g.save();
    g.clipPath(mantle);
    for (final s in _mspots) {
      _circ(g, s.x, s.y, s.light ? s.r * 0.5 : s.r, s.light ? _mspotLight : _mspotDark);
    }
    g.save();
    g.translate(-17, -180);
    g.rotate(-0.45);
    _fill
      ..shader = null
      ..color = const Color.fromRGBO(255, 255, 255, 0.16);
    g.drawOval(_ellipse(0, 0, 9, 17), _fill);
    g.restore();
    g.translate(-5, 2);
    _stroke
      ..strokeWidth = 7
      ..color = const Color.fromRGBO(110, 160, 255, 0.3);
    g.drawPath(mantle, _stroke);
    g.restore();

    _stroke
      ..strokeWidth = 1.4
      ..color = _mantleLine;
    g.drawPath(Path()..moveTo(-27, -112)..quadraticBezierTo(0, -103, 27, -112), _stroke);
    g.drawPath(Path()..moveTo(-18, -121)..quadraticBezierTo(0, -115, 18, -121), _stroke);
    g.restore();

    final blink = _blinkAt(t);
    for (var e = -1; e <= 1; e += 2) {
      final cx = e * 34.0, cy = -104.0;
      // shadowBlur 8, shadowOffsetY 3
      g.drawCircle(Offset(cx, cy) + _shadowOffset(3), 18, _shadowPaint(_shadowEye, 8));
      _fill.color = const Color(0xFF000000); // shader varken rengin alfası opaklığı etkiler
      _fill.shader = ui.Gradient.radial(
        Offset(cx, cy), 20, _eyeColors, const [0, 0.5, 1], TileMode.clamp, null,
        Offset(cx - 6, cy - 8), 2,
      );
      g.drawCircle(Offset(cx, cy), 18, _fill);

      final ix = cx + e * 1.5, iy = cy + 1.5;
      final iris = _ellipse(ix, iy, 11, 10);
      _fill.color = const Color(0xFF000000); // shader varken rengin alfası opaklığı etkiler
      _fill.shader = ui.Gradient.radial(
        Offset(ix, iy), 11, _irisColors, const [0, 0.5, 1], TileMode.clamp, null,
        Offset(ix - 2, iy - 2), 1,
      );
      g.drawOval(iris, _fill);
      _stroke
        ..strokeWidth = 1.8
        ..color = _irisRing;
      g.drawOval(iris, _stroke);
      _fill
        ..shader = null
        ..color = const Color(0xFF06030B);
      g.drawOval(_ellipse(ix, iy, 7.8, 2.5), _fill);
      _circ(g, ix - 4, iy - 4, 2.1, const Color.fromRGBO(255, 255, 255, 0.9));
      _circ(g, ix + 3.5, iy + 3.5, 1, const Color.fromRGBO(255, 255, 255, 0.4));
      if (blink > 0) {
        g.save();
        g.clipPath(Path()..addOval(_ellipse(ix, iy, 12, 11)));
        _fill.color = _lidTop;
        g.drawRect(Rect.fromLTWH(ix - 13, iy - 12, 26, 23 * blink), _fill);
        _fill.color = _lidEdge;
        g.drawRect(Rect.fromLTWH(ix - 13, iy - 12 + 23 * blink - 1.2, 26, 1.6), _fill);
        g.restore();
      }
      _stroke
        ..strokeWidth = 2.2
        ..color = _browDark;
      g.drawArc(
        Rect.fromCircle(center: Offset(ix, iy + 1), radius: 13.5),
        math.pi * 1.12, math.pi * 0.76, false, _stroke,
      );
      _stroke
        ..strokeWidth = 1.2
        ..color = _browLight;
      g.drawArc(
        Rect.fromCircle(center: Offset(ix, iy + 1), radius: 15.5),
        math.pi * 1.2, math.pi * 0.35, false, _stroke,
      );
    }
  }

  void _drawBg(Canvas c, Size size, double t, double cx, double cy, double glow) {
    final w = size.width, h = size.height;
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, h),
          const [Color(0xFF17245C), Color(0xFF0B1540), Color(0xFF050920)],
          const [0, 0.45, 1],
        ),
    );
    // 'lighter' -> BlendMode.plus
    final rayShader = ui.Gradient.linear(
      Offset.zero, Offset(0, h * 0.8),
      const [Color.fromRGBO(120, 150, 255, 0.09), Color.fromRGBO(120, 150, 255, 0)],
    );
    final rayPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = rayShader;
    for (var i = 0; i < 4; i++) {
      final x = (0.12 + i * 0.25) * w + math.sin(t * 0.25 + i * 1.7) * 18;
      c.drawPath(
        Path()
          ..moveTo(x - 12, 0)
          ..lineTo(x + 20, 0)
          ..lineTo(x + 120 + i * 12, h * 0.8)
          ..lineTo(x + 30, h * 0.8)
          ..close(),
        rayPaint,
      );
    }
    if (glow > 0) {
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            Offset(cx, cy), w * 0.75,
            [Color.fromRGBO(125, 80, 235, 0.24 * glow), const Color.fromRGBO(125, 80, 235, 0)],
          ),
      );
    }
    final partPaint = Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.plus;
    for (final q in _parts) {
      final py = ((q.y - t * 0.012 * q.z) % 1 + 1) % 1;
      final px = q.x + math.sin(t * 0.3 + q.ph) * 0.01;
      partPaint.color = Color.fromRGBO(190, 200, 255, 0.1 + 0.3 * q.z);
      c.drawCircle(Offset(px * w, py * h), 0.5 + 1.1 * q.z, partPaint);
    }
  }

  /// JS frame(t) karşılığı. [devicePixelRatio] yalnızca bulanıklık eşiği için.
  void paint(Canvas canvas, Size size, double t, double devicePixelRatio) {
    if (size.isEmpty) return;
    final w = size.width, h = size.height;
    final eo = 1 - math.pow(1 - _clamp(t / 2.2), 2.2);
    final ec = _smooth((t - 1.9) / 1.6);
    final unit = unitFor(size);
    final sc = 0.05 + 0.79 * eo + 0.16 * ec + 0.03 * math.max(0, math.sin(t * 5)) * (1 - ec);
    final ox = w / 2 + math.sin(t * 1.3) * 6 * (1 - ec);
    final oy = h * 0.44 + (1 - eo) * 110 + math.sin(t * 1.1) * 3 * ec;
    final rot = 0.06 * math.sin(t * 1.7) * (1 - ec);
    _drawBg(canvas, size, t, w / 2, oy - 50 * unit * sc, eo.toDouble());

    final alpha = _clamp(t / 0.5);
    if (alpha <= 0) return;

    // Ahtapot ayrı bir katmanda çizilir; uzaklık bulanıklığı ve opaklık
    // katman birleştirilirken uygulanır (JS: ctx.filter + globalAlpha).
    final blur = 6 * math.pow(1 - eo, 1.5).toDouble();
    final layerPaint = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    if (blur * devicePixelRatio > 0.2) {
      layerPaint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal);
    }
    canvas.saveLayer(Offset.zero & size, layerPaint);

    _k = sc * unit;
    _rot = rot;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(rot);
    canvas.scale(_k);
    for (final a in _arms) {
      _pose(a, t);
    }
    for (var jj = 3; jj >= 0; jj--) {
      for (final a in _arms) {
        if (a.j != jj) continue;
        if (a.mir) {
          canvas.save();
          canvas.scale(-1, 1);
          _drawArm(canvas, a, 0.55, -0.83);
          canvas.restore();
        } else {
          _drawArm(canvas, a, -0.55, -0.83);
        }
      }
    }
    _drawHead(canvas, t);
    canvas.restore();

    // Sis: yalnızca ahtapotun üzerine (source-atop -> BlendMode.srcATop).
    final fog = 0.85 * math.pow(1 - eo, 1.2);
    if (fog > 0.004) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Color.fromRGBO(11, 21, 64, fog.toDouble()),
      );
    }
    canvas.restore();
  }
}

class OctopusScenePainter extends CustomPainter {
  OctopusScenePainter({
    required this.scene,
    required this.time,
    required this.devicePixelRatio,
  }) : super(repaint: time);

  final OctopusScene scene;
  final ValueListenable<double> time;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    scene.paint(canvas, size, time.value, devicePixelRatio);
  }

  @override
  bool shouldRepaint(OctopusScenePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.time != time ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
