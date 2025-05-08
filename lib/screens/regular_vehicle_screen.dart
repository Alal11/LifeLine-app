import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/emergency_vehicle_alert.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/shared_service.dart';

class RegularVehicleScreen extends StatefulWidget {
  const RegularVehicleScreen({Key? key}) : super(key: key);

  @override
  _RegularVehicleScreenState createState() => _RegularVehicleScreenState();
}

class _RegularVehicleScreenState extends State<RegularVehicleScreen> {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

  // 상태 변수들
  bool _showEmergencyAlert = false;
  String _currentLocation = '강남구 행복동로';
  String _currentSpeed = '0 km/h';

  // 알림 정보
  String _estimatedArrival = '';
  String _approachDirection = '';
  String _emergencyDestination = '';

  // 위치 구독
  StreamSubscription? _locationSubscription;
  StreamSubscription? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _subscribeToEmergencyAlerts();
  }

// 위치 초기화 및 구독
  Future<void> _initializeLocation() async {
    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentLocation();

      // 위치 스트림 구독
      _locationSubscription = _locationService.getPositionStream().listen((position) {
        if (mounted) {
          setState(() {
            // 속도 업데이트 (km/h로 변환)
            _currentSpeed = '${(position.speed * 3.6).round()} km/h';
          });
        }
      });

    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

// 응급차량 알림 구독
  void _subscribeToEmergencyAlerts() {
    // 공유 서비스로부터 응급 알림 구독
    final sharedService = SharedService();
    _alertSubscription = sharedService.emergencyAlertStream.listen((data) {
      if (mounted) {
        if (data['active'] == true) {
          setState(() {
            _showEmergencyAlert = true;
            _estimatedArrival = data['estimatedTime'];
            _approachDirection = data['approachDirection'];
            _emergencyDestination = data['destination'];

            // 알림 표시 시 효과음 재생
            _notificationService.playAlertSound();
          });
        } else {
          setState(() {
            _showEmergencyAlert = false;
          });
        }
      }
    });

    // 기존 알림 서비스 구독 (백그라운드 알림용)
    _notificationService.getEmergencyAlerts().listen((alertData) {
      if (mounted && !_showEmergencyAlert) {
        setState(() {
          _showEmergencyAlert = true;
          _estimatedArrival = alertData['message'].split('분').first + '분 이내';
          _approachDirection = alertData['approach_direction'];
          _emergencyDestination = alertData['destination'];
        });

        // 알림 효과음 재생
        _notificationService.playAlertSound();
      }
    });
  }

// 알림 닫기
  void _dismissAlert() {
    setState(() {
      _showEmergencyAlert = false;
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
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
                  // 지도 배경 (실제 지도 대신 더미 배경)
                  Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        '지도가 여기에 표시됩니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                  // 응급차량 경로 오버레이 (반투명 블루)
                  if (_showEmergencyAlert)
                    Container(color: Colors.blue.withOpacity(0.1)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 응급차량 접근 알림
          if (_showEmergencyAlert)
            EmergencyVehicleAlert(
              estimatedArrival: _estimatedArrival,
              approachDirection: _approachDirection,
              destination: _emergencyDestination,
              onDismiss: _dismissAlert,
            ),

          const SizedBox(height: 16),

          // 현재 상태 정보
          Container(
            width: double.infinity,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '현재 상태',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // 상태 정보 표시
                Row(
                  children: [
                    // 위치 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '내 위치',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentLocation,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 속도 정보
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '속도',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentSpeed,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 상태 메시지
                _showEmergencyAlert
                    ? const Text(
                      '응급차량이 접근 중입니다. 우측으로 차량을 이동해 주세요.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    )
                    : Text(
                      '주변에 응급상황이 없습니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
