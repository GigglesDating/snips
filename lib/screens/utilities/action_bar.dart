import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ActionBarOrientation { vertical, horizontal }

class ActionBar extends StatelessWidget {
  final bool isDarkMode;
  final bool isLiked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final ActionBarOrientation orientation;
  final Color? backgroundColor;
  final double? width;
  final double? height;

  const ActionBar({
    super.key,
    required this.isDarkMode,
    required this.isLiked,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    this.orientation = ActionBarOrientation.vertical,
    this.backgroundColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.018,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDarkMode
                ? Colors.black.withAlpha(230)
                : Colors.white.withAlpha(230)),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withAlpha(38)
                  : Colors.black.withAlpha(26),
          width: 1,
        ),
      ),
      child:
          orientation == ActionBarOrientation.vertical
              ? Column(children: _buildActionButtons(screenWidth, screenHeight))
              : Row(children: _buildActionButtons(screenWidth, screenHeight)),
    );
  }

  List<Widget> _buildActionButtons(double screenWidth, double screenHeight) {
    final buttons = [
      _buildActionButton(
        iconPath: 'assets/feed/like.svg',
        onTap: () {
          HapticFeedback.lightImpact();
          onLikeTap();
        },
        color:
            isLiked
                ? Colors.red
                : (isDarkMode
                    ? Colors.white.withAlpha(204)
                    : Colors.black.withAlpha(204)),
        screenWidth: screenWidth,
      ),
      SizedBox(
        height:
            orientation == ActionBarOrientation.vertical
                ? screenHeight * 0.015
                : 0,
        width:
            orientation == ActionBarOrientation.horizontal
                ? screenWidth * 0.03
                : 0,
      ),
      _buildActionButton(
        iconPath: 'assets/feed/comment.svg',
        onTap: onCommentTap,
        color:
            isDarkMode
                ? Colors.white.withAlpha(204)
                : Colors.black.withAlpha(204),
        screenWidth: screenWidth,
      ),
      SizedBox(
        height:
            orientation == ActionBarOrientation.vertical
                ? screenHeight * 0.015
                : 0,
        width:
            orientation == ActionBarOrientation.horizontal
                ? screenWidth * 0.03
                : 0,
      ),
      _buildActionButton(
        iconPath: 'assets/feed/share.svg',
        onTap: onShareTap,
        color:
            isDarkMode
                ? Colors.white.withAlpha(204)
                : Colors.black.withAlpha(204),
        screenWidth: screenWidth,
      ),
    ];

    return buttons;
  }

  Widget _buildActionButton({
    required String iconPath,
    required VoidCallback onTap,
    required Color color,
    required double screenWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.025),
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? Colors.white.withAlpha(38)
                  : Colors.black.withAlpha(26),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          iconPath,
          width: screenWidth * 0.055,
          height: screenWidth * 0.055,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
