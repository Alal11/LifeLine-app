import 'package:flutter/material.dart';
import '../services/hospital_service.dart';

class HospitalListCard extends StatelessWidget {
  final List<Hospital> hospitals;
  final Hospital? selectedHospital;
  final String patientCondition;
  final String patientSeverity;
  final Function(Hospital) onHospitalSelected;
  final List<String> availableRegions; // 추가
  final String? selectedRegion; // 추가
  final Function(String) onRegionChanged; // 추가

  const HospitalListCard({
    Key? key,
    required this.hospitals,
    required this.selectedHospital,
    required this.patientCondition,
    required this.patientSeverity,
    required this.onHospitalSelected,
    this.availableRegions = const [], // 기본값 추가
    this.selectedRegion, // 기본값 추가
    required this.onRegionChanged, // 추가
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.local_hospital, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  '추천 병원',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(patientSeverity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    patientSeverity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  patientCondition,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                // 정렬 옵션 (시간, 거리, 병상 수 등)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.blue),
                      const SizedBox(width: 2),
                      Text(
                        '소요시간순',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 지역 필터 추가
            if (availableRegions.isNotEmpty) ...[
              const SizedBox(height: 8), // 간격 줄임 (12 -> 8)
              Container(
                height: 32, // 높이 줄임 (40 -> 32)
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableRegions.length + 1, // "전체" 옵션 추가
                  itemBuilder: (context, index) {
                    final String region = index == 0 ? '전체' : availableRegions[index - 1];
                    final isSelected = selectedRegion == region ||
                        (index == 0 && selectedRegion == null);

                    return GestureDetector(
                      onTap: () => onRegionChanged(region),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12), // 패딩 줄임 (16 -> 12)
                        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3), // 마진 줄임
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(12), // 라운드 줄임 (16 -> 12)
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey[300]!,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          region,
                          style: TextStyle(
                            fontSize: 11, // 폰트 사이즈 줄임 (12 -> 11)
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 8), // 간격 줄임 (12 -> 8)

            // 병원 목록
            SizedBox(
              height: 120, // 목록의 최대 높이를 줄임 (200 -> 120)
              child: ListView.builder(
                itemCount: hospitals.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final hospital = hospitals[index];
                  final isSelected = selectedHospital == hospital;

                  return InkWell(
                    onTap: () => onHospitalSelected(hospital),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                        border:
                        isSelected
                            ? Border.all(
                          color: Colors.blue.withOpacity(0.4),
                        )
                            : null,
                      ),
                      child: Row(
                        children: [
                          // 선택 표시
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                              isSelected ? Colors.blue : Colors.grey[200],
                              border: Border.all(
                                color:
                                isSelected
                                    ? Colors.blue
                                    : Colors.grey[400]!,
                              ),
                            ),
                            child:
                            isSelected
                                ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                                : null,
                          ),

                          const SizedBox(width: 8),

                          // 병원 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        hospital.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13, // 폰트 사이즈 줄임 (14 -> 13)
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // 지역 표시 추가
                                    if (hospital.region != null && hospital.region!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), // 패딩 줄임
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(3), // 라운드 줄임
                                        ),
                                        child: Text(
                                          hospital.region!,
                                          style: TextStyle(
                                            fontSize: 9, // 폰트 사이즈 줄임 (10 -> 9)
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 3), // 간격 줄임
                                    _buildFeatureIcon(
                                      hospital.canTreatTrauma,
                                      '외상',
                                      Colors.red,
                                    ),
                                    _buildFeatureIcon(
                                      hospital.canTreatCardiac,
                                      '심장',
                                      Colors.red,
                                    ),
                                    _buildFeatureIcon(
                                      hospital.canTreatStroke,
                                      '뇌졸중',
                                      Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3), // 간격 줄임 (4 -> 3)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.king_bed,
                                      size: 12, // 아이콘 사이즈 줄임 (14 -> 12)
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 3), // 간격 줄임
                                    Text(
                                      '병상 ${hospital.availableBeds}개',
                                      style: TextStyle(
                                        fontSize: 11, // 폰트 사이즈 줄임 (12 -> 11)
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 6), // 간격 줄임
                                    Icon(
                                      Icons.timer,
                                      size: 12, // 아이콘 사이즈 줄임
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${(hospital.estimatedTimeSeconds / 60).round()}분',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.route,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${(hospital.distanceMeters / 1000).toStringAsFixed(1)}km',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 적합도
                          _buildCompatibilityIndicator(hospital),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6), // 간격 줄임 (8 -> 6)

            // 선택된 병원에 대한 추가 정보 (선택된 병원이 있는 경우) - 간단하게 축소
            if (selectedHospital != null) ...[
              const Divider(height: 12), // 높이 줄임
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0), // 패딩 줄임 (8 -> 4)
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '선택된 병원',
                          style: TextStyle(
                            fontSize: 11, // 폰트 사이즈 줄임 (12 -> 11)
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 지역 정보 표시
                        if (selectedHospital!.region != null && selectedHospital!.region!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // 패딩 줄임
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(3), // 라운드 줄임
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              selectedHospital!.region!,
                              style: TextStyle(
                                fontSize: 10, // 폰트 사이즈 줄임 (11 -> 10)
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3), // 간격 줄임
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (selectedHospital!.hasICU)
                            _buildHospitalFeature('중환자실', Colors.red[700]!),
                          if (selectedHospital!.hasPediatricER)
                            _buildHospitalFeature('소아응급', Colors.blue[700]!),
                          if (selectedHospital!.canTreatTrauma)
                            _buildHospitalFeature('외상센터', Colors.orange[700]!),
                          if (selectedHospital!.canTreatCardiac)
                            _buildHospitalFeature('심장센터', Colors.pink[700]!),
                          if (selectedHospital!.canTreatStroke)
                            _buildHospitalFeature('뇌졸중센터', Colors.purple[700]!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 병원이 없는 경우 표시 - 간단하게 축소
            if (hospitals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12), // 패딩 줄임 (20 -> 12)
                child: Column(
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 32, // 아이콘 사이즈 줄임 (48 -> 32)
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 4), // 간격 줄임 (8 -> 4)
                    Text(
                      '선택된 지역에 적합한 병원이 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12, // 폰트 사이즈 줄임 (14 -> 12)
                      ),
                    ),
                    const SizedBox(height: 2), // 간격 줄임 (4 -> 2)
                    Text(
                      '다른 지역을 선택해보세요',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11, // 폰트 사이즈 줄임 (12 -> 11)
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 병원 특성 기능 아이콘
  Widget _buildFeatureIcon(bool hasFeature, String label, Color color) {
    if (!hasFeature) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 병원 특성 표시
  Widget _buildHospitalFeature(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 환자 상태-병원 적합도 표시
  Widget _buildCompatibilityIndicator(Hospital hospital) {
    double compatibility = 0.0;

    // 적합도 계산
    if (hospital.isMatchForCondition(patientCondition) &&
        hospital.isMatchForSeverity(patientSeverity)) {
      compatibility = 1.0; // 최적
    } else if (hospital.isMatchForCondition(patientCondition) ||
        hospital.isMatchForSeverity(patientSeverity)) {
      compatibility = 0.5; // 부분 적합
    } else {
      compatibility = 0.2; // 최소 적합
    }

    // 아이콘 색상
    Color iconColor;
    String compatibilityText;

    if (compatibility >= 0.8) {
      iconColor = Colors.green;
      compatibilityText = '최적';
    } else if (compatibility >= 0.5) {
      iconColor = Colors.orange;
      compatibilityText = '적합';
    } else {
      iconColor = Colors.grey;
      compatibilityText = '가능';
    }

    return Column(
      children: [
        Icon(Icons.check_circle, color: iconColor, size: 16),
        Text(
          compatibilityText,
          style: TextStyle(
            fontSize: 10,
            color: iconColor,
            fontWeight: FontWeight.bold,
          ),
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