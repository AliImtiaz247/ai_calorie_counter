import 'dart:ui';
import 'package:flutter/material.dart';

class Responsive {
  /// Logical Screen width
  static double width(BuildContext context) => MediaQuery.of(context).size.width;

  /// Logical Screen height
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  /// Orientation
  static Orientation orientation(BuildContext context) =>
      MediaQuery.of(context).orientation;

  static bool isLandscape(BuildContext context) =>
      orientation(context) == Orientation.landscape || width(context) > height(context);

  /// Breakpoint Checks
  static bool isSmallPhone(BuildContext context) => width(context) < 360;

  static bool isSmallScreen(BuildContext context) => isSmallPhone(context);

  static bool isPhone(BuildContext context) =>
      width(context) >= 360 && width(context) < 600;

  static bool isMediumScreen(BuildContext context) => isPhone(context);

  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 900;

  static bool isLargeTablet(BuildContext context) => width(context) >= 900;

  static bool isTabletOrDesktop(BuildContext context) => width(context) >= 600;

  /// Dynamic horizontal padding based on screen width
  static double horizontalPadding(BuildContext context) {
    if (isLargeTablet(context)) return 40.0;
    if (isTablet(context)) return 32.0;
    if (isSmallPhone(context)) return 12.0;
    return 20.0;
  }

  /// Max content width for readable tablet layouts
  static double maxAuthWidth(BuildContext context) => 480.0;
  static double maxFormWidth(BuildContext context) => 680.0;
  static double maxDashboardWidth(BuildContext context) => 1150.0;

  /// Responsive font sizing with clamping to prevent overflow
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final scale = width(context) / 375.0;
    final clampedScale = clampDouble(scale, 0.85, 1.20);
    return baseSize * clampedScale;
  }

  /// Dynamic Grid Column Count
  static int gridCrossAxisCount(BuildContext context, {int defaultCount = 3}) {
    final w = width(context);
    if (w < 340) return 2;
    if (w >= 600 && w < 900) return 4;
    if (w >= 900) return 5;
    return defaultCount;
  }

  /// Multi-Column Grid Column Helper
  static int responsiveColumns(
    BuildContext context, {
    int phone = 1,
    int tablet = 2,
    int largeTablet = 3,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTabletOrDesktop(context)) return tablet;
    return phone;
  }
}

/// Reusable Widget that centers content and constrains maximum width on tablets
class ResponsiveContentConstrained extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool enableScroll;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentConstrained({
    super.key,
    required this.child,
    this.maxWidth,
    this.enableScroll = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final targetMaxWidth = maxWidth ?? Responsive.maxDashboardWidth(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: 16.0,
        );

    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: targetMaxWidth),
        child: child,
      ),
    );

    if (enableScroll) {
      content = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: effectivePadding,
        child: content,
      );
    } else {
      content = Padding(
        padding: effectivePadding,
        child: content,
      );
    }

    return content;
  }
}
