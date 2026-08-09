
import 'dart:math';
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class WaterBottle extends StatefulWidget {
  final double progress;
  final int consumed;
  final int goal;
  final double? maxWidth;

  const WaterBottle({
    super.key,
    required this.progress,
    required this.consumed,
    required this.goal,
    this.maxWidth,
  });

  @override
  State<WaterBottle> createState() => _WaterBottleState();
}

class _WaterBottleState extends State<WaterBottle>
    with SingleTickerProviderStateMixin {
  late final AnimationController waveController;
  late final ConfettiController confettiController;

  bool played = false;

  @override
  void initState() {
    super.initState();

    waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );


  }

  @override
  void didUpdateWidget(covariant WaterBottle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.progress >= 1 && !played) {
      played = true;
      confettiController.play();
    }

    if (widget.progress < 1) {
      played = false;
    }
  }

  @override
  void dispose() {
    waveController.dispose();
    confettiController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final availableWidth = min(safeWidth, widget.maxWidth ?? safeWidth);

        final bottleWidth = min(availableWidth * 0.38, 320.0);
        final bottleHeight = bottleWidth * 1.65;
        final widgetWidth = bottleWidth + 70;
        final widgetHeight = bottleHeight + 100;

        final iconSize = bottleWidth * 0.28;
        final amountSize = bottleWidth * 0.17;
        final goalSize = bottleWidth * 0.10;
        final percentSize = bottleWidth * 0.11;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            final waterHeight = bottleHeight * progress;
            final completed = progress >= 1;
            final textCovered = waterHeight >= bottleHeight * 0.56;

            return AnimatedBuilder(
              animation: waveController,
              builder: (_, _) {
                return SizedBox(
                  width: widgetWidth,
                  height: widgetHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          emissionFrequency: 0.04,
                          numberOfParticles: 25,
                          gravity: 0.25,
                          maxBlastForce: 30,
                          minBlastForce: 15,
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 600),
                        opacity: completed ? 1 : 0,
                        child: Container(
                          width: bottleWidth + 30,
                          height: bottleHeight + 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withAlpha(
                                  (0.35 * 255).round(),
                                ),
                                blurRadius: 40,
                                spreadRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        child: Container(
                          width: bottleWidth * .42,
                          height: bottleHeight * .11,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              bottleWidth * .08,
                            ),
                            border: Border.all(
                              color: Colors.blue.shade700,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: bottleHeight * .12,
                        child: Container(
                          width: bottleWidth,
                          height: bottleHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              bottleWidth * .24,
                            ),
                            border: Border.all(
                              color: Colors.blue.shade700,
                              width: 4,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              bottleWidth * .21,
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOut,
                                    width: double.infinity,
                                    height: waterHeight,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Color(0xff1976D2),
                                          Color(0xff42A5F5),
                                          Color(0xff90CAF9),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (progress > 0)
                                  Positioned(
                                    bottom: waterHeight - 9,
                                    left:
                                        sin(waveController.value * pi * 2) *
                                            10 -
                                        12,
                                    child: Container(
                                      width: bottleWidth + 25,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(
                                          (0.28 * 255).round(),
                                        ),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                  ),
                                if (progress > 0)
                                  ...List.generate(14, (i) {
                                    final bubbleY =
                                        (waveController.value * bottleHeight +
                                            i * 24) %
                                        max(waterHeight, 1);

                                    final bubbleSize = 4 + (i % 4) * 2.0;

                                    return Positioned(
                                      bottom: bubbleY,
                                      left:
                                          15 + ((i * 17) % (bottleWidth - 30)),
                                      child: Opacity(
                                        opacity: .55,
                                        child: Container(
                                          width: bubbleSize,
                                          height: bubbleSize,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                Positioned(
                                  left: 16,
                                  top: 18,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 3,
                                        sigmaY: 3,
                                      ),
                                      child: Container(
                                        width: 10,
                                        height: bottleHeight - 50,
                                        color: Colors.white.withAlpha(
                                          (0.18 * 255).round(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: SizedBox(
                                    width: bottleWidth - 20,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: Icon(
                                            Icons.water_drop,
                                            key: ValueKey(textCovered),
                                            size: iconSize,
                                            color: completed
                                                ? Colors.amber
                                                : textCovered
                                                ? Colors.white
                                                : Colors.blue.shade700,
                                          ),
                                        ),
                                        SizedBox(height: bottleHeight * .03),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          style: TextStyle(
                                            color: textCovered
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: amountSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          child: Text(
                                            "${widget.consumed} mL",
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        SizedBox(height: bottleHeight * .015),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          style: TextStyle(
                                            color: textCovered
                                                ? Colors.white70
                                                : Colors.grey.shade700,
                                            fontSize: goalSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          child: Text(
                                            "Goal ${widget.goal} mL",
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        SizedBox(height: bottleHeight * .04),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: bottleWidth * .09,
                                            vertical: bottleHeight * .025,
                                          ),
                                          decoration: BoxDecoration(
                                            color: textCovered
                                                ? Colors.white24
                                                : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Text(
                                            "${(progress * 100).toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: percentSize,
                                              color: textCovered
                                                  ? Colors.white
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
