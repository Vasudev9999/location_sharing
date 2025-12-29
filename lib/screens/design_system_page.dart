import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

// ---------------------------------------------------------------------------
// 1. CURVY ARTIST PALETTE & STYLING
// ---------------------------------------------------------------------------
const Color kBgColor = Color(0xFFE0F7FA); // Soft Cyan Background
const Color kCardBg = Color(0xFFFFFDE7); // Creamy Off-White
const Color kAccentYellow = Color(0xFFFFD54F);
const Color kAccentOrange = Color(0xFFFF8A80);
const Color kAccentBlue = Color(0xFF80D8FF);
const Color kAccentGreen = Color(0xFFB9F6CA);
const Color kBlack = Color(0xFF212121); // Softened Black

// Styling Constants
const double kBorderWidth = 3.0;
const double kShadowOffset = 4.0;
const double kRadius = 32.0; // VERY CURVY
const double kElementRadius = 16.0; // Standard radius for smaller UI elements

// Helper for the "Curvy Artist" look
BoxDecoration artistDecoration({
  required Color color,
  double radius = kRadius,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kBlack.withOpacity(0.95), width: kBorderWidth),
    boxShadow: [
      BoxShadow(
        color: kBlack.withOpacity(0.12),
        blurRadius: 8,
        offset: Offset(kShadowOffset, kShadowOffset),
      ),
      BoxShadow(
        color: kBlack.withOpacity(0.06),
        blurRadius: 24,
        offset: Offset(0, kShadowOffset),
      ),
    ],
  );
}

TextStyle get headerStyle => GoogleFonts.spaceMono(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kBlack,
);

TextStyle get bodyStyle => GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kBlack,
);

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DesignSystemPage(),
    ),
  );
}

