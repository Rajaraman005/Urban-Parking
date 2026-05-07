import 'package:flutter/material.dart';

class AvailabilityFieldLabel extends StatelessWidget {
  const AvailabilityFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF0B0B0C),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
  }
}
