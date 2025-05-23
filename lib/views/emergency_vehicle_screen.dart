import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/route_info_card.dart';
import '../widgets/emergency_alert_card.dart';
import '../widgets/hospital_list_card.dart';
import '../viewmodels/emergency_vehicle_viewmodel.dart';

class EmergencyVehicleScreen extends StatelessWidget {
  const EmergencyVehicleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<EmergencyVehicleViewModel>(
      builder: (context, viewModel, child) {
        return const _EmergencyVehicleScreenContent();
      },
    );
  }
}

class _EmergencyVehicleScreenContent extends StatelessWidget {
  const _EmergencyVehicleScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<EmergencyVehicleViewModel>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = 80.0; // BottomNavigationBar 예상 높이

    // 사용 가능한 화면 높이 계산
    final availableHeight = screenHeight - appBarHeight - statusBarHeight - bottomNavHeight;

    // 지도 영역의 최소/최대 높이 설정
    final minMapHeight = availableHeight * 0.4; // 최소 40%
    final maxMapHeight = availableHeight * 0.7; // 최대 70%

    // 현재 상황에 따른 지도 높이 결정
    double mapHeight;
    if (viewModel.emergencyMode) {
      mapHeight = minMapHeight; // 응급 모드일 때는 더 많은 공간을 하단에
    } else if (viewModel.routePhase == 'hospital' && viewModel.recommendedHospitals.isNotEmpty) {
      mapHeight = minMapHeight; // 병원 목록이 있을 때
    } else {
      mapHeight = maxMapHeight; // 일반적인 경우
    }

    return Column(
      children: [
        // 🔥 지도 영역 - 고정 높이
        Container(
          height: mapHeight,
          margin: const EdgeInsets.all(16.0),
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
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  mapToolbarEnabled: true,
                ),

                // 🔥 응급 알림 표시 - 스크롤 가능하게 개선
                if (viewModel.showAlert)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: SingleChildScrollView(
                      child: EmergencyAlertCard(
                        message: "주변 차량 ${viewModel.notifiedVehicles}대에 알림이 전송되었습니다",
                        patientCondition: viewModel.patientCondition,
                        patientSeverity: viewModel.patientSeverity,
                      ),
                    ),
                  ),

                // 🔥 응급 모드 경로 정보 - 더 컴팩트하게
                if (viewModel.emergencyMode)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: RouteInfoCard(
                      destination: viewModel.routePhase == 'pickup'
                          ? viewModel.patientLocation
                          : viewModel.hospitalLocation,
                      routePhase: viewModel.routePhase,
                      estimatedTime: viewModel.estimatedTime,
                      notifiedVehicles: "${viewModel.notifiedVehicles}대",
                      patientCondition: viewModel.patientCondition,
                      patientSeverity: viewModel.patientSeverity,
                    ),
                  ),

