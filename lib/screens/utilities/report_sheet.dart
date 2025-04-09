import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum ReportType { user, content }

class ReportSheet extends StatefulWidget {
  final bool isDarkMode;
  final double screenWidth;
  final VoidCallback? onReportComplete;
  final ReportType reportType;
  final String? contentType; // 'post', 'comment', 'snip', etc.

  const ReportSheet({
    super.key,
    required this.isDarkMode,
    required this.screenWidth,
    required this.reportType,
    this.contentType,
    this.onReportComplete,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  // Selected main option
  String? selectedMainOption;
  // Selected sub-option if any
  String? selectedSubOption;
  // For custom input
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  // User Report Options
  final Map<String, List<String>> userReportOptions = {
    'Bullying or unwanted contact': [],
    'Suicide, self-injury': [],
    'Nudity or sexuality': [],
    'Scam, fraud or spam': [],
    'False information': [],
    'Pretending to be someone else': [],
    'Selling or promoting restricted items': [],
    'Violence, hate or exploitation': [],
    'The user may be under 18 years': [],
    'Not these? Let us know what\'s wrong.': [],
  };

  // Content Report Options with sub-options
  final Map<String, List<String>> contentReportOptions = {
    'I just don\'t like it': [],
    'Threatening to share or sharing nude images': [],
    'Bullying or harassment': [],
    'Suicide, self-injury': [],
    'Nudity or sexual activity': [
      'Threatening to share or sharing nude images',
      'Seems like prostitution',
      'Seems like sexual exploitation',
      'Nudity or sexual activity',
    ],
    'Scam, fraud or spam': [],
    'Promoting False information': [
      'Health',
      'Politics',
      'Social issues',
      'Digitally created or altered',
    ],
    'Pretending to be someone else': ['Me', 'A friend / Someone I know'],
    'Selling or promoting restricted items': ['Drugs', 'Weapons', 'Animals'],
    'Violence, hate or exploitation': [
      'Credible threat to safety',
      'Seems like terrorism or organised crime',
      'Seems like exploitation',
      'Hate speech or symbols',
      'Calling for violence',
      'Showing violence, death or severe injury',
      'Animal abuse',
    ],
    'Not these? Let us know what\'s wrong.': [],
  };

  Map<String, List<String>> get currentOptions =>
      widget.reportType == ReportType.user
          ? userReportOptions
          : contentReportOptions;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _handleReport() async {
    if (selectedMainOption == null && !_showCustomInput) {
      Fluttertoast.showToast(
        msg: "Please select a reason for reporting",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
      return;
    }

    if (_showCustomInput && _customReasonController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: "Please provide details about your concern",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
      return;
    }

    // TODO: Implement the API call here
    // final response = await ReportService.submitReport({
    //   'type': widget.reportType.toString(),
    //   'contentType': widget.contentType,
    //   'mainReason': selectedMainOption,
    //   'subReason': selectedSubOption,
    //   'customReason': _showCustomInput ? _customReasonController.text : null,
    // });

    if (widget.onReportComplete != null) {
      widget.onReportComplete!();
    }

    if (mounted) {
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Thank you for your report. We'll review it shortly.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color:
                  widget.isDarkMode
                      ? Colors.black.withAlpha(230)
                      : Colors.white.withAlpha(230),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border.all(
                color:
                    widget.isDarkMode
                        ? Colors.white.withAlpha(38)
                        : Colors.black.withAlpha(26),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.reportType == ReportType.user
                        ? 'Report User'
                        : 'Report ${widget.contentType ?? 'Content'}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child:
                      selectedMainOption != null &&
                              currentOptions[selectedMainOption]!.isNotEmpty
                          ? _buildSubOptions()
                          : _buildMainOptions(),
                ),
                if (_showCustomInput) _buildCustomInput(),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainOptions() {
    return ListView.builder(
      itemCount: currentOptions.length,
      itemBuilder: (context, index) {
        final option = currentOptions.keys.elementAt(index);
        return ListTile(
          title: Text(
            option,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
          ),
          onTap: () {
            setState(() {
              selectedMainOption = option;
              selectedSubOption = null;
              _showCustomInput =
                  option == 'Not these? Let us know what\'s wrong.';
            });
          },
        );
      },
    );
  }

  Widget _buildSubOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            onPressed: () {
              setState(() {
                selectedMainOption = null;
                selectedSubOption = null;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: currentOptions[selectedMainOption]!.length,
            itemBuilder: (context, index) {
              final subOption = currentOptions[selectedMainOption]![index];
              return ListTile(
                title: Text(
                  subOption,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                trailing:
                    selectedSubOption == subOption
                        ? Icon(
                          Icons.check_circle,
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                        )
                        : null,
                onTap: () {
                  setState(() {
                    selectedSubOption = subOption;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _customReasonController,
        maxLines: 3,
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Please provide more details about your concern...',
          hintStyle: TextStyle(
            color: widget.isDarkMode ? Colors.white54 : Colors.black54,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor:
              widget.isDarkMode
                  ? Colors.white.withAlpha(38)
                  : Colors.black.withAlpha(26),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _handleReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
}
