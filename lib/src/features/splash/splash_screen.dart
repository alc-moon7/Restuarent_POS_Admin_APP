import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.bootFuture, required this.onFinished, super.key});

  final Future<void> bootFuture;
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _shimmerController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..forward();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2200),
    )..repeat();
    _scale = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _finishAfterBoot();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: PosGradients.brandDeep),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _BgOrb(
              size: 360,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _BgOrb(
              size: 380,
              color: PosColors.primaryGlow.withValues(alpha: 0.18),
            ),
          ),
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              return Positioned(
                top: -100 + 200 * _shimmerController.value,
                left: -50 + 100 * _shimmerController.value,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: Offset(0, 22),
                          ),
                          BoxShadow(
                            color: PosColors.primaryGlow.withValues(alpha: 0.3),
                            blurRadius: 32,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return PosGradients.brand.createShader(rect);
                        },
                        child: Icon(
                          Icons.point_of_sale_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    SizedBox(height: 22),
                    Text(
                      'REs Admin',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 0,
                        fontSize: 32,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(PosRadii.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: PosColors.primaryGlow,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: PosColors.primaryGlow,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cloud Restaurant Suite',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishAfterBoot() async {
    await Future.wait([
      widget.bootFuture,
      Future<void>.delayed(Duration(milliseconds: 1600)),
    ]);
    if (mounted) widget.onFinished();
  }
}

class _BgOrb extends StatelessWidget {
  const _BgOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
