import 'package:flutter/material.dart';
import 'dart:math';

final Map<Color, Color> colorMap = {
  const Color(0xFFE08D79): Colors.black,
  const Color(0xFFA882DD): Colors.black,
  const Color(0xFF49416D): Colors.white,
};

List<Color> getRandomColor() {
  int randomIndex = Random().nextInt(colorMap.length);
  Color randomColor = colorMap.keys.elementAt(randomIndex);
  Color randomTextColor = colorMap.values.elementAt(randomIndex);

  return [randomColor, randomTextColor];
}

class HomeCard extends StatelessWidget {
  // Include a title string and a content Widget
  const HomeCard({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    List<Color> randomColors = getRandomColor();
    Color randomColor = randomColors[0];
    Color randomTextColor = randomColors[1];

    return Card(
      color: randomColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  color: randomTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: randomTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardButton extends StatefulWidget {
  const CardButton({super.key, required this.content, this.textSize = 16});

  final String content;
  final double textSize;

  @override
  State<CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<CardButton> {
  Color? randomColor;
  Color? randomTextColor;

  @override
  Widget build(BuildContext context) {
    if (randomColor == null) {
      List<Color> randomColors = getRandomColor();
      randomColor = randomColors[0];
      randomTextColor = randomColors[1];
    }

    randomColor = randomColor!.withOpacity(0.8);

    return TextButton(
      onPressed: () {},
      onFocusChange: (value) {
        setState(() {
          randomColor = randomColor!.withOpacity(value ? 1 : 0.5);
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: randomColor,
        foregroundColor: randomTextColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(widget.content,
          style: TextStyle(fontSize: widget.textSize, color: randomTextColor),
          textAlign: TextAlign.center),
    );
  }
}