                // 병원 검색 로딩
                if (viewModel.routePhase == 'hospital' && viewModel.isLoadingHospitals)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('최적 병원 검색 중...', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 🔥 하단 콘텐츠 영역 - 스크롤 가능
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // 🔥 병원 추천 목록 (지도 밖으로 이동)
                if (viewModel.routePhase == 'hospital' &&
                    viewModel.recommendedHospitals.isNotEmpty &&
                    !viewModel.emergencyMode) ...[
                  HospitalListCard(
                    hospitals: viewModel.recommendedHospitals,
                    selectedHospital: viewModel.selectedHospital,
                    patientCondition: viewModel.patientCondition,
                    patientSeverity: viewModel.patientSeverity,
                    onHospitalSelected: (hospital) {
                      viewModel.selectHospital(hospital);
                    },
                    availableRegions: viewModel.availableRegions,
                    selectedRegion: viewModel.selectedRegion,
                    onRegionChanged: (region) {
                      viewModel.changeRegion(region);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 🔥 입력 및 제어 영역
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.08 * 255).round()),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: !viewModel.emergencyMode
                      ? _buildDestinationInput(context, viewModel)
                      : _buildActiveEmergencyControls(context, viewModel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 목적지 입력 UI - 더 컴팩트하게 개선
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
            Expanded(
              child: Text(
                viewModel.routePhase == 'pickup' ? '환자 위치 설정' : '병원 위치 설정',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                viewModel.routePhase == 'pickup' ? '1단계: 환자 이동' : '2단계: 병원 이동',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 출발 위치 입력
        _buildInputField(
          label: '출발 위치',
          hintText: '출발 위치 입력 (예: 소방서 위치)',
          controller: viewModel.currentLocationController,
          enabled: viewModel.routePhase != 'hospital',
          filled: viewModel.routePhase == 'hospital',
          onChanged: (value) {
            if (viewModel.routePhase != 'hospital') {
              viewModel.updateCurrentLocation(value);
            }
          },
        ),

        const SizedBox(height: 14),

        // 목적지 입력
        _buildInputField(
          label: viewModel.routePhase == 'pickup' ? '환자 위치' : '병원 위치',
          hintText: viewModel.routePhase == 'pickup'
              ? '환자 위치 입력'
              : '병원 위치 입력 (또는 최적 병원 자동 추천)',
          controller: viewModel.routePhase == 'pickup'
              ? viewModel.patientLocationController
              : viewModel.hospitalLocationController,
          suffixIcon: viewModel.routePhase == 'hospital'
              ? Tooltip(
            message: '환자 상태에 맞는 최적 병원이 자동으로 추천됩니다',
            child: Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
          )
              : null,
          onChanged: (value) {
            if (viewModel.routePhase == 'pickup') {
              viewModel.updatePatientLocation(value);
            } else {
              viewModel.updateHospitalLocation(value);
            }
          },
        ),

        // 환자 상태 입력 (환자 픽업 단계에서만 표시)
        if (viewModel.routePhase == 'pickup') ...[
          const SizedBox(height: 14),

          // 환자 상태/병명 선택
          _buildDropdownField(
            label: '환자 상태',
            hint: '환자 상태 선택',
            value: viewModel.patientCondition.isEmpty ? null : viewModel.patientCondition,
            items: viewModel.patientConditionOptions,
            onChanged: (value) {
              if (value != null) {
                viewModel.updatePatientCondition(value);
              }
            },
          ),

          const SizedBox(height: 14),

          // 환자 중증도 선택
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '중증도',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Row(
                children: viewModel.patientSeverityOptions.map((severity) {
                  bool isSelected = viewModel.patientSeverity == severity;
                  Color backgroundColor = isSelected
                      ? _getSeverityColor(severity)
                      : Colors.grey[100]!;
                  Color textColor = isSelected ? Colors.white : Colors.black87;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () => viewModel.updatePatientSeverity(severity),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.grey[300]!,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            severity,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

        // 지역 정보 표시
        if (viewModel.routePhase == 'hospital' &&
            viewModel.selectedRegion != null &&
            viewModel.selectedRegion!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.blue[600]),
                const SizedBox(width: 4),
                Text(
                  '검색 지역: ${viewModel.selectedRegion!}',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (viewModel.routePhase == 'pickup' &&
                viewModel.patientLocation.isNotEmpty &&
                viewModel.currentLocation.isNotEmpty &&
                viewModel.patientCondition.isNotEmpty) ||
                (viewModel.routePhase == 'hospital' &&
                    ((viewModel.hospitalLocation.isNotEmpty) ||
                        (viewModel.selectedHospital != null)) &&
                    viewModel.patientLocationCoord != null)
                ? () => viewModel.activateEmergencyMode()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              viewModel.routePhase == 'pickup' ? '환자 이동 경로 알림' : '병원 이동 경로 알림',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 설명
        if (viewModel.routePhase == 'hospital') ...[
          const SizedBox(height: 8),
          Text(
            '환자 상태 기반으로 최적 병원이 자동 추천됩니다.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // 🔥 활성화된 응급 모드 UI - 더 컴팩트하게
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.red[600]),
                  const SizedBox(width: 4),
                  Text(
                    '진행 중',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[600]),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 환자 상태 정보
        if (viewModel.patientCondition.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.3 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(viewModel.patientSeverity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    viewModel.patientSeverity,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    viewModel.patientCondition,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 경로 표시
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildRoutePoint(
                Colors.green,
                viewModel.routePhase == 'pickup'
                    ? viewModel.currentLocation
                    : viewModel.patientLocation,
                false,
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                height: 12,
                child: const VerticalDivider(color: Colors.grey, thickness: 1, width: 1),
              ),
              _buildRoutePoint(
                Colors.red,
                viewModel.routePhase == 'pickup'
                    ? viewModel.patientLocation
                    : viewModel.hospitalLocation,
                true,
                region: viewModel.routePhase == 'hospital' &&
                    viewModel.selectedHospital != null &&
                    viewModel.selectedHospital!.region != null
                    ? viewModel.selectedHospital!.region!
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 버튼 영역
        if (viewModel.routePhase == 'pickup') ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => viewModel.switchToHospitalPhase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('환자 픽업 완료', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => viewModel.deactivateEmergencyMode(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('응급 상황 취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                viewModel.deactivateEmergencyMode();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('임무 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  // 🔥 입력 필드 빌더
  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool enabled = true,
    bool filled = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        TextField(
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(10),
            filled: filled,
            fillColor: filled ? Colors.grey[200] : null,
            suffixIcon: suffixIcon,
            isDense: true,
          ),
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  // 🔥 드롭다운 필드 빌더
  Widget _buildDropdownField({
    required String label,
    required String hint,
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: InputBorder.none,
              isDense: true,
            ),
            isExpanded: true,
            hint: Text(hint, style: const TextStyle(fontSize: 14)),
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 🔥 경로 포인트 빌더
  Widget _buildRoutePoint(Color color, String location, bool isDestination, {String? region}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isDestination ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (region != null)
                Text(
                  region,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 중증도에 따른 색상 반환
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case '경증': return Colors.green;
      case '중등': return Colors.orange;
      case '중증': return Colors.red;
      case '사망': return Colors.black;
      default: return Colors.blue;
    }
  }
}