// ---------------------------------------------------------------------------
// 2. MAIN DASHBOARD PAGE (Renamed to match your Login Page)
// ---------------------------------------------------------------------------
class DesignSystemPage extends StatelessWidget {
  const DesignSystemPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        // Using CustomScrollView to prevent overflow everywhere
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // AppBar
            SliverAppBar(
              backgroundColor: kBgColor,
              elevation: 0,
              floating: true,
              title: Text(
                'ARTIST_DASH.ui',
                style: headerStyle.copyWith(fontSize: 22),
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _ArtistIconButton(
                    icon: Icons.settings,
                    color: kAccentYellow,
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- SECTION 1: DASHBOARD STATS ---
                  const _SectionHeader(title: 'OVERVIEW'),
                  Row(
                    children: const [
                      Expanded(
                        child: _StatCard(
                          label: 'TOTAL USERS',
                          value: '12.5K',
                          color: kAccentBlue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          label: 'REVENUE',
                          value: '\$84K',
                          color: kAccentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- NEW: ADDITIONAL COMPONENTS ---
                  const _SectionHeader(title: 'NEW ELEMENTS'),
                  const SizedBox(height: 12),
                  _LabeledInput(
                    label: 'Full name',
                    hint: 'First and last name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ModernButton(
                          label: 'Continue',
                          color: kAccentOrange,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernButton(
                          label: 'Later',
                          color: kCardBg,
                          onTap: () {},
                          height: 48,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SegmentedControl(items: ['One', 'Two', 'Three']),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      _Badge(label: 'NEW', color: kAccentOrange),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.trending_up,
                          value: '+12%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AvatarRow(names: ['AL', 'BG', 'CM', 'DK']),
                  const SizedBox(height: 12),
                  _ChipList(items: ['Alpha', 'Beta', 'Gamma']),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Welcome',
                    subtitle:
                        'This is an example of a new info card with a short description.',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 32),

                  // --- SECTION 2: BUTTONS & INTERACTION ---
                  const _SectionHeader(title: 'CONTROLS & ACTIONS'),
                  const _ArtistSlideToggle(label: 'DARK MODE'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _PressableButton(
                          label: 'PRIMARY ACTION',
                          color: kAccentOrange,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PressableButton(
                          label: 'SECONDARY',
                          color: kCardBg,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Icon Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _ArtistIconButton(
                        icon: Icons.home_rounded,
                        color: kAccentYellow,
                        size: 50,
                      ),
                      _ArtistIconButton(
                        icon: Icons.favorite_rounded,
                        color: kAccentOrange,
                        size: 50,
                      ),
                      _ArtistIconButton(
                        icon: Icons.share_rounded,
                        color: kAccentBlue,
                        size: 50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- SECTION 3: INPUTS ---
                  const _SectionHeader(title: 'DATA ENTRY'),
                  _LabeledInput(
                    label: 'Username',
                    hint: 'Enter username',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 16),
                  const _ArtistSearchBar(),
                  const SizedBox(height: 32),

                  // --- SECTION 4: SPECIAL CARDS (Speedometer & Location) ---
                  const _SectionHeader(title: 'LIVE METRICS'),
                  const _SpeedometerCard(speed: 75),
                  const SizedBox(height: 24),
                  const _LocationCard(),
                  const SizedBox(height: 32),

                  // --- SECTION 5: LOADERS ---
                  const _SectionHeader(title: 'SYSTEM STATUS'),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: artistDecoration(color: kCardBg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [_ChunkySpinner(), _ChunkyProgress()],
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. CORE COMPONENTS
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        '// $title',
        style: headerStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// --- A. STAT CARD ---
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: artistDecoration(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: headerStyle.copyWith(fontSize: 28)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- B. BUTTONS (Pressable & Icons) ---
class _PressableButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double? height;
  const _PressableButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.height,
  });
  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final btnHeight = widget.height ?? 56.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: btnHeight,
        // Squish shadow when pressed
        decoration: artistDecoration(
          color: widget.color,
          radius: kElementRadius,
        ).copyWith(
          boxShadow:
              _isPressed
                  ? [
                    const BoxShadow(
                      color: kBlack,
                      blurRadius: 0,
                      offset: Offset(0, 0),
                    ),
                  ]
                  : null,
        ),
        // Move button down when pressed
        transform:
            _isPressed
                ? Matrix4.translationValues(kShadowOffset, kShadowOffset, 0)
                : Matrix4.identity(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                style: headerStyle.copyWith(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _ArtistIconButton({
    required this.icon,
    required this.color,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: artistDecoration(color: color, radius: size / 2),
      child: Icon(icon, color: kBlack, size: size * 0.5),
    );
  }
}

class _ArtistSlideToggle extends StatefulWidget {
  final String label;
  const _ArtistSlideToggle({required this.label});
  @override
  State<_ArtistSlideToggle> createState() => _ArtistSlideToggleState();
}

class _ArtistSlideToggleState extends State<_ArtistSlideToggle> {
  bool isOn = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => isOn = !isOn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: artistDecoration(color: isOn ? kAccentGreen : kCardBg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 60,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kBlack,
                borderRadius: BorderRadius.circular(kElementRadius),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isOn ? kAccentGreen : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- C. INPUTS ---
class _ArtistInput extends StatelessWidget {
  final String hint;
  final IconData icon;
  const _ArtistInput({required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: artistDecoration(color: kCardBg),
      child: TextField(
        style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
        cursorColor: kBlack,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          prefixIcon: IconTheme(
            data: const IconThemeData(size: 24),
            child: Icon(icon, color: kBlack),
          ),
          hintText: hint,
          hintStyle: bodyStyle.copyWith(color: kBlack.withOpacity(0.5)),
        ),
        minLines: 1,
      ),
    );
  }
}

class _ArtistSearchBar extends StatelessWidget {
  const _ArtistSearchBar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: artistDecoration(
        color: kAccentYellow,
        radius: kElementRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
              cursorColor: kBlack,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                hintText: 'Search...',
                hintStyle: bodyStyle.copyWith(color: kBlack.withOpacity(0.6)),
                border: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                prefixIcon: IconTheme(
                  data: const IconThemeData(size: 24),
                  child: Icon(Icons.search, color: kBlack.withOpacity(0.95)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ArtistIconButton(icon: Icons.mic, color: kCardBg, size: 44),
        ],
      ),
    );
  }
}

// -------------------------
// Additional Modern Components
// -------------------------

class _ModernButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double? height;
  const _ModernButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    return _PressableButton(
      label: label,
      color: color,
      onTap: onTap,
      height: height,
    );
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return _PressableButton(
      label: '$label',
      color: kCardBg,
      onTap: onTap,
      height: 48,
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData? icon;
  const _LabeledInput({required this.label, required this.hint, this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: bodyStyle.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: artistDecoration(color: kCardBg, radius: kElementRadius),
          child: TextField(
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            cursorColor: kBlack,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: false,
              fillColor: Colors.transparent,
              prefixIcon:
                  icon != null
                      ? IconTheme(
                        data: const IconThemeData(size: 24),
                        child: Icon(icon, color: kBlack),
                      )
                      : null,
              hintText: hint,
              hintStyle: bodyStyle.copyWith(color: kBlack.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatefulWidget {
  final List<String> items;
  final ValueChanged<int>? onChanged;
  const _SegmentedControl({required this.items, this.onChanged});
  @override
  State<_SegmentedControl> createState() => _SegmentedControlState();
}

class _SegmentedControlState extends State<_SegmentedControl> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(widget.items.length, (i) {
        final isSel = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => selected = i);
              widget.onChanged?.call(i);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: artistDecoration(
                color: isSel ? kAccentOrange : kCardBg,
                radius: kElementRadius,
              ).copyWith(
                border: Border.all(
                  color: kBlack.withOpacity(0.9),
                  width: kBorderWidth,
                ),
              ),
              child: Center(
                child: Text(
                  widget.items[i],
                  style: bodyStyle.copyWith(
                    color: isSel ? Colors.white : kBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: artistDecoration(color: kCardBg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kAccentBlue,
              borderRadius: BorderRadius.circular(kElementRadius),
            ),
            child: Icon(icon, color: kBlack),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: headerStyle.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: bodyStyle.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------
// Extra small components
// -------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: artistDecoration(color: color, radius: kElementRadius),
      child: Text(
        label,
        style: bodyStyle.copyWith(fontWeight: FontWeight.w700, color: kBlack),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniStat({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: artistDecoration(color: kCardBg, radius: kElementRadius),
      child: Row(
        children: [
          Icon(icon, color: kBlack),
          const SizedBox(width: 8),
          Text(value, style: bodyStyle.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final List<String> names;
  const _AvatarRow({required this.names});
  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          names
              .map(
                (n) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: kAccentBlue,
                    child: Text(
                      n,
                      style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _ChipList extends StatefulWidget {
  final List<String> items;
  const _ChipList({required this.items});
  @override
  State<_ChipList> createState() => _ChipListState();
}

class _ChipListState extends State<_ChipList> {
  int selected = -1;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List.generate(widget.items.length, (i) {
        final sel = i == selected;
        return GestureDetector(
          onTap: () => setState(() => selected = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: artistDecoration(
              color: sel ? kAccentOrange : kCardBg,
              radius: kElementRadius,
            ),
            child: Text(
              widget.items[i],
              style: bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kBlack,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// --- D. SPECIAL CARDS (Speedometer & Location) ---

class _SpeedometerCard extends StatelessWidget {
  final double speed; // 0 to 100
  const _SpeedometerCard({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: artistDecoration(color: kCardBg),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // The Gauge Painter
          Positioned(
            top: 20,
            child: CustomPaint(
              size: const Size(200, 120),
              painter: _GaugePainter(speed: speed),
            ),
          ),
          // Speed Text
          Positioned(
            bottom: 30,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    speed.toStringAsFixed(0),
                    style: headerStyle.copyWith(fontSize: 32),
                  ),
                ),
                Text(
                  'KM/H',
                  style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 20,
            child: Icon(Icons.speed_rounded, color: kBlack),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  _GaugePainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    // 1. Background Arc (Thick Black Border Style)
    final bgPaint =
        Paint()
          ..color = kBlack
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + kBorderWidth * 2
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // 2. Track Arc (Off-white filler)
    final trackPaint =
        Paint()
          ..color = kCardBg
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    // 3. Progress Arc (Colored)
    final progressPaint =
        Paint()
          ..color = speed > 70 ? kAccentOrange : kAccentGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    // Calculate angle based on speed (0-100 maps to pi to 2*pi)
    final sweepAngle = (speed / 100) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweepAngle,
      false,
      progressPaint,
    );

    // 4. Needle (Thick Line)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate to match speed position (-pi/2 is pointing up)
    canvas.rotate(math.pi + sweepAngle);

    final needlePaint =
        Paint()
          ..color = kBlack
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(radius - 20, 0), needlePaint);

    // Needle anchor point
    canvas.drawCircle(Offset.zero, 10, Paint()..color = kBlack);
    canvas.drawCircle(Offset.zero, 5, Paint()..color = kAccentYellow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: artistDecoration(color: kAccentBlue),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Stack(
          children: [
            // Abstract Map Background
            Positioned.fill(child: CustomPaint(painter: _ChunkyGridPainter())),
            // Live Badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: artistDecoration(
                  color: kAccentOrange,
                  radius: kElementRadius,
                ),
                child: Text(
                  'LIVE TRACKING',
                  style: bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // User Pin
            const Center(
              child: _ArtistIconButton(
                icon: Icons.person_pin_circle_rounded,
                color: kAccentYellow,
                size: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChunkyGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = kBlack.withOpacity(0.2)
          ..strokeWidth = 2;
    // Draw some chunky grid lines
    for (double i = 20; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 20; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    // Draw a thick path
    final pathPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 0.4,
      size.width,
      size.height * 0.6,
    );
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- E. LOADERS ---

class _ChunkySpinner extends StatefulWidget {
  const _ChunkySpinner({Key? key}) : super(key: key);
  @override
  State<_ChunkySpinner> createState() => _ChunkySpinnerState();
}

class _ChunkySpinnerState extends State<_ChunkySpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: Container(
            width: 50,
            height: 50,
            decoration: artistDecoration(
              color: kAccentOrange,
              radius: kElementRadius,
            ),
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: kBlack,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChunkyProgress extends StatefulWidget {
  const _ChunkyProgress({Key? key}) : super(key: key);
  @override
  State<_ChunkyProgress> createState() => _ChunkyProgressState();
}

class _ChunkyProgressState extends State<_ChunkyProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 30,
      decoration: artistDecoration(color: Colors.white, radius: kElementRadius),
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            width: 120 * _ctrl.value,
            height: 30,
            decoration: BoxDecoration(
              color: kAccentGreen,
              borderRadius: BorderRadius.circular(kElementRadius),
              border: Border.all(color: kBlack, width: kBorderWidth),
            ),
          );
        },
      ),
    );
  }
}
