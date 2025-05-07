import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../widgets/app_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '응급차와 일반 차량 선택',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            AppButton(
              text: '응급차 모드',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.emergencyVehicle);
              },
              backgroundColor: Theme.of(context).colorScheme.error,
              textColor: Colors.white,
              width: 200,
              icon: Icons.emergency,
            ),
            const SizedBox(height: 16),
            AppButton(
              text: '일반 차량 모드',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.regularVehicle);
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              textColor: Colors.white,
              width: 200,
              icon: Icons.directions_car,
            ),
          ],
        ),
      ),
    );
  }
}
