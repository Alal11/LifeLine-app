import 'dart:convert';
import 'package:http/http.dart' as http;

class RoadNetworkService {
  final String _baseUrl = 'https://viewt.ktdb.go.kr/cong/api/mainPath_road.do';

  // 도로망 경로 분석 API 호출
  Future<Map<String, dynamic>> getRoadNetwork({
    required int dprtrLinkId,
    required int arriveLinkId,
    int year = 2022,
    int weekType = 0, // 0: 평일, 1: 주말
    String time = "all",
  }) async {
    final url = Uri.parse(
      '$_baseUrl?DPRTR_LINKID=$dprtrLinkId&ARRIVE_LINKID=$arriveLinkId&YEAR=$year&WEEKTYPE=$weekType&TIME=$time',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('도로망 경로 데이터 로드 실패: ${response.statusCode}');
    }
  }

  // 도로 유형별 접근 가능 여부 확인
  bool isRoadAccessibleForEmergency(String roadType) {
    final accessibleRoadTypes = ['고속도로', '도시고속도로', '일반국도', '국가지원지방도', '지방도'];
    return accessibleRoadTypes.contains(roadType);
  }

  // 도로 유형별 속도 제한 정보
  double getRoadSpeedLimit(String roadType) {
    final Map<String, double> speedLimits = {
      '고속도로': 100.0,
      '도시고속도로': 80.0,
      '일반국도': 70.0,
      '국가지원지방도': 60.0,
      '지방도': 50.0,
      '시군도': 40.0,
      '연결로': 30.0,
    };
    return speedLimits[roadType] ?? 30.0;
  }
}
