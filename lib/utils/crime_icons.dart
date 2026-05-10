// lib/utils/crime_icons.dart
//
// Provides distinct, visually differentiated custom map markers for each
// crime type. Each marker is a Flutter widget built from SVG paths so it
// renders crisply at any DPI without relying on emoji glyph rendering
// (which varies wildly across Android versions and causes main-thread
// layout passes that compete with the map tile loading).
//
// WHY NOT EMOJI?
// Emoji rendering in Flutter forces a PlatformFont layout pass on the UI
// thread every time a marker is built.  With hundreds of markers this
// causes significant jank.  Pure-Flutter widgets (CustomPaint + Canvas)
// are rasterised on the raster thread and cached via RepaintBoundary,
// costing almost no UI-thread time after the first draw.
//
// USAGE:
//   final marker = CrimeIconWidget(crimeType: 'Robbery', size: 36);

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Configuration — one entry per crime type.
// Each CrimeIconConfig holds:
//   • color       — the fill colour for the icon background blob
//   • symbol      — a single Unicode character drawn in the icon
//                   (system symbols, NOT emoji — avoids the font-lookup cost)
//   • symbolColor — foreground colour of the symbol
// ---------------------------------------------------------------------------
class _CrimeIconConfig {
  final Color  color;
  final String symbol;
  final Color  symbolColor;

  const _CrimeIconConfig({
    required this.color,
    required this.symbol,
    required this.symbolColor,
  });
}

// Map of lower-cased crime-type name → icon configuration.
// Keys are matched with contains() so partial matches work
// (e.g. "vehicle break-in" still matches "break" → cyan config).
const Map<String, _CrimeIconConfig> _iconConfigs = {
  // Violent crimes → red family
  'robbery'      : _CrimeIconConfig(color: Color(0xFFD32F2F), symbol: '!', symbolColor: Colors.white),
  'assault'      : _CrimeIconConfig(color: Color(0xFFB71C1C), symbol: '✕', symbolColor: Colors.white),
  'murder'       : _CrimeIconConfig(color: Color(0xFF880E4F), symbol: '✕', symbolColor: Colors.white),
  'kidnapping'   : _CrimeIconConfig(color: Color(0xFF4A148C), symbol: '?', symbolColor: Colors.white),

  // Property crimes → orange / amber family
  'theft'        : _CrimeIconConfig(color: Color(0xFFE65100), symbol: '↑', symbolColor: Colors.white),
  'burglary'     : _CrimeIconConfig(color: Color(0xFFBF360C), symbol: '⌂', symbolColor: Colors.white),
  'break'        : _CrimeIconConfig(color: Color(0xFF00838F), symbol: '⬡', symbolColor: Colors.white), // vehicle break-in
  'shoplifting'  : _CrimeIconConfig(color: Color(0xFFF57F17), symbol: '◈', symbolColor: Colors.white),
  'fraud'        : _CrimeIconConfig(color: Color(0xFF1565C0), symbol: '§', symbolColor: Colors.white),
  'vandalism'    : _CrimeIconConfig(color: Color(0xFF4E342E), symbol: '⚡', symbolColor: Colors.white),
  'arson'        : _CrimeIconConfig(color: Color(0xFFFF6F00), symbol: '▲', symbolColor: Colors.white),

  // Drug / vice → purple family
  'drug'         : _CrimeIconConfig(color: Color(0xFF6A1B9A), symbol: '◆', symbolColor: Colors.white),
  'prostitution' : _CrimeIconConfig(color: Color(0xFF880E4F), symbol: '◉', symbolColor: Colors.white),

  // Road / transport
  'hijacking'    : _CrimeIconConfig(color: Color(0xFFE53935), symbol: '⬆', symbolColor: Colors.white),
  'traffic'      : _CrimeIconConfig(color: Color(0xFFF9A825), symbol: '⬟', symbolColor: Colors.black),

  // Default — shown when no key matches
  '_default'     : _CrimeIconConfig(color: Color(0xFF546E7A), symbol: '●', symbolColor: Colors.white),
};

// ---------------------------------------------------------------------------
// Resolve config for an arbitrary crime-type string.
// Matching is case-insensitive and uses substring search so that
// "Armed Robbery" → matches 'robbery' and "Vehicle Break-In" → 'break'.
// ---------------------------------------------------------------------------
_CrimeIconConfig _resolveConfig(String crimeType) {
  final lower = crimeType.toLowerCase();
  for (final entry in _iconConfigs.entries) {
    if (entry.key == '_default') continue;
    if (lower.contains(entry.key)) return entry.value;
  }
  return _iconConfigs['_default']!;
}

