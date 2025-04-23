import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
// import '../barrel.dart';

// Dummy navigation function
void dummyNavigation(BuildContext context, int index) {
  // Do nothing - navigation is temporarily disabled
  debugPrint('Navigation temporarily disabled');
}

class NavigationController extends StatefulWidget {
  final int initialTab;

  const NavigationController({super.key, this.initialTab = 0});

  // Add static method to handle navigation from child screens
  static void navigateToTab(BuildContext context, int index) {
    dummyNavigation(context, index);
  }

  @override
  State<NavigationController> createState() => NavigationControllerState();
}

class NavigationControllerState extends State<NavigationController>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _currentIndex;
  bool _isSOSActive = false;
  late Size size;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _hideSystemBars();
    }
  }

  void _hideSystemBars() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Empty array means hide all
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Calculate navigation bar dimensions
    final navBarHeight = size.height * 0.075;
    final navAreaHeight = navBarHeight + bottomPadding + size.height * 0.03;

    // IMPORTANT: This widget is now suitable for being placed inside other widgets
    return SizedBox(
      height: navAreaHeight,
      width: size.width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main navigation bar
          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical: size.height * 0.015,
              ),
              height: navBarHeight,
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? const Color(0xFF333333)
                        : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0),
                  _buildNavItem(1),
                  _buildNavItem(2),
                  _buildNavItem(3),
                  _buildProfileItem(4),
                ],
              ),
            ),
          ),

          // Floating SOS button
          Positioned(top: 0, child: _buildSOSButton()),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _currentIndex == index;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconSize = size.width * 0.1;

    if (index == 2) {
      return SizedBox(width: iconSize * 1.5);
    }

    return GestureDetector(
      onTap: () => dummyNavigation(context, index),
      behavior:
          HitTestBehavior.opaque, // Important for reliable touch detection
      child: Container(
        width: isSelected ? iconSize * 1.2 : iconSize,
        height: isSelected ? iconSize * 1.2 : iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isDarkMode
                  ? Colors.white.withAlpha(38)
                  : Colors.white.withAlpha(26),
        ),
        child: Center(
          child: Icon(
            _getIconData(index),
            size: iconSize * 0.55,
            color:
                isSelected
                    ? Colors.green
                    : (isDarkMode ? Colors.white : Colors.white),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.favorite;
      case 3:
        return Icons.video_library;
      default:
        return Icons.question_mark;
    }
  }

  Widget _buildProfileItem(int index) {
    final isSelected = _currentIndex == index;
    final iconSize = size.width * 0.1;

    return GestureDetector(
      onTap: () => dummyNavigation(context, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 2,
          ),
          color: Colors.grey[800],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSOSButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonSize = _isSOSActive ? size.width * 0.15 : size.width * 0.13;

    return GestureDetector(
      onTap: _handleSOSPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? const Color(0xFF121212)
                  : const Color.fromARGB(239, 239, 241, 241),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(239, 20, 20, 20).withAlpha(77),
              blurRadius: size.width * 0.02,
              spreadRadius: size.width * 0.002,
              offset: Offset(0, size.width * 0.01),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: buttonSize * 0.8,
            height: buttonSize * 0.8,
            decoration: BoxDecoration(
              color: _isSOSActive ? Colors.red : Colors.red.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSOSPress() async {
    HapticFeedback.heavyImpact();

    if (_isSOSActive) {
      // If SOS is currently active, stop everything immediately
      Vibration.cancel();
      setState(() => _isSOSActive = false);
    } else {
      // Start new SOS sequence
      setState(() => _isSOSActive = true);

      // Use a safer approach for long-running operations
      unawaited(_runSOSSequence());
    }
  }

  // Separate method to handle the SOS vibration sequence
  Future<void> _runSOSSequence() async {
    while (_isSOSActive) {
      // S (... = 3 short vibrations)
      for (var i = 0; i < 3; i++) {
        if (!_isSOSActive) return; // Check before each vibration
        await Vibration.vibrate(duration: 200, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!_isSOSActive) return;
      await Future.delayed(const Duration(milliseconds: 400));

      // O (--- = 3 long vibrations)
      for (var i = 0; i < 3; i++) {
        if (!_isSOSActive) return; // Check before each vibration
        await Vibration.vibrate(duration: 500, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!_isSOSActive) return;
      await Future.delayed(const Duration(milliseconds: 400));

      // S (... = 3 short vibrations)
      for (var i = 0; i < 3; i++) {
        if (!_isSOSActive) return; // Check before each vibration
        await Vibration.vibrate(duration: 200, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!_isSOSActive) return;
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}

// Helper function to handle unawaited futures
void unawaited(Future<void> future) {
  // This ignores the future but catches any errors
  future.catchError((error, stackTrace) {
    debugPrint('Error in unawaited future: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}
