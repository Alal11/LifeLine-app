import 'package:flutter/material.dart';
import '../widgets/route_info_card.dart';
import '../widgets/emergency_alert_card.dart';
import '../models/emergency_route.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/notification_service.dart';
import '../services/shared_service.dart';

class EmergencyVehicleScreen extends StatefulWidget {
  const EmergencyVehicleScreen({Key? key}) : super(key: key);

  @override
  _EmergencyVehicleScreenState createState() => _EmergencyVehicleScreenState();
}

class _EmergencyVehicleScreenState extends State<EmergencyVehicleScreen> {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final NotificationService _notificationService = NotificationService();

  // 상태 변수들
  bool _emergencyMode = false;
  String _destination = '';
  bool _showAlert = false;
  EmergencyRouteStatus _routeStatus = EmergencyRouteStatus.ready;

  // 구급차 경로 정보
  String _currentLocation = '소방서 (강남119안전센터)';
  String _patientLocation = '';
  String _hospitalLocation = '';
  String _routePhase = 'pickup'; // 'pickup' 또는 'hospital'

  // 경로 정보
  EmergencyRoute? _currentRoute;
  String _estimatedTime = '계산 중...';
  int _notifiedVehicles = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadSharedState();
  }

  // 위치 초기화
  Future<void> _initializeLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          // 위치 서비스로부터 현재 위치 갱신 가능
          // 지금은 더미 위치를 계속 사용
        });
      }
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 공유 상태 로드
  void _loadSharedState() {
    final sharedService = SharedService();

    // 저장된 환자 및 병원 위치 불러오기
    setState(() {
      _patientLocation = sharedService.patientLocation;
      _hospitalLocation = sharedService.hospitalLocation;
      _routePhase = sharedService.routePhase;

      // 응급 모드가 활성화되어 있으면 상태 복원
      if (sharedService.isEmergencyActive) {
        _emergencyMode = true;
        _estimatedTime = sharedService.estimatedTime;
        _notifiedVehicles = sharedService.notifiedVehicles;
        _showAlert = true;

        // 현재 경로 단계에 따라 목적지 설정
        if (_routePhase == 'pickup') {
          _destination = _patientLocation;
        } else {
          _destination = _hospitalLocation;
        }
      }
    });
  }

  // 응급 모드 활성화
  void _activateEmergencyMode() async {
    if (_routePhase == 'pickup' && _patientLocation.isNotEmpty) {
      _destination = _patientLocation;
      await _calculateAndActivateRoute();
    } else if (_routePhase == 'hospital' && _hospitalLocation.isNotEmpty) {
      _destination = _hospitalLocation;
      await _calculateAndActivateRoute();
    }
  }

// 경로 계산 및 알림 활성화
  Future<void> _calculateAndActivateRoute() async {
    setState(() {
      _emergencyMode = true;
    });

    try {
      // 더미 시작점과 도착점 생성 (실제로는 실제 좌표 사용)
      final LatLng origin = LatLng(37.498095, 127.027610);
      LatLng destination;
      String destinationName;

      if (_routePhase == 'pickup') {
        destination = LatLng(37.504890, 127.049132); // 더미 환자 위치
        destinationName = _patientLocation;
      } else {
        destination = LatLng(37.582670, 127.050630); // 더미 병원 위치
        destinationName = _hospitalLocation;
      }

      // 경로 데이터 계산
      final routeData = await _routeService.calculateOptimalRoute(
          origin,
          destination,
          isEmergency: true
      );

      // 주변 차량에 알림 전송
      final notifiedCount = await _notificationService.sendEmergencyAlertToNearbyVehicles(
          'dummy_route_id',
          '응급차량이 접근 중입니다. 길을 비켜주세요.',
          1.0 // 1km 반경
      );

      if (mounted) {
        setState(() {
          _estimatedTime = routeData['estimated_time'] as String;
          _notifiedVehicles = notifiedCount;
          _showAlert = true;
        });
      }

      // 공유 서비스를 통해 알림 전파
      final sharedService = SharedService();
      sharedService.broadcastEmergencyAlert(
        destination: destinationName,
        estimatedTime: _estimatedTime,
        approachDirection: _routePhase == 'pickup' ? '소방서에서 환자 방향' : '환자에서 병원 방향',
        notifiedVehicles: _notifiedVehicles,
      );

    } catch (e) {
      print('경로 활성화 중 오류 발생: $e');

      if (mounted) {
        setState(() {
          _emergencyMode = false;
          _showAlert = false;
        });
      }
    }
  }

