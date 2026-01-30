import 'package:flutter/material.dart';

import '../../data/models/memo_location.dart';

class MemoLocationLine extends StatelessWidget {
  const MemoLocationLine({
    super.key,
    required this.location,
    required this.textColor,
    this.onTap,
    this.fontSize = 11,
  });

  final MemoLocation location;
  final Color textColor;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final display = location.displayText(fractionDigits: 6);
    if (display.trim().isEmpty) return const SizedBox.shrink();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.place_outlined, size: fontSize + 2, color: textColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}
