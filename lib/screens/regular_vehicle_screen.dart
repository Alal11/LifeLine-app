import 'package:flutter/material.dart';
import '../widgets/emergency_vehicle_alert.dart';

class RegularVehicleScreen extends StatefulWidget {
  const RegularVehicleScreen({Key? key}) : super(key: key);

  @override
  _RegularVehicleScreenState createState() => _RegularVehicleScreenState();
}

class _RegularVehicleScreenState extends State<RegularVehicleScreen> {
  // 상태 변수들
  bool _showEmergencyAlert = true;
  String _currentLocation = '강남구 행복동로';
  String _currentSpeed = '32 km/h';

  @override
  void initState() {
    super.initState();
  }

  // 알림 닫기
  void _dismissAlert() {
    setState(() {
      _showEmergencyAlert = false;
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
              estimatedArrival: '2분 이내',
              approachDirection: '동남쪽에서 북서쪽',
              destination: '서울대병원 응급실',
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
