import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 추가
import 'package:provider/provider.dart';
import 'package:lifeline/viewmodels/emergency_vehicle_viewmodel.dart';
import 'package:lifeline/viewmodels/regular_vehicle_viewmodel.dart';
import 'package:lifeline/views/emergency_vehicle_screen.dart';
import 'package:lifeline/views/regular_vehicle_screen.dart';
import 'package:lifeline/services/shared_location_service.dart';

void main() {
  runApp(RestartWidget(child: const MyApp()));
}

// 🔥 앱 재시작을 위한 RestartWidget
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({Key? key, required this.child}) : super(key: key);

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 SharedLocationService 인스턴스 생성
    final sharedLocationService = SharedLocationService();

    return MultiProvider(
      providers: [
        // 🔥 SharedLocationService를 Provider에 등록
        ChangeNotifierProvider.value(value: sharedLocationService),

        // 🔥 ViewModel들을 앱 레벨에서 싱글톤으로 관리
        ChangeNotifierProvider(
          create: (_) => EmergencyVehicleViewModel()..initialize(),
          lazy: false, // 즉시 생성
        ),
        ChangeNotifierProvider(
          create: (_) => RegularVehicleViewModel(
            sharedLocationService: sharedLocationService,
          )..initialize(),
          lazy: false, // 즉시 생성
        ),
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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  // 🔥 각 탭의 위젯을 한 번만 생성하고 재사용
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🔥 페이지들을 미리 생성해서 재사용 (새로 생성하지 않음)
    _pages = [
      const EmergencyVehicleScreenContent(), // 🔥 새로운 Content 위젯 사용
      const RegularVehicleScreenContent(),   // 🔥 새로운 Content 위젯 사용
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('구급차 경로 알림 시스템'),
        // 🔥 미션 완료 버튼 추가 (응급 모드가 활성화되어 있을 때만 표시)
        actions: [
          Consumer<EmergencyVehicleViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.emergencyMode && viewModel.routePhase == 'hospital') {
                return IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _showMissionCompleteDialog(context, viewModel),
                  tooltip: '미션 완료',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages, // 🔥 미리 생성된 페이지들 사용
      ),
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

  // 🔥 미션 완료 다이얼로그
  void _showMissionCompleteDialog(BuildContext context, EmergencyVehicleViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚨 미션 완료'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('환자: ${viewModel.patientCondition} (${viewModel.patientSeverity})'),
              Text('병원: ${viewModel.hospitalLocation}'),
              const SizedBox(height: 10),
              const Text(
                '환자를 성공적으로 병원에 이송했습니다.\n새로운 임무를 시작하시겠습니까?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 🔥 앱 완전 재시작
                _restartApp();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('미션 완료'),
            ),
          ],
        );
      },
    );
  }

  // 🔥 앱 완전 재시작
  void _restartApp() {
    // 🔥 RestartWidget을 사용한 완전 재시작
    RestartWidget.restartApp(context);

    // 재시작 후 성공 메시지 표시
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 미션 완료! 새로운 임무를 시작하세요!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// 🔥 응급차량 화면의 Content 부분만 분리
class EmergencyVehicleScreenContent extends StatelessWidget {
  const EmergencyVehicleScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 이미 생성된 ViewModel 인스턴스 사용 (새로 생성하지 않음)
    return Consumer<EmergencyVehicleViewModel>(
      builder: (context, viewModel, child) {
        return EmergencyVehicleScreen(); // 기존 화면 내용 그대로 사용
      },
    );
  }
}

// 🔥 일반차량 화면의 Content 부분만 분리
class RegularVehicleScreenContent extends StatelessWidget {
  const RegularVehicleScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 이미 생성된 ViewModel 인스턴스 사용 (새로 생성하지 않음)
    return Consumer<RegularVehicleViewModel>(
      builder: (context, viewModel, child) {
        return RegularVehicleScreen(); // 기존 화면 내용 그대로 사용
      },
    );
  }
}