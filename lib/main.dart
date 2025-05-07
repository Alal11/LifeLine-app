import 'package:flutter/material.dart';
import 'screens/emergency_vehicle_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-MASS 응급차량 알림 시스템',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const EmergencyAppHome(),
    );
  }
}

class EmergencyAppHome extends StatefulWidget {
  const EmergencyAppHome({Key? key}) : super(key: key);

  @override
  _EmergencyAppHomeState createState() => _EmergencyAppHomeState();
}

class _EmergencyAppHomeState extends State<EmergencyAppHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 탭 바
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor:
                    _tabController.index == 0 ? Colors.red : Colors.blue,
                indicatorWeight: 3,
                labelColor:
                    _tabController.index == 0 ? Colors.red : Colors.blue,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                tabs: const [Tab(text: '응급차량 모드'), Tab(text: '일반차량 모드')],
              ),
            ),

            // 탭 콘텐츠
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  EmergencyVehicleScreen(),
                  Center(child: Text('일반차량 화면이 여기에 표시됩니다')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