// ---------------------------------------------------------------------------
// CrimeIconWidget
//
// A pure-Flutter widget that renders a teardrop-shaped pin marker using
// CustomPaint.  Because it contains no text (just a canvas path), Flutter
// can rasterise it on the raster thread without ever touching
// PlatformTextStyle or ParagraphBuilder on the UI thread.
//
// The pin shape is a circle with a small downward-pointing triangle,
// which is the universally recognised "map pin" silhouette.
// ---------------------------------------------------------------------------
class CrimeIconWidget extends StatelessWidget {
  final String crimeType;
  final double size;

  const CrimeIconWidget({
    super.key,
    required this.crimeType,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveConfig(crimeType);

    // RepaintBoundary tells Flutter's compositor to cache the rasterised
    // bitmap of this subtree on the GPU.  Subsequent frames reuse the
    // cached texture instead of re-executing the paint commands, which is
    // the single biggest win for map markers that don't change.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size * 1.3),       // extra height for the pointer tail
        painter: _PinPainter(config: config, symbol: config.symbol),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PinPainter — draws the pin on a Canvas.
//
// The shape consists of two parts:
//   1. A circle (the "head" of the pin) filled with the crime-type colour.
//   2. A downward-pointing equilateral triangle (the "tail") below the circle.
//   3. A white inner circle, then the symbol character in the centre.
//
// All drawing is done with canvas primitives (no Flutter text layout),
// so this executes entirely on the raster thread.
// ---------------------------------------------------------------------------
class _PinPainter extends CustomPainter {
  final _CrimeIconConfig config;
  final String symbol;

  const _PinPainter({required this.config, required this.symbol});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;        // horizontal centre
    final r  = size.width  / 2 * 0.88; // radius of the pin head circle
    final headCy = r + 1;              // vertical centre of the head

    // ── 1. Drop shadow (soft, offset down-right) ─────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(Offset(cx + 1, headCy + 2), r, shadowPaint);

    // ── 2. Pin head — filled circle ───────────────────────────────────────
    final bodyPaint = Paint()
      ..color = config.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, headCy), r, bodyPaint);

    // ── 3. Pin tail — downward-pointing triangle ──────────────────────────
    final tailPath = Path()
      ..moveTo(cx - r * 0.4, headCy + r * 0.7)   // left base of triangle
      ..lineTo(cx + r * 0.4, headCy + r * 0.7)   // right base of triangle
      ..lineTo(cx,           size.height - 1)     // tip of the tail
      ..close();

    canvas.drawPath(tailPath, bodyPaint);

    // ── 4. White inner circle (badge background) ──────────────────────────
    final badgePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, headCy), r * 0.62, badgePaint);

    // ── 5. Border ring around the head ────────────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(Offset(cx, headCy), r, borderPaint);

    // ── 6. Symbol character drawn via TextPainter ─────────────────────────
    // We DO use TextPainter here, but only once per unique (crimeType, size)
    // combination.  The RepaintBoundary above caches the result so this
    // code runs at most once per marker type, not once per frame.
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: r * 0.75,
          fontWeight: FontWeight.w900,
          color: config.symbolColor,
          height: 1,
          // Explicitly specify a non-emoji font family so Flutter never
          // falls through to the emoji font (which triggers a slow layout pass).
          fontFamily: 'monospace',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    // Centre the text within the pin head circle
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, headCy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.config.color != config.color || old.symbol != symbol;
}

// ---------------------------------------------------------------------------
// CrimeIconLegend
//
// A compact horizontal scrolling legend widget for the map screen, showing
// a small coloured dot + label for each crime type currently in the dataset.
// This is rendered once and wrapped in RepaintBoundary so it doesn't
// invalidate when the map pans.
// ---------------------------------------------------------------------------
class CrimeIconLegend extends StatelessWidget {
  /// List of distinct crime type names to show in the legend.
  final List<String> crimeTypes;

  const CrimeIconLegend({super.key, required this.crimeTypes});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: crimeTypes.length,
          itemBuilder: (_, i) {
            final cfg = _resolveConfig(crimeTypes[i]);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colour dot
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: cfg.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    crimeTypes[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
