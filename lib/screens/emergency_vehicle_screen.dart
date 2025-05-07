import 'package:flutter/material.dart';
import '../widgets/route_info_card.dart';
import '../widgets/emergency_alert_card.dart';
import '../models/emergency_route.dart';

class EmergencyVehicleScreen extends StatefulWidget {
  const EmergencyVehicleScreen({Key? key}) : super(key: key);

  @override
  _EmergencyVehicleScreenState createState() => _EmergencyVehicleScreenState();
}

class _EmergencyVehicleScreenState extends State<EmergencyVehicleScreen> {
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

  @override
  void initState() {
    super.initState();
  }

  // 응급 모드 활성화 (더미 구현)
  void _activateEmergencyMode() {
    if (_routePhase == 'pickup' && _patientLocation.isNotEmpty) {
      _destination = _patientLocation;
      _calculateDummyRoute();
    } else if (_routePhase == 'hospital' && _hospitalLocation.isNotEmpty) {
      _destination = _hospitalLocation;
      _calculateDummyRoute();
    }
  }

  // 더미 경로 계산
  void _calculateDummyRoute() {
    setState(() {
      _emergencyMode = true;
    });

    // 알림 효과 시뮬레이션
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showAlert = true;
        });
      }
    });
  }

  // 응급 모드 비활성화
  void _deactivateEmergencyMode() {
    setState(() {
      _emergencyMode = false;
      _showAlert = false;
    });
  }

  // 환자 픽업 완료 후 병원 단계로 전환
  void _switchToHospitalPhase() {
    setState(() {
      _routePhase = 'hospital';
      _emergencyMode = false;
      _showAlert = false;
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
                        estimatedTime: "12분",
                        notifiedVehicles: "27대",
                      ),
                    ),

                  // 응급 알림 표시
                  if (_showAlert)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: const EmergencyAlertCard(
                        message: "주변 차량 27대에 알림이 전송되었습니다",
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
