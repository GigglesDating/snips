import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';

class ShareSheet extends StatelessWidget {
  final bool isDarkMode;
  final Map<String, dynamic> post;
  final double screenWidth;

  const ShareSheet({
    super.key,
    required this.isDarkMode,
    required this.post,
    required this.screenWidth,
  });

  void _shareContent(BuildContext context, String platform) {
    String shareText;
    String shareUrl;

    // Determine content type and create appropriate share text
    if (post['type'] == 'reel' || post['type'] == 'snip') {
      shareText = 'Check out this video on Giggles!';
      shareUrl = post['url'] ?? 'https://gigglesdating.com';
    } else {
      shareText = 'Check out this post on Giggles!';
      shareUrl = 'https://gigglesdating.com/post/${post['id']}';
    }

    final String fullShareText = '$shareText\n$shareUrl';

    switch (platform) {
      case 'whatsapp':
        Share.share(fullShareText, subject: 'Share via WhatsApp');
        break;
      case 'discord':
        Share.share(fullShareText, subject: 'Share via Discord');
        break;
      case 'copy_link':
        // Store the context in a final variable
        final currentContext = context;
        Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
          if (Navigator.canPop(currentContext)) {
            Navigator.pop(currentContext);
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
        break;
      case 'more':
        Share.share(fullShareText, subject: 'Share from Giggles');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.35,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.black.withAlpha(240)
                      : Colors.white.withAlpha(240),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border.all(
                color:
                    isDarkMode
                        ? Colors.white.withAlpha(38)
                        : Colors.black.withAlpha(26),
              ),
            ),
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
                    width: screenWidth * 0.1,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.white.withAlpha(77)
                              : Colors.black.withAlpha(77),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Share to',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: screenWidth * 0.04),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                    ),
                    children: [
                      _buildShareOption(
                        context,
                        icon: FontAwesomeIcons.whatsapp,
                        label: 'WhatsApp',
                        onTap: () => _shareContent(context, 'whatsapp'),
                      ),
                      _buildShareOption(
                        context,
                        icon: FontAwesomeIcons.discord,
                        label: 'Discord',
                        onTap: () => _shareContent(context, 'discord'),
                      ),
                      _buildShareOption(
                        context,
                        icon: Icons.link_rounded,
                        label: 'Copy Link',
                        onTap: () => _shareContent(context, 'copy_link'),
                      ),
                      _buildShareOption(
                        context,
                        icon: Icons.share,
                        label: 'More',
                        onTap: () => _shareContent(context, 'more'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white.withAlpha(38)
                      : Colors.black.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDarkMode ? Colors.white : Colors.black,
              size: screenWidth * 0.06,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ],
      ),
    );
  }
}
