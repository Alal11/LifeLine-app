import 'package:flutter/material.dart';

class RegularVehicleScreen extends StatefulWidget {
  const RegularVehicleScreen({super.key});

  @override
  State<RegularVehicleScreen> createState() => _RegularVehicleScreenState();
}

class _RegularVehicleScreenState extends State<RegularVehicleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일반 차량 모드')),
      body: const Center(child: Text('일반 차량 화면 구현 예정')),
    );
  }
}
