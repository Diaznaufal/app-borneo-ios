import 'package:flutter/material.dart';

class ScreenCheckWrapper extends StatelessWidget {
  final Widget child;

  const ScreenCheckWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    // Batas 600dp adalah standar tablet 10 inci
    if (shortestSide < 600) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Aplikasi ini hanya dapat dijalankan pada perangkat tablet 10 inci ke atas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}