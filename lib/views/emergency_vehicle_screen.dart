import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/route_info_card.dart';
import '../widgets/emergency_alert_card.dart';
import '../viewmodels/emergency_vehicle_viewmodel.dart';

class EmergencyVehicleScreen extends StatelessWidget {
  const EmergencyVehicleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmergencyVehicleViewModel()..initialize(),
      child: const _EmergencyVehicleScreenContent(),
    );
  }
}

class _EmergencyVehicleScreenContent extends StatelessWidget {
  const _EmergencyVehicleScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ViewModel 인스턴스 가져오기
    final viewModel = Provider.of<EmergencyVehicleViewModel>(context);

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
                  GoogleMap(
                    initialCameraPosition: viewModel.initialCameraPosition,
                    onMapCreated: (controller) {
                      viewModel.setMapController(controller);
                    },
                    markers: viewModel.markers,
                    polylines: viewModel.polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  // 응급 모드 활성화 시 경로 정보 카드
                  if (viewModel.emergencyMode)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: RouteInfoCard(
                        destination:
                            viewModel.routePhase == 'pickup'
                                ? viewModel.patientLocation
                                : viewModel.hospitalLocation,
                        routePhase: viewModel.routePhase,
                        estimatedTime: viewModel.estimatedTime,
                        notifiedVehicles: "${viewModel.notifiedVehicles}대",
                      ),
                    ),

                  // 응급 알림 표시
                  if (viewModel.showAlert)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: EmergencyAlertCard(
                        message:
                            "주변 차량 ${viewModel.notifiedVehicles}대에 알림이 전송되었습니다",
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
                !viewModel.emergencyMode
                    ? _buildDestinationInput(context, viewModel)
                    : _buildActiveEmergencyControls(context, viewModel),
          ),
        ],
      ),
    );
  }

  // 목적지 입력 UI
  Widget _buildDestinationInput(
    BuildContext context,
    EmergencyVehicleViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              viewModel.routePhase == 'pickup' ? '환자 위치 설정' : '병원 위치 설정',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                viewModel.routePhase == 'pickup' ? '1단계: 환자 이동' : '2단계: 병원 이동',
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
                viewModel.routePhase == 'pickup'
                    ? viewModel.currentLocation
                    : '${viewModel.patientLocation} (환자 위치)',
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
                viewModel.routePhase == 'pickup'
                    ? '환자 위치 입력 (예: 강남역 2번 출구)'
                    : '병원 위치 입력 (예: 서울대병원 응급실)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: (value) {
            if (viewModel.routePhase == 'pickup') {
              viewModel.updatePatientLocation(value);
            } else {
              viewModel.updateHospitalLocation(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (viewModel.routePhase == 'pickup' &&
                            viewModel.patientLocation.isNotEmpty) ||
                        (viewModel.routePhase == 'hospital' &&
                            viewModel.hospitalLocation.isNotEmpty)
                    ? () => viewModel.activateEmergencyMode()
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
              viewModel.routePhase == 'pickup' ? '환자 이동 경로 알림' : '병원 이동 경로 알림',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // 활성화된 응급 모드 UI
  Widget _buildActiveEmergencyControls(
    BuildContext context,
    EmergencyVehicleViewModel viewModel,
  ) {
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
                    viewModel.routePhase == 'pickup'
                        ? viewModel.currentLocation
                        : viewModel.patientLocation,
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
                    viewModel.routePhase == 'pickup'
                        ? viewModel.patientLocation
                        : viewModel.hospitalLocation,
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
            if (viewModel.routePhase == 'pickup')
              Expanded(
                child: ElevatedButton(
                  onPressed: () => viewModel.switchToHospitalPhase(),
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
            if (viewModel.routePhase == 'pickup') const SizedBox(width: 12),

            // 응급 상황 종료/취소 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: () => viewModel.deactivateEmergencyMode(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  viewModel.routePhase == 'hospital' ? '임무 완료' : '응급 상황 취소',
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
