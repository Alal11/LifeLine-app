import 'package:flutter/material.dart';

class RouteInfoCard extends StatelessWidget {
  final String destination;
  final String routePhase;
  final String estimatedTime;
  final String notifiedVehicles;
  final String patientCondition;
  final String patientSeverity;

  const RouteInfoCard({
    Key? key,
    required this.destination,
    required this.routePhase,
    required this.estimatedTime,
    required this.notifiedVehicles,
    required this.patientCondition,
    required this.patientSeverity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 환자 정보 표시 (추가)
            if (patientCondition.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: _getSeverityColor(patientSeverity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getSeverityColor(patientSeverity).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(patientSeverity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        patientSeverity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      patientCondition,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColor(patientSeverity),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 목적지 표시
            Row(
              children: [
                const Icon(Icons.navigation, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  routePhase == 'pickup'
                      ? '환자 위치: $destination'
                      : '병원: $destination',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 추가 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '예상 도착 시간: $estimatedTime',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '$notifiedVehicles 차량에 알림 전송됨',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
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