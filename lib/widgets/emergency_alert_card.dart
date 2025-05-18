import 'package:flutter/material.dart';

class EmergencyAlertCard extends StatelessWidget {
  final String message;
  final String patientCondition; // 추가
  final String patientSeverity; // 추가

  const EmergencyAlertCard({
    Key? key,
    required this.message,
    required this.patientCondition, // 추가
    required this.patientSeverity, // 추가
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[200]!),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '응급 모드 활성화됨',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 환자 상태 정보 추가
            if (patientCondition.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                      "$patientCondition 환자 이송 중",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
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