// 응급 모드 비활성화
  void _deactivateEmergencyMode() {
    setState(() {
      _emergencyMode = false;
      _showAlert = false;
    });

    // 공유 서비스를 통해 알림 취소
    final sharedService = SharedService();
    sharedService.cancelEmergencyAlert();
  }

// 환자 픽업 완료 후 병원 단계로 전환
  void _switchToHospitalPhase() {
    // 먼저 현재 응급 모드 비활성화
    _deactivateEmergencyMode();

    setState(() {
      _routePhase = 'hospital';
      _currentLocation = '$_patientLocation (환자 위치)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 지도 영역
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 지도 영역 (실제 지도 대신 더미 배경)
                  Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        '지도가 여기에 표시됩니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                  // 응급 모드 활성화 시 경로 정보 카드
                  if (_emergencyMode)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: RouteInfoCard(
                        destination: _destination,
                        routePhase: _routePhase,
                        estimatedTime: _estimatedTime,
                        notifiedVehicles: "$_notifiedVehicles대",
                      ),
                    ),

                  // 응급 알림 표시
                  if (_showAlert)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: EmergencyAlertCard(
                        message: "주변 차량 $_notifiedVehicles대에 알림이 전송되었습니다",
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 입력 및 제어 영역
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child:
                !_emergencyMode
                    ? _buildDestinationInput()
                    : _buildActiveEmergencyControls(),
          ),
        ],
      ),
    );
  }

  // 목적지 입력 UI
  Widget _buildDestinationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _routePhase == 'pickup' ? '환자 위치 설정' : '병원 위치 설정',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _routePhase == 'pickup' ? '1단계: 환자 이동' : '2단계: 병원 이동',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 현재 위치 표시
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 위치',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _routePhase == 'pickup'
                    ? _currentLocation
                    : '$_patientLocation (환자 위치)',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 목적지 입력
        TextField(
          decoration: InputDecoration(
            hintText:
                _routePhase == 'pickup'
                    ? '환자 위치 입력 (예: 강남역 2번 출구)'
                    : '병원 위치 입력 (예: 서울대병원 응급실)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: (value) {
            setState(() {
              if (_routePhase == 'pickup') {
                _patientLocation = value;
              } else {
                _hospitalLocation = value;
              }
            });
          },
        ),

        const SizedBox(height: 16),

        // 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (_routePhase == 'pickup' && _patientLocation.isNotEmpty) ||
                        (_routePhase == 'hospital' &&
                            _hospitalLocation.isNotEmpty)
                    ? _activateEmergencyMode
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              _routePhase == 'pickup' ? '환자 이동 경로 알림' : '병원 이동 경로 알림',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // 활성화된 응급 모드 UI
  Widget _buildActiveEmergencyControls() {
    return Column(
      children: [
        // 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '응급 모드 활성화됨',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.red[600]),
                  const SizedBox(width: 4),
                  Text(
                    '진행 중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 경로 표시
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // 출발지
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _routePhase == 'pickup'
                        ? _currentLocation
                        : _patientLocation,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),

              // 경로 선
              Container(
                margin: const EdgeInsets.only(left: 8),
                height: 16,
                child: const VerticalDivider(
                  color: Colors.grey,
                  thickness: 1,
                  width: 1,
                ),
              ),

              // 목적지
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _routePhase == 'pickup'
                        ? _patientLocation
                        : _hospitalLocation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 버튼 영역
        Row(
          children: [
            // 환자 픽업 완료 버튼 (환자 이동 단계에서만 표시)
            if (_routePhase == 'pickup')
              Expanded(
                child: ElevatedButton(
                  onPressed: _switchToHospitalPhase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '환자 픽업 완료',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // 간격
            if (_routePhase == 'pickup') const SizedBox(width: 12),

            // 응급 상황 종료/취소 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: _deactivateEmergencyMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _routePhase == 'hospital' ? '임무 완료' : '응급 상황 취소',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
