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
                        patientCondition: viewModel.patientCondition,
                        patientSeverity: viewModel.patientSeverity,
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
                        patientCondition: viewModel.patientCondition,
                        patientSeverity: viewModel.patientSeverity,
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
                  color: Colors.black.withAlpha((0.8 * 255).round()),
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

        // 출발 위치 입력
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '출발 위치',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            TextField(
              decoration: InputDecoration(
                hintText: '출발 위치 입력 (예: 소방서 위치)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                // 병원 이동 단계에서는 읽기 전용으로 설정
                filled: viewModel.routePhase == 'hospital',
                fillColor:
                    viewModel.routePhase == 'hospital'
                        ? Colors.grey[200]
                        : null,
              ),
              // 병원 이동 단계에서는 환자 위치로 고정하고 수정 불가능하도록 설정
              controller: TextEditingController(
                text: viewModel.currentLocation,
              ),
              enabled: viewModel.routePhase != 'hospital', // 병원 이동 단계에서는 비활성화
              onChanged: (value) {
                if (viewModel.routePhase != 'hospital') {
                  // 병원 이동 단계가 아닐 때만 수정 가능
                  viewModel.updateCurrentLocation(value);
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 목적지 입력
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              viewModel.routePhase == 'pickup' ? '환자 위치' : '병원 위치',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            TextField(
              decoration: InputDecoration(
                hintText:
                    viewModel.routePhase == 'pickup'
                        ? '환자 위치 입력 (예: 천안시 신부동 352-7)'
                        : '병원 위치 입력 (예: 천안충무병원 응급실)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
          ],
        ),

        // 환자 상태 입력 (환자 픽업 단계에서만 표시)
        if (viewModel.routePhase == 'pickup') ...[
          const SizedBox(height: 16),

          // 환자 상태/병명 선택
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '환자 상태',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: InputBorder.none,
                  ),
                  isExpanded: true,
                  hint: const Text('환자 상태 선택'),
                  value:
                      viewModel.patientCondition.isEmpty
                          ? null
                          : viewModel.patientCondition,
                  items:
                      viewModel.patientConditionOptions.map((condition) {
                        return DropdownMenuItem(
                          value: condition,
                          child: Text(condition),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.updatePatientCondition(value);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 환자 중증도 선택
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '중증도',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Row(
                children:
                    viewModel.patientSeverityOptions.map((severity) {
                      bool isSelected = viewModel.patientSeverity == severity;
                      Color backgroundColor =
                          isSelected
                              ? _getSeverityColor(severity)
                              : Colors.grey[100]!;
                      Color textColor =
                          isSelected ? Colors.white : Colors.black87;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap:
                                () => viewModel.updatePatientSeverity(severity),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.transparent
                                          : Colors.grey[300]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                severity,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (viewModel.routePhase == 'pickup' &&
                            viewModel.patientLocation.isNotEmpty &&
                            viewModel.currentLocation.isNotEmpty &&
                            viewModel.patientCondition.isNotEmpty) ||
                        (viewModel.routePhase == 'hospital' &&
                            viewModel.hospitalLocation.isNotEmpty &&
                            viewModel.currentLocation.isNotEmpty)
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

        // 환자 상태 정보 표시 (추가)
        if (viewModel.patientCondition.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getSeverityColor(
                viewModel.patientSeverity,
              ).withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getSeverityColor(
                  viewModel.patientSeverity,
                ).withAlpha((0.3 * 255).round()),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '환자 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getSeverityColor(viewModel.patientSeverity),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(viewModel.patientSeverity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        viewModel.patientSeverity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      viewModel.patientCondition,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
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
