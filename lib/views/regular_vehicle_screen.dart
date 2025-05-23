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
    final viewModel = Provider.of<RegularVehicleViewModel>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = 80.0;

    // 사용 가능한 화면 높이 계산
    final availableHeight = screenHeight - appBarHeight - statusBarHeight - bottomNavHeight;

    // 응급 알림 상태에 따른 지도 높이 조정
    final mapHeight = viewModel.showEmergencyAlert
        ? availableHeight * 0.45  // 응급 알림 있을 때는 45%
        : availableHeight * 0.65; // 평상시에는 65%

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

                // 위치 변경 버튼 (우측 상단)
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    elevation: 4,
                    child: const Icon(Icons.edit_location, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationSelectionScreen(
                            initialLocation: viewModel.currentLocationCoord,
                          ),
                        ),
                      );

                      if (result != null) {
                        await viewModel.updateLocation(result);
                      }
                    },
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
                // 🔥 응급차량 접근 알림 - 더 눈에 띄게 개선
                if (viewModel.showEmergencyAlert) ...[
                  EmergencyVehicleAlert(
                    estimatedArrival: viewModel.estimatedArrival,
                    approachDirection: viewModel.approachDirection,
                    destination: viewModel.emergencyDestination,
                    patientCondition: viewModel.patientCondition,
                    patientSeverity: viewModel.patientSeverity,
                    onDismiss: () => viewModel.dismissAlert(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 🔥 현재 상태 정보 컨테이너
                Container(
                  width: double.infinity,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 부분
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '현재 상태',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          // 위치 변경 버튼
                          _buildLocationChangeButton(context, viewModel),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 🔥 응급상황 정보 (있을 경우)
                      if (viewModel.showEmergencyAlert) ...[
                        _buildEmergencyInfoCard(viewModel),
                        const SizedBox(height: 14),
                      ],

                      // 🔥 현재 위치 및 속도 정보
                      _buildLocationSpeedInfo(viewModel),

                      const SizedBox(height: 14),

                      // 🔥 상태 메시지
                      _buildStatusMessage(viewModel),
                    ],
                  ),
                ),

                // 🔥 추가 정보나 팁 (응급상황이 없을 때)
                if (!viewModel.showEmergencyAlert) ...[
                  const SizedBox(height: 16),
                  _buildSafetyTipsCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 위치 변경 버튼
  Widget _buildLocationChangeButton(BuildContext context, RegularVehicleViewModel viewModel) {
    return TextButton.icon(
      icon: const Icon(Icons.edit_location_alt, size: 16),
      label: const Text('위치 변경', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        foregroundColor: Colors.blue,
        backgroundColor: Colors.blue.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () async {
        final result = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(
            builder: (context) => LocationSelectionScreen(
              initialLocation: viewModel.currentLocationCoord,
            ),
          ),
        );

        if (result != null) {
          await viewModel.updateLocation(result);
        }
      },
    );
  }

  // 🔥 응급상황 정보 카드
  Widget _buildEmergencyInfoCard(RegularVehicleViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '🚨 응급상황 정보',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('환자', '${viewModel.patientCondition} (${viewModel.patientSeverity})'),
          const SizedBox(height: 4),
          _buildInfoRow('목적지', viewModel.emergencyDestination),
          const SizedBox(height: 4),
          _buildInfoRow('예상 도착', viewModel.estimatedArrival),
        ],
      ),
    );
  }

  // 🔥 정보 행 빌더
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // 🔥 위치 및 속도 정보
  Widget _buildLocationSpeedInfo(RegularVehicleViewModel viewModel) {
    return Row(
      children: [
        // 위치 정보
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '내 위치',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  viewModel.currentLocation,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 속도 정보
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '속도',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  viewModel.currentSpeed,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 상태 메시지
  Widget _buildStatusMessage(RegularVehicleViewModel viewModel) {
    if (viewModel.showEmergencyAlert) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getSeverityColor(viewModel.patientSeverity).withAlpha((0.3 * 255).round()),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: _getSeverityColor(viewModel.patientSeverity),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${viewModel.patientCondition} (${viewModel.patientSeverity}) 환자 이송 중',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(viewModel.patientSeverity),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '응급차량이 접근 중입니다. 우측으로 차량을 이동해 주세요.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            const SizedBox(width: 8),
            Text(
              '주변에 응급상황이 없습니다.',
              style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
  }

  // 🔥 안전 운전 팁 카드 (응급상황이 없을 때)
  Widget _buildSafetyTipsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '안전 운전 팁',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTipItem('• 응급차량 사이렌이 들리면 즉시 우측으로 차선 변경'),
          _buildTipItem('• 교차로에서는 응급차량 우선 통행'),
          _buildTipItem('• 안전거리 유지로 급정거 상황 대비'),
        ],
      ),
    );
  }

  // 🔥 팁 아이템 빌더
  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        tip,
        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
      ),
    );
  }

  // 🔥 중증도에 따른 색상 반환
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