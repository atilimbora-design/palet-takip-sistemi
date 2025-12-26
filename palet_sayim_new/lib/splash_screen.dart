import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart'; // To navigate to Dashboard/Entry
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _statusText = 'Veritabanı Hazırlanıyor...';

  @override
  void initState() {
    super.initState();

    // 5 Seconds total duration
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    // Animate from -100 (left offscreen) to Screen Width
    _controller.forward();

    // Text Updates
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _statusText = 'Sunucuya Bağlanılıyor...');
    });
    
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _statusText = 'Başlatılıyor...');
    });

    // Navigate when done
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Screen Width for animation
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // LOGO & TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  Image.asset('assets/images/splash_logo.png', height: 160),
                  const SizedBox(height: 16),
                  const Text(
                    'PALET TAKİP SİSTEMİ',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      color: Color(0xFF003366), // Dark Blue
                      letterSpacing: 1.5
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 3),
            
            // ANIMATION AREA
            SizedBox(
              height: 100, // Height for chicken and bar
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                   // Loading Bar Background
                   Positioned(
                     bottom: 0, left: 20, right: 20,
                     child: Container(
                       height: 6,
                       decoration: BoxDecoration(
                         color: Colors.grey.shade200,
                         borderRadius: BorderRadius.circular(3)
                       ),
                     )
                   ),
                   
                   // Loading Bar Progress (Animated with controller)
                   AnimatedBuilder(
                     animation: _controller,
                     builder: (context, child) {
                       return Positioned(
                         bottom: 0, left: 20,
                         width: (width - 40) * _controller.value,
                         child: Container(
                           height: 6,
                           decoration: BoxDecoration(
                             gradient: const LinearGradient(colors: [Colors.red, Colors.orange]),
                             borderRadius: BorderRadius.circular(3)
                           ),
                         ),
                       );
                     }
                   ),

                   // Walking Chicken
                   AnimatedBuilder(
                     animation: _controller,
                     builder: (context, child) {
                       // Move from left to right
                       final pos = (width - 80) * _controller.value;
                       
                       // Waddle Animation (Bobbing + Rotating)
                       final walkCycle = _controller.value * 20 * 3.14159; // Frequency
                       final bobY = -sin(walkCycle).abs() * 10; // Jump up 10px
                       final rotate = sin(walkCycle) * 0.1; // Rotate slighty
                       
                       return Positioned(
                         bottom: 8 + bobY.abs(), // Lift feet
                         left: 20 + pos,
                         child: Transform.rotate(
                           angle: rotate,
                           child: child!,
                         ),
                       );
                     },
                     child: Image.asset('assets/images/chicken.png', width: 45, height: 45),
                   ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // STATUS TEXT
            Text(
              _statusText,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),

            const Spacer(flex: 2),
            
            // FOOTER
            const Text(
              'Product: www.boraugur.com',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Wrapper to hold the main app logic (Providers etc if any, or just MainScreen)
// Actually main.dart likely has MaterialApp directly.
// We will replace 'home:' in main.dart
