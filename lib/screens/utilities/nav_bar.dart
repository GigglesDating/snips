import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _showNavBar = true;
  bool _isSOSActive = false;
  late Size size;
  late PageController _pageController;
  final List<bool> _loadedTabs = List.generate(5, (index) => false);

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: widget.initialTab);
    _loadedTabs[widget.initialTab] = true; // Mark initial tab as loaded
    _hideSystemBars();

    // Add navigation state listener
    _pageController.addListener(_handlePageScroll);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _hideSystemBars();
    }
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;

    final page = _pageController.page;
    if (page == null) return;

    // Update navigation state based on scroll position
    if (page % 1 == 0) {
      _onPageChanged(page.toInt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    // Restore system UI when disposing
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _showNavBar = index != 1; // Hide nav bar for SwipeScreen
        _loadedTabs[index] = true; // Mark tab as loaded
      });

      // Ensure immersive mode is maintained
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // Main content with PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                return KeepAliveWidget(
                  active: _loadedTabs[index],
                  child: _navigationItems[index].builder(),
                );
              },
            ),

            // Navigation bar with SOS button
            if (_showNavBar)
              Positioned(
                bottom: bottomPadding,
                left: 0,
                right: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Main navigation bar
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: size.width * 0.05,
                        vertical: size.height * 0.015,
                      ),
                      height: size.height * 0.075,
                      child: Stack(
                        children: [
                          // SVG Background
                          Positioned.fill(
                            child: SvgPicture.asset(
                              'assets/app/nav.svg',
                              fit: BoxFit.fill,
                              colorFilter: ColorFilter.mode(
                                isDarkMode
                                    ? const Color(0xFF333333)
                                    : const Color(0xFF333333),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          // Icons Row
                          Center(
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
                        ],
                      ),
                    ),

                    // Floating SOS buttonr
                    Positioned(
                      top: -(size.height * 0.02),
                      child: _buildSOSButton(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String getIconPath(int index) {
    switch (index) {
      case 0:
        return 'assets/nav_bar/home.svg';
      case 1:
        return 'assets/nav_bar/swipe.svg';
      case 3:
        return 'assets/nav_bar/snips.svg';
      default:
        return 'assets/nav_bar/home.svg';
    }
  }

  Widget _buildNavItem(int index) {
    final isSelected = _currentIndex == index;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconSize = size.width * 0.1;

    if (index == 2) {
      return SizedBox(width: iconSize * 1.5);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isSelected ? iconSize * 1.2 : iconSize,
      height: isSelected ? iconSize * 1.2 : iconSize,
      child: GestureDetector(
        onTap: () => dummyNavigation(context, index),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isDarkMode
                    ? Colors.white.withAlpha(38)
                    : const Color.fromARGB(255, 255, 255, 255).withAlpha(26),
          ),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: isSelected ? 1.1 : 1.0,
              child: SvgPicture.asset(
                getIconPath(index),
                width: iconSize * 0.55,
                height: iconSize * 0.55,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? Colors.green
                      : (isDarkMode ? Colors.white : Colors.black),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(int index) {
    final isSelected = _currentIndex == index;
    final iconSize = size.width * 0.1;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 2,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/tempImages/users/user1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleSOSPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isSOSActive ? size.width * 0.2 : size.width * 0.17,
        height: _isSOSActive ? size.width * 0.2 : size.width * 0.17,
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
        child:
            _isSOSActive
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(size.width * 0.17),
                  child: OverflowBox(
                    maxWidth: size.width * 0.3,
                    maxHeight: size.width * 0.3,
                    child: Image.asset(
                      'assets/nav_bar/sos.gif',
                      fit: BoxFit.cover,
                      width: size.width * 0.3,
                      height: size.width * 0.3,
                    ),
                  ),
                )
                : Center(
                  child: SvgPicture.asset(
                    'assets/nav_bar/sos.svg',
                    width: size.width * 0.13,
                    height: size.width * 0.13,
                    colorFilter: ColorFilter.mode(
                      isDarkMode ? Colors.white : Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
      ),
    );
  }

  final List<({String label, Widget Function() builder})> _navigationItems = [
    (label: 'Home', builder: () => const Center(child: Text('Home'))),
    (label: 'Swipe', builder: () => const Center(child: Text('Swipe'))),
    (label: 'SOS', builder: () => const Center(child: Text('SOS'))),
    (label: 'Snips', builder: () => const Center(child: Text('Snips'))),
    (label: 'Profile', builder: () => const Center(child: Text('Profile'))),
  ];

  Future<void> _handleSOSPress() async {
    if (_isSOSActive) {
      // If SOS is currently active, stop everything immediately
      Vibration.cancel();
      setState(() => _isSOSActive = false);
    } else {
      // Start new SOS sequence
      setState(() => _isSOSActive = true);

      Future.delayed(const Duration(milliseconds: 500), () async {
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
      });
    }
  }
}

class KeepAliveWidget extends StatefulWidget {
  final bool active;
  final Widget child;

  const KeepAliveWidget({required this.active, required this.child, super.key});

  @override
  State<KeepAliveWidget> createState() => _KeepAliveWidgetState();
}

class _KeepAliveWidgetState extends State<KeepAliveWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.active;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.active ? widget.child : const SizedBox.shrink();
  }
}
