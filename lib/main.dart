import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/viewmodels/emergency_vehicle_viewmodel.dart';
import 'package:lifeline/viewmodels/regular_vehicle_viewmodel.dart';
import 'package:lifeline/views/emergency_vehicle_screen.dart';
import 'package:lifeline/views/regular_vehicle_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ViewModel들을 여기에 등록합니다
        ChangeNotifierProvider(create: (_) => EmergencyVehicleViewModel()),
        ChangeNotifierProvider(create: (_) => RegularVehicleViewModel()),
      ],
      child: MaterialApp(
        title: '구급차 경로 알림 시스템',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const EmergencyVehicleScreen(),
    RegularVehicleScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구급차 경로 알림 시스템')),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: '응급 차량',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: '일반 차량',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
