import 'package:flutter/material.dart';

class FitmonColors {
  static const bg = Color(0xFF0B1526);
  static const bgDeep = Color(0xFF06080F);
  static const card = Color(0xFF131F35);
  static const cardAlt = Color(0xFF1A2D4A);
  static const line = Color(0x1AFFFFFF);
  static const green = Color(0xFF4D9846);
  static const greenLight = Color(0xFF81BE4C);
  static const yellow = Color(0xFFFFDE59);
  static const red = Color(0xFFEC0D18);
  static const cyan = Color(0xFF4ECEE0);
  static const pink = Color(0xFFFEA9AC);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9AAABB);
  static const soft = Color(0xFFE8EDF5);
}

BoxDecoration fitmonCard({
  Color color = FitmonColors.card,
  Color border = FitmonColors.line,
  double radius = 18,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );
}
