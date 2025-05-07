import 'package:flutter/material.dart';

class EmergencyVehicleScreen extends StatefulWidget {
  const EmergencyVehicleScreen({super.key});

  @override
  State<EmergencyVehicleScreen> createState() => _EmergencyVehicleScreenState();
}

class _EmergencyVehicleScreenState extends State<EmergencyVehicleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('응급차 모드')),
      body: const Center(child: Text('응급차 화면 구현 예정')),
    );
  }
}
