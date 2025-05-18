// views/regular_vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/emergency_vehicle_alert.dart';
import '../viewmodels/regular_vehicle_viewmodel.dart';

class RegularVehicleScreen extends StatelessWidget {
  const RegularVehicleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegularVehicleViewModel()..initialize(),
      child: const _RegularVehicleScreenContent(),
    );
  }
}

class _RegularVehicleScreenContent extends StatelessWidget {
  const _RegularVehicleScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ViewModel 인스턴스 가져오기
    final viewModel = Provider.of<RegularVehicleViewModel>(context);

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
                  // 실제 Google Map으로 교체
                  GoogleMap(
                    initialCameraPosition: viewModel.initialCameraPosition,
                    onMapCreated: (controller) {
                      viewModel.setMapController(controller);
                    },
                    markers: viewModel.markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  // 응급차량 경로 오버레이 (반투명 블루)
                  if (viewModel.showEmergencyAlert)
                    Container(color: Colors.blue.withOpacity(0.1)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 응급차량 접근 알림
          if (viewModel.showEmergencyAlert)
            EmergencyVehicleAlert(
              estimatedArrival: viewModel.estimatedArrival,
              approachDirection: viewModel.approachDirection,
              destination: viewModel.emergencyDestination,
              patientCondition: viewModel.patientCondition, // 추가
              patientSeverity: viewModel.patientSeverity, // 추가
              onDismiss: () => viewModel.dismissAlert(),
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
                              viewModel.currentLocation,
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
                              viewModel.currentSpeed,
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
                viewModel.showEmergencyAlert
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(viewModel.patientSeverity).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getSeverityColor(viewModel.patientSeverity).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: _getSeverityColor(viewModel.patientSeverity),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${viewModel.patientCondition} (${viewModel.patientSeverity}) 환자 이송 중',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getSeverityColor(viewModel.patientSeverity),
                                  ),
                                ),
                                const Text(
                                  '응급차량이 접근 중입니다. 우측으로 차량을 이동해 주세요.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  // 중증도에 따른 색상 반환 메서드
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case '경증':
        return Colors.green;
      case '중등':
        return Colors.orange;
      case '중증':
        return Colors.red;
      case '사망':
        return Colors.black;
      default:
        return Colors.blue;
    }
  }
}