import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/emergency_vehicle_alert.dart';
import '../viewmodels/regular_vehicle_viewmodel.dart';
import '../views/location_selection_screen.dart';

class RegularVehicleScreen extends StatelessWidget {
  const RegularVehicleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 이미 생성된 ViewModel 사용 (새로 생성하지 않음)
    return Consumer<RegularVehicleViewModel>(
      builder: (context, viewModel, child) {
        return const _RegularVehicleScreenContent();
      },
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
                  // Google Map
                  GestureDetector(
                    onTap: () {
                      // 지도 탭 이벤트 처리
                    },
                    child: GoogleMap(
                      initialCameraPosition: viewModel.initialCameraPosition,
                      onMapCreated: (controller) {
                        viewModel.setMapController(controller);
                      },
                      markers: viewModel.markers,
                      polylines: viewModel.polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      mapToolbarEnabled: true,
                    ),
                  ),

                  // 위치 변경 버튼 추가 (우측 상단)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      child: const Icon(Icons.edit_location),
                      onPressed: () async {
                        // LocationSelectionScreen으로 이동
                        print('위치 변경 버튼 클릭됨'); // 디버깅용 로그 추가
                        final result = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LocationSelectionScreen(
                              initialLocation: viewModel.currentLocationCoord,
                            ),
                          ),
                        );

                        // 위치가 선택되었다면 ViewModel 업데이트
                        if (result != null) {
                          print('선택된 위치: $result'); // 디버깅용 로그 추가
                          await viewModel.updateLocation(result);
                          print('위치 업데이트 완료'); // 디버깅용 로그 추가
                        } else {
                          print('위치가 선택되지 않음'); // 디버깅용 로그 추가
                        }
                      },
                    ),
                  ),
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
              patientCondition: viewModel.patientCondition,
              patientSeverity: viewModel.patientSeverity,
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
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '현재 상태',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    // 위치 변경 버튼 추가
                    TextButton.icon(
                      icon: const Icon(Icons.edit_location_alt, size: 16),
                      label: const Text('위치 변경', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        // LocationSelectionScreen으로 이동
                        print('하단 위치 변경 버튼 클릭됨'); // 디버깅용 로그 추가
                        final result = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LocationSelectionScreen(
                              initialLocation: viewModel.currentLocationCoord,
                            ),
                          ),
                        );

                        // 위치가 선택되었다면 ViewModel 업데이트
                        if (result != null) {
                          print('선택된 위치: $result'); // 디버깅용 로그 추가
                          await viewModel.updateLocation(result);
                          print('위치 업데이트 완료'); // 디버깅용 로그 추가
                        } else {
                          print('위치가 선택되지 않음'); // 디버깅용 로그 추가
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔥 응급차량 정보가 있으면 추가로 표시
                if (viewModel.showEmergencyAlert) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🚨 응급상황 정보',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('환자: ${viewModel.patientCondition} (${viewModel.patientSeverity})'),
                        Text('목적지: ${viewModel.emergencyDestination}'),
                        Text('예상 도착: ${viewModel.estimatedArrival}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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
                              maxLines: 2, // 주소가 길 경우 2줄까지 표시
                              overflow: TextOverflow.ellipsis, // 넘칠 경우 ... 표시
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
                        color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.3 * 255).round()),
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