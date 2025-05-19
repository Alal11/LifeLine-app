import 'package:flutter/material.dart';
import '../services/hospital_service.dart';

class HospitalListCard extends StatelessWidget {
  final List<Hospital> hospitals;
  final Hospital? selectedHospital;
  final String patientCondition;
  final String patientSeverity;
  final Function(Hospital) onHospitalSelected;

  const HospitalListCard({
    Key? key,
    required this.hospitals,
    required this.selectedHospital,
    required this.patientCondition,
    required this.patientSeverity,
    required this.onHospitalSelected,
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

            const SizedBox(height: 12),

            // 병원 목록
            SizedBox(
              height: 200, // 목록의 최대 높이
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
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.king_bed,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '병상 ${hospital.availableBeds}개 가용',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.timer,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(hospital.estimatedTimeSeconds / 60).round()}분',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.route,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(hospital.distanceMeters / 1000).toStringAsFixed(1)}km',
                                      style: TextStyle(
                                        fontSize: 12,
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

            const SizedBox(height: 8),

            // 선택된 병원에 대한 추가 정보 (선택된 병원이 있는 경우)
            if (selectedHospital != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '선택된 병원 정보',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
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
                  ],
                ),
              ),
            ],
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
