import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

// 병원 모델 클래스
class Hospital {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int availableBeds;
  final List<String> specialties;
  final bool hasEmergencyRoom;
  final String? region;
  final String phoneNumber;
  final double distance;
  final int estimatedMinutes;
  final bool canTreatTrauma;
  final bool canTreatCardiac;
  final bool canTreatStroke;
  final bool hasPediatricER;
  final bool hasICU;
  final int distanceMeters;
  int estimatedTimeSeconds;

  Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.availableBeds,
    required this.specialties,
    required this.hasEmergencyRoom,
    this.region,
    required this.phoneNumber,
    required this.distance,
    required this.estimatedMinutes,
    required this.canTreatTrauma,
    required this.canTreatCardiac,
    required this.canTreatStroke,
    required this.hasPediatricER,
    required this.hasICU,
    required this.distanceMeters,
    required this.estimatedTimeSeconds,
  });

  bool isMatchForCondition(String condition) {
    switch (condition.toLowerCase()) {
      case '심장마비':
        return canTreatCardiac && hasICU;
      case '뇌출혈':
        return canTreatStroke && hasICU;
      case '다발성 외상':
        return canTreatTrauma && hasICU;
      case '심한 출혈':
        return canTreatTrauma;
      case '화상':
        return hasICU;
      default:
        return hasEmergencyRoom;
    }
  }

  bool isMatchForSeverity(String severity) {
    switch (severity) {
      case '사망':
        return false; // 사망 환자는 병원 이송 불필요
      case '중증':
        return hasICU; // 중증은 ICU 필수
      case '중등':
        return hasEmergencyRoom; // 중등증은 응급실만 있으면 됨
      case '경증':
        return true; // 경증은 모든 병원 가능
      default:
        return hasEmergencyRoom;
    }
  }

  @override
  String toString() {
    return 'Hospital(name: $name, region: $region, distance: ${(distance / 1000).toStringAsFixed(1)}km)';
  }
}

// 지역 설정 클래스
class RegionConfig {
  final String regionName;
  final double searchRadius;
  final List<String> allowedRegions;
  final Map<String, double> conditionWeights;

  RegionConfig({
    required this.regionName,
    required this.searchRadius,
    required this.allowedRegions,
    required this.conditionWeights,
  });
}

// 응급의료정보센터 API 서비스
class EmergencyMedicalService {
  static const String _baseUrl =
      'http://apis.data.go.kr/B552657/ErmctInfoInqireService';
  static const String _serviceKey =
      'uJTYl2xqFaLfmL9WJN55JPXdgtm1JLQiXJYRv3UDRwAbsaf3wGLIBDxUTJ0gn54x3eOaJfgIwpzH0l6aZHJefQ%3D%3D'; // 실제 API 키로 교체 필요

  // 🔥 수정된 지역 감지를 위한 키워드 맵
  final Map<String, String> regionKeywords = {
    // 서울 키워드
    '서울': '서울',
    'seoul': '서울',
    '강남': '서울',
    '강북': '서울',
    '서초': '서울',
    '종로': '서울',
    '중구': '서울',
    '용산': '서울',
    '성동': '서울',
    '광진': '서울',
    '동대문': '서울',
    '중랑': '서울',
    '성북': '서울',
    '도봉': '서울',
    '노원': '서울',
    '은평': '서울',
    '서대문': '서울',
    '마포': '서울',
    '양천': '서울',
    '강서': '서울',
    '구로': '서울',
    '금천': '서울',
    '영등포': '서울',
    '동작': '서울',
    '관악': '서울',
    '송파': '서울',
    '강동': '서울',

    // 경기 키워드
    '경기': '경기',
    'gyeonggi': '경기',
    '수원': '경기',
    '성남': '경기',
    '용인': '경기',
    '안양': '경기',
    '안산': '경기',
    '고양': '경기',
    '과천': '경기',
    '구리': '경기',
    '남양주': '경기',
    '오산': '경기',
    '시흥': '경기',
    '군포': '경기',
    '의왕': '경기',
    '하남': '경기',
    '부천': '경기',
    '광명': '경기',
    '평택': '경기',
    '화성': '경기',
    '김포': '경기',
    '분당': '경기',
    '일산': '경기',

    // 🔥 대구/경북 키워드 수정
    '대구': '대구',
    'daegu': '대구',
    '대구가톨릭': '대구',
    '계명': '대구',
    '영남': '대구',

    // 경북 키워드 (구미 포함)
    '경북': '경북',
    '경상북도': '경북',
    'gyeongbuk': '경북',
    '포항': '경북',
    '경주': '경북',
    '김천': '경북',
    '안동': '경북',
    '구미': '경북', // 🔥 구미는 경북!
    '영주': '경북',
    '영천': '경북',
    '상주': '경북',
    '문경': '경북',
    '경산': '경북',

    // 부산 키워드
    '부산': '부산',
    'busan': '부산',
    '동아': '부산',
    '인제': '부산',
    '해운대': '부산',

    // 인천 키워드
    '인천': '인천',
    'incheon': '인천',
    '가천': '인천',
    '부평': '인천',

    // 🔥 대전 키워드 수정 (충남 제거!)
    '대전': '대전',
    'daejeon': '대전',
    '건양': '대전',
    '을지': '대전',

    // 🔥 충남 키워드 강화 (천안 포함)
    '충남': '충남',
    '충청남도': '충남',
    'chungnam': '충남',
    '천안': '충남', // 🔥 천안은 충남!
    '공주': '충남',
    '보령': '충남',
    '아산': '충남',
    '서산': '충남',
    '논산': '충남',
    '계룡': '충남',
    '당진': '충남',
    '홍성': '충남',
    '예산': '충남',
    '태안': '충남',
    '순천향': '충남', // 순천향대 천안병원
    '단국': '충남',    // 단국대병원

    // 광주 키워드 (전남 광주)
    '광주': '광주',
    'gwangju': '광주',
    '조선': '광주',
    '전남대': '광주',

    // 울산 키워드
    '울산': '울산',
    'ulsan': '울산',
    '동강': '울산',

    // 세종 키워드
    '세종': '세종',
    'sejong': '세종',

    // 강원 키워드
    '강원': '강원',
    'gangwon': '강원',
    '춘천': '강원',
    '원주': '강원',
    '강릉': '강원',
    '동해': '강원',
    '태백': '강원',
    '속초': '강원',
    '삼척': '강원',

    // 충북 키워드
    '충북': '충북',
    '충청북도': '충북',
    'chungbuk': '충북',
    '청주': '충북',
    '충주': '충북',
    '제천': '충북',

    // 전북 키워드
    '전북': '전북',
    '전라북도': '전북',
    'jeonbuk': '전북',
    '전주': '전북',
    '군산': '전북',
    '익산': '전북',
    '정읍': '전북',
    '남원': '전북',
    '김제': '전북',
    '원광': '전북',

    // 전남 키워드
    '전남': '전남',
    '전라남도': '전남',
    'jeonnam': '전남',
    '목포': '전남',
    '여수': '전남',
    '순천': '전남',
    '나주': '전남',
    '광양': '전남',

    // 경남 키워드
    '경남': '경남',
    '경상남도': '경남',
    'gyeongnam': '경남',
    '창원': '경남',
    '마산': '경남',
    '진주': '경남',
    '통영': '경남',
    '사천': '경남',
    '김해': '경남',
    '밀양': '경남',
    '거제': '경남',
    '양산': '경남',

    // 제주 키워드
    '제주': '제주',
    'jeju': '제주',
  };

  // 전화번호 지역번호로 지역 감지
  String? getRegionFromAreaCode(String areaCode) {
    final Map<String, String> areaCodes = {
      '02': '서울',
      '031': '경기',
      '032': '인천',
      '033': '강원',
      '041': '충남',
      '042': '대전',
      '043': '충북',
      '044': '세종',
      '051': '부산',
      '052': '울산',
      '053': '대구',
      '054': '경북',
      '055': '경남',
      '061': '전남',
      '062': '광주',
      '063': '전북',
      '064': '제주',
    };

    return areaCodes[areaCode];
  }

  // 🔥 수정된 지역 감지 함수
  String? extractRegionFromHospitalData(Map<String, dynamic> hospitalData) {
    // 1. 병원명에서 지역 추출 (가장 정확함)
    String? hospitalName = hospitalData['dutyName']?.toString();
    if (hospitalName != null) {
      String hospitalNameLower = hospitalName.toLowerCase();

      // 🔥 더 정확한 키워드 매칭 (긴 키워드부터 매칭)
      List<MapEntry<String, String>> sortedKeywords = regionKeywords.entries
          .toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length)); // 긴 키워드 우선

      for (var entry in sortedKeywords) {
        if (hospitalNameLower.contains(entry.key.toLowerCase())) {
          print('✅ 병원명 "${hospitalName}"에서 키워드 "${entry.key}" 감지 → ${entry.value} 지역');
          return entry.value;
        }
      }
    }

    // 2. 전화번호 지역번호로 지역 추출
    String? phoneNumber = hospitalData['dutyTel3']?.toString() ??
        hospitalData['dutyTel1']?.toString();
    if (phoneNumber != null && phoneNumber.contains('-')) {
      String areaCode = phoneNumber.split('-')[0];
      String? region = getRegionFromAreaCode(areaCode);
      if (region != null) {
        print('✅ 전화번호 "${phoneNumber}" 지역번호 "${areaCode}"에서 ${region} 지역 감지');
        return region;
      }
    }

    // 3. 주소 정보 활용
    String? address = hospitalData['dutyAddr']?.toString();
    if (address != null) {
      String addressLower = address.toLowerCase();

      // 주소에서도 긴 키워드부터 매칭
      List<MapEntry<String, String>> sortedKeywords = regionKeywords.entries
          .toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

      for (var entry in sortedKeywords) {
        if (addressLower.contains(entry.key.toLowerCase())) {
          print('✅ 주소 "${address}"에서 키워드 "${entry.key}" 감지 → ${entry.value} 지역');
          return entry.value;
        }
      }
    }

    print('❌ 병원 데이터에서 지역을 감지하지 못했습니다: ${hospitalData['dutyName']}');
    return null;
  }

  // 지역별 설정 가져오기
  Map<String, RegionConfig> getRegionConfigs() {
    return {
      '서울': RegionConfig(
        regionName: '서울특별시',
        searchRadius: 20.0,
        allowedRegions: ['서울특별시', '경기도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '경기': RegionConfig(
        regionName: '경기도',
        searchRadius: 30.0,
        allowedRegions: ['경기도', '서울특별시', '인천광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '부산': RegionConfig(
        regionName: '부산광역시',
        searchRadius: 25.0,
        allowedRegions: ['부산광역시', '경상남도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '대구': RegionConfig(
        regionName: '대구광역시',
        searchRadius: 25.0,
        allowedRegions: ['대구광역시', '경상북도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '인천': RegionConfig(
        regionName: '인천광역시',
        searchRadius: 25.0,
        allowedRegions: ['인천광역시', '경기도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '광주': RegionConfig(
        regionName: '광주광역시',
        searchRadius: 30.0,
        allowedRegions: ['광주광역시', '전라남도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '대전': RegionConfig(
        regionName: '대전광역시',
        searchRadius: 30.0,
        allowedRegions: ['대전광역시', '충청남도', '충청북도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '울산': RegionConfig(
        regionName: '울산광역시',
        searchRadius: 30.0,
        allowedRegions: ['울산광역시', '경상남도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '세종': RegionConfig(
        regionName: '세종특별자치시',
        searchRadius: 35.0,
        allowedRegions: ['세종특별자치시', '충청남도', '대전광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '충남': RegionConfig(
        regionName: '충청남도',
        searchRadius: 40.0,
        allowedRegions: ['충청남도', '대전광역시', '세종특별자치시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '충북': RegionConfig(
        regionName: '충청북도',
        searchRadius: 40.0,
        allowedRegions: ['충청북도', '대전광역시', '세종특별자치시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '경북': RegionConfig(
        regionName: '경상북도',
        searchRadius: 50.0,
        allowedRegions: ['경상북도', '대구광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '경남': RegionConfig(
        regionName: '경상남도',
        searchRadius: 45.0,
        allowedRegions: ['경상남도', '부산광역시', '울산광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '전북': RegionConfig(
        regionName: '전라북도',
        searchRadius: 45.0,
        allowedRegions: ['전라북도', '광주광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '전남': RegionConfig(
        regionName: '전라남도',
        searchRadius: 50.0,
        allowedRegions: ['전라남도', '광주광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '강원': RegionConfig(
        regionName: '강원특별자치도',
        searchRadius: 60.0,
        allowedRegions: ['강원특별자치도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '제주': RegionConfig(
        regionName: '제주특별자치도',
        searchRadius: 30.0,
        allowedRegions: ['제주특별자치도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
    };
  }

  // 환자 위치의 행정구역 정보 확인
  Future<String?> _getAdministrativeArea(
      double latitude,
      double longitude,
      ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty) {
        return placemarks.first.administrativeArea;
      }
    } catch (e) {
      print('주소 변환 오류: $e');
    }
    return null;
  }

  // 주변 병원 검색 (API + 더미 데이터 조합)
  Future<List<Hospital>> findNearbyHospitals(
      double latitude,
      double longitude,
      double radiusKm,
      ) async {
    List<Hospital> allHospitals = [];

    try {
      // 1. 실제 API에서 병원 정보 가져오기
      final apiHospitals = await _fetchHospitalsFromAPI(
        latitude,
        longitude,
        radiusKm,
      );
      allHospitals.addAll(apiHospitals);
      print('API에서 ${apiHospitals.length}개 병원 정보 가져옴');
    } catch (e) {
      print('API 호출 실패: $e');
    }

    // 2. API 결과가 부족하면 더미 데이터 추가
    if (allHospitals.length < 3) {
      print('API 병원 수가 부족하여 더미 데이터 추가');
      final dummyHospitals = await _getDummyHospitals(latitude, longitude);
      allHospitals.addAll(dummyHospitals);
    }

    // 3. 거리순 정렬
    allHospitals.sort((a, b) => a.distance.compareTo(b.distance));

    print('총 ${allHospitals.length}개의 병원을 찾았습니다.');

    // 지역별 분포 확인
    Map<String, int> regionDistribution = {};
    for (var hospital in allHospitals) {
      String region = hospital.region ?? '미분류';
      regionDistribution[region] = (regionDistribution[region] ?? 0) + 1;
    }
    print('지역별 병원 분포: $regionDistribution');

    return allHospitals;
  }

  // 실제 API에서 병원 정보 가져오기
  Future<List<Hospital>> _fetchHospitalsFromAPI(
      double latitude,
      double longitude,
      double radiusKm,
      ) async {
    try {
      // WGS84 좌표를 이용한 API 호출
      final url = Uri.parse(
        '$_baseUrl/getEmrrmRltmUsefulSckbdInfoInqire',
      ).replace(
        queryParameters: {
          'serviceKey': _serviceKey,
          'WGS84_LON': longitude.toString(),
          'WGS84_LAT': latitude.toString(),
          'pageNo': '1',
          'numOfRows': '20',
          '_type': 'json',
        },
      );

      print('API 호출: $url');

      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return await _parseApiHospitals(data, latitude, longitude);
      } else {
        print('API 호출 실패: ${response.statusCode}');
        print('응답 내용: ${response.body}');
        return [];
      }
    } catch (e) {
      print('API 호출 중 오류 발생: $e');
      return [];
    }
  }

  // API 병원 데이터 파싱 함수
  Future<List<Hospital>> _parseApiHospitals(
      Map<String, dynamic> apiResponse,
      double patientLat,
      double patientLng,
      ) async {
    final List<Hospital> hospitals = [];

    try {
      final items = apiResponse['response']?['body']?['items']?['item'];
      if (items == null) return hospitals;

      List<dynamic> hospitalList = items is List ? items : [items];

      for (var item in hospitalList) {
        // 동적 지역 감지 적용
        String? detectedRegion = extractRegionFromHospitalData(item);

        // 좌표 정보 확인
        double? lat = double.tryParse(item['wgs84Lat']?.toString() ?? '');
        double? lng = double.tryParse(item['wgs84Lon']?.toString() ?? '');

        if (lat == null || lng == null || lat == 0 || lng == 0) {
          print('병원 ${item['dutyName']} - 좌표 정보 없음, 건너뜀');
          continue;
        }

        // 거리 계산
        double distance = _calculateDistance(patientLat, patientLng, lat, lng);

        // 병원 객체 생성
        hospitals.add(
          Hospital(
            id: item['hpid']?.toString() ?? '',
            name: item['dutyName']?.toString() ?? '알 수 없는 병원',
            latitude: lat,
            longitude: lng,
            availableBeds: int.tryParse(item['hvec']?.toString() ?? '0') ?? 0,
            specialties: _parseSpecialties(item),
            hasEmergencyRoom: (item['hvec'] ?? 0) > 0,
            region: detectedRegion,
            phoneNumber:
            item['dutyTel3']?.toString() ??
                item['dutyTel1']?.toString() ??
                '',
            distance: distance,
            estimatedMinutes: (distance / 1000 / 60 * 60).round(),
            canTreatTrauma: _canTreatCondition(item, '외상'),
            canTreatCardiac: _canTreatCondition(item, '심장'),
            canTreatStroke: _canTreatCondition(item, '뇌졸중'),
            hasPediatricER: (item['hvs01'] ?? 0) > 0,
            hasICU: (item['hvs17'] ?? 0) > 0,
            distanceMeters: distance.round(),
            estimatedTimeSeconds: (distance / 1000 / 60 * 60).round() * 60,
          ),
        );

        print(
          'API 병원 추가: ${item['dutyName']} (지역: $detectedRegion, 거리: ${(distance / 1000).toStringAsFixed(1)}km)',
        );
      }
    } catch (e) {
      print('API 응답 파싱 중 오류: $e');
    }

    return hospitals;
  }

  // 전문과목 파싱
  List<String> _parseSpecialties(Map<String, dynamic> item) {
    List<String> specialties = [];

    // API 응답에서 전문과목 정보 추출
    if (item['dgidIdName'] != null) {
      specialties.add(item['dgidIdName'].toString());
    }

    // 기본 전문과목 추가
    specialties.addAll(['내과', '외과', '응급의학과']);

    return specialties.toSet().toList(); // 중복 제거
  }

  // 특정 조건 치료 가능 여부 확인
  bool _canTreatCondition(Map<String, dynamic> item, String condition) {
    // 간단한 로직 - 실제로는 더 복잡한 매핑이 필요
    switch (condition) {
      case '외상':
        return (item['hvs02'] ?? 0) > 0; // 외상 관련
      case '심장':
        return (item['hvs03'] ?? 0) > 0; // 심장 관련
      case '뇌졸중':
        return (item['hvs04'] ?? 0) > 0; // 뇌졸중 관련
      default:
        return true;
    }
  }

  // 두 지점 간의 거리 계산 (Haversine 공식)
  double _calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLon = (lon2 - lon1) * (math.pi / 180);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1 * (math.pi / 180)) *
                math.cos(lat2 * (math.pi / 180)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // 전국 병원 데이터 반환
  Map<String, List<Map<String, dynamic>>> getNationalHospitalData() {
    return {
      '서울': [
        {
          "name": "서울대학교병원",
          "region": "서울특별시",
          "phone": "02-2072",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "세브란스병원",
          "region": "서울특별시",
          "phone": "02-2228",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "삼성서울병원",
          "region": "서울특별시",
          "phone": "02-3410",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "서울아산병원",
          "region": "서울특별시",
          "phone": "02-3010",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "강남세브란스병원",
          "region": "서울특별시",
          "phone": "02-2019",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "서울성모병원",
          "region": "서울특별시",
          "phone": "02-2258",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "고려대학교 안암병원",
          "region": "서울특별시",
          "phone": "02-920",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
      ],
      '경기': [
        {
          "name": "분당서울대학교병원",
          "region": "경기도",
          "phone": "031-787",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "경기도의료원 안산병원",
          "region": "경기도",
          "phone": "031-412",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "국민건강보험 일산병원",
          "region": "경기도",
          "phone": "031-900",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "아주대학교병원",
          "region": "경기도",
          "phone": "031-219",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "경기도의료원 수원병원",
          "region": "경기도",
          "phone": "031-288",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "성남중앙병원",
          "region": "경기도",
          "phone": "031-738",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
      ],
      '부산': [
        {
          "name": "부산대학교병원",
          "region": "부산광역시",
          "phone": "051-240",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "동아대학교병원",
          "region": "부산광역시",
          "phone": "051-240",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "인제대학교 부산백병원",
          "region": "부산광역시",
          "phone": "051-890",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "고신대학교복음병원",
          "region": "부산광역시",
          "phone": "051-990",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "부산의료원",
          "region": "부산광역시",
          "phone": "051-607",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "해운대백병원",
          "region": "부산광역시",
          "phone": "051-797",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
      ],
      '대구': [
        {
          "name": "대구가톨릭대학교병원",
          "region": "대구광역시",
          "phone": "053-650",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "계명대학교 동산병원",
          "region": "대구광역시",
          "phone": "053-250",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "영남대학교병원",
          "region": "대구광역시",
          "phone": "053-640",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "대구의료원",
          "region": "대구광역시",
          "phone": "053-560",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "경북대학교병원",
          "region": "대구광역시",
          "phone": "053-420",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "대구파티마병원",
          "region": "대구광역시",
          "phone": "053-940",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
      ],
      '인천': [
        {
          "name": "인하대학교병원",
          "region": "인천광역시",
          "phone": "032-890",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "가천대학교 길병원",
          "region": "인천광역시",
          "phone": "032-460",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "인천의료원",
          "region": "인천광역시",
          "phone": "032-580",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "인천성모병원",
          "region": "인천광역시",
          "phone": "032-280",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "부평세림병원",
          "region": "인천광역시",
          "phone": "032-340",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '광주': [
        {
          "name": "조선대학교병원",
          "region": "광주광역시",
          "phone": "062-220",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "전남대학교병원",
          "region": "광주광역시",
          "phone": "062-220",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "광주기독병원",
          "region": "광주광역시",
          "phone": "062-650",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "전남대학교 화순병원",
          "region": "광주광역시",
          "phone": "061-379",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "광주보훈병원",
          "region": "광주광역시",
          "phone": "062-602",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
      ],
      '대전': [
        {
          "name": "충남대학교병원",
          "region": "대전광역시",
          "phone": "042-280",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "건양대학교병원",
          "region": "대전광역시",
          "phone": "042-600",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "을지대학교병원",
          "region": "대전광역시",
          "phone": "042-611",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "대전성모병원",
          "region": "대전광역시",
          "phone": "042-220",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "대전보훈병원",
          "region": "대전광역시",
          "phone": "042-939",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
      ],
      '울산': [
        {
          "name": "울산대학교병원",
          "region": "울산광역시",
          "phone": "052-250",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "동강병원",
          "region": "울산광역시",
          "phone": "052-241",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "울산의료원",
          "region": "울산광역시",
          "phone": "052-219",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "서울아산병원 울산점",
          "region": "울산광역시",
          "phone": "052-674",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
      ],
      '충남': [
        {
          "name": "순천향대학교 천안병원",
          "region": "충청남도",
          "phone": "041-570",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "단국대학교병원",
          "region": "충청남도",
          "phone": "041-550",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "천안한국병원",
          "region": "충청남도",
          "phone": "041-570",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "천안의료원",
          "region": "충청남도",
          "phone": "041-570",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "홍성의료원",
          "region": "충청남도",
          "phone": "041-630",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "서산의료원",
          "region": "충청남도",
          "phone": "041-660",
          "trauma": true,
          "cardiac": false,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "공주의료원",
          "region": "충청남도",
          "phone": "041-850",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '충북': [
        {
          "name": "충북대학교병원",
          "region": "충청북도",
          "phone": "043-269",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "청주의료원",
          "region": "충청북도",
          "phone": "043-270",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "청주성모병원",
          "region": "충청북도",
          "phone": "043-219",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "제천의료원",
          "region": "충청북도",
          "phone": "043-649",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "충주의료원",
          "region": "충청북도",
          "phone": "043-857",
          "trauma": true,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '강원': [
        {
          "name": "강원대학교병원",
          "region": "강원특별자치도",
          "phone": "033-258",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "원주세브란스기독병원",
          "region": "강원특별자치도",
          "phone": "033-741",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "춘천성심병원",
          "region": "강원특별자치도",
          "phone": "033-240",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "강릉아산병원",
          "region": "강원특별자치도",
          "phone": "033-610",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "원주의료원",
          "region": "강원특별자치도",
          "phone": "033-760",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "속초의료원",
          "region": "강원특별자치도",
          "phone": "033-639",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '전북': [
        {
          "name": "전북대학교병원",
          "region": "전라북도",
          "phone": "063-250",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "원광대학교병원",
          "region": "전라북도",
          "phone": "063-859",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "전주예수병원",
          "region": "전라북도",
          "phone": "063-230",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "군산의료원",
          "region": "전라북도",
          "phone": "063-445",
          "trauma": true,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
        {
          "name": "익산병원",
          "region": "전라북도",
          "phone": "063-843",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
      ],
      '전남': [
        {
          "name": "목포대학교병원",
          "region": "전라남도",
          "phone": "061-279",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "순천향대학교 구미병원",
          "region": "전라남도",
          "phone": "061-729",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "여수중앙병원",
          "region": "전라남도",
          "phone": "061-680",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "목포중앙병원",
          "region": "전라남도",
          "phone": "061-280",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "나주의료원",
          "region": "전라남도",
          "phone": "061-330",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '경북': [
        {
          "name": "안동병원",
          "region": "경상북도",
          "phone": "054-840",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "포항성모병원",
          "region": "경상북도",
          "phone": "054-260",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "경주병원",
          "region": "경상북도",
          "phone": "054-770",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "구미차병원",
          "region": "경상북도",
          "phone": "054-450",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "김천의료원",
          "region": "경상북도",
          "phone": "054-420",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "영주의료원",
          "region": "경상북도",
          "phone": "054-639",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
      ],
      '경남': [
        {
          "name": "경상국립대학교병원",
          "region": "경상남도",
          "phone": "055-750",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "창원경상대학교병원",
          "region": "경상남도",
          "phone": "055-214",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "마산의료원",
          "region": "경상남도",
          "phone": "055-249",
          "trauma": true,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "진주의료원",
          "region": "경상남도",
          "phone": "055-750",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "통영의료원",
          "region": "경상남도",
          "phone": "055-648",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
        {
          "name": "김해의료원",
          "region": "경상남도",
          "phone": "055-330",
          "trauma": true,
          "cardiac": false,
          "stroke": false,
          "icu": true,
        },
      ],
      '제주': [
        {
          "name": "제주대학교병원",
          "region": "제주특별자치도",
          "phone": "064-717",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "제주한라병원",
          "region": "제주특별자치도",
          "phone": "064-740",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "제주의료원",
          "region": "제주특별자치도",
          "phone": "064-750",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
        {
          "name": "서귀포의료원",
          "region": "제주특별자치도",
          "phone": "064-730",
          "trauma": false,
          "cardiac": false,
          "stroke": false,
          "icu": false,
        },
        {
          "name": "제주국제병원",
          "region": "제주특별자치도",
          "phone": "064-720",
          "trauma": false,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
      ],
      '세종': [
        {
          "name": "세종충남대학교병원",
          "region": "세종특별자치시",
          "phone": "044-995",
          "trauma": true,
          "cardiac": true,
          "stroke": true,
          "icu": true,
        },
        {
          "name": "세종병원",
          "region": "세종특별자치시",
          "phone": "044-856",
          "trauma": false,
          "cardiac": true,
          "stroke": false,
          "icu": true,
        },
        {
          "name": "세종의료원",
          "region": "세종특별자치시",
          "phone": "044-850",
          "trauma": false,
          "cardiac": false,
          "stroke": true,
          "icu": false,
        },
      ],
    };
  }

  // 🔥 수정된 더미 병원 데이터 생성
  Future<List<Hospital>> _getDummyHospitals(
      double centerLat,
      double centerLng,
      ) async {
    print('🏥 더미 병원 데이터 생성 시작');

    // 환자 위치의 지역 확인 (주소 기반)
    String? patientRegion = await _getAdministrativeArea(centerLat, centerLng);
    String? regionKey;

    print('📍 환자 위치 주소: $patientRegion');

    if (patientRegion != null) {
      String patientRegionLower = patientRegion.toLowerCase();

      // 🔥 더 정확한 지역 매칭 (긴 키워드부터)
      List<MapEntry<String, String>> sortedKeywords = regionKeywords.entries
          .toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

      for (var entry in sortedKeywords) {
        if (patientRegionLower.contains(entry.key.toLowerCase())) {
          regionKey = entry.value;
          print('✅ 주소에서 키워드 "${entry.key}" 매칭 → ${entry.value} 지역');
          break;
        }
      }
    }

    // 🔥 지역이 감지되지 않으면 좌표 기반으로 추정
    if (regionKey == null) {
      regionKey = _estimateRegionByCoordinates(centerLat, centerLng);
      print('📍 좌표 기반 지역 추정: $regionKey');
    }

    // 🔥 그래도 없으면 서울을 기본값으로 (하지만 로그에 명시)
    if (regionKey == null) {
      regionKey = '서울';
      print('⚠️ 지역 감지 실패 - 서울 기본값 사용');
    }

    print('🎯 최종 선택된 지역: $regionKey');

    final random = math.Random();
    final List<Hospital> dummyHospitals = [];
    final nationalHospitalData = getNationalHospitalData();

    List<Map<String, dynamic>> hospitalTypes = nationalHospitalData[regionKey]!;
    print('🏥 ${regionKey} 지역 병원 ${hospitalTypes.length}개 로드');

    // 더미 병원 데이터 생성
    for (int i = 0; i < hospitalTypes.length; i++) {
      final latOffset = (random.nextDouble() - 0.5) * 0.05;
      final lngOffset = (random.nextDouble() - 0.5) * 0.05;

      final hospitalLat = centerLat + latOffset;
      final hospitalLng = centerLng + lngOffset;

      final hospitalType = hospitalTypes[i];
      final distance = math.sqrt(latOffset * latOffset + lngOffset * lngOffset) * 100000;
      final availableBeds = math.max(1, (10 - distance / 10000).round());

      dummyHospitals.add(
        Hospital(
          id: "dummy_${hospitalType["name"]}",
          name: hospitalType["name"] as String,
          latitude: hospitalLat,
          longitude: hospitalLng,
          availableBeds: availableBeds,
          specialties: ["내과", "외과", "응급의학과"],
          hasEmergencyRoom: true,
          region: hospitalType["region"] as String,
          phoneNumber: "${hospitalType["phone"]}-000-000$i",
          distance: distance,
          estimatedMinutes: (distance / 1000 / 60 * 60).round(),
          canTreatTrauma: hospitalType["trauma"] as bool,
          canTreatCardiac: hospitalType["cardiac"] as bool,
          canTreatStroke: hospitalType["stroke"] as bool,
          hasPediatricER: random.nextBool(),
          hasICU: hospitalType["icu"] as bool,
          distanceMeters: distance.round(),
          estimatedTimeSeconds: (distance / 1000 / 60 * 60).round() * 60,
        ),
      );
    }

    print('✅ ${dummyHospitals.length}개 더미 병원 생성 완료');
    return dummyHospitals;
  }

  // 🔥 좌표 기반 지역 추정 함수 추가
  String? _estimateRegionByCoordinates(double lat, double lng) {
    // 한국 주요 도시 중심 좌표
    final Map<String, Map<String, double>> regionCenters = {
      '서울': {'lat': 37.5665, 'lng': 126.9780},
      '부산': {'lat': 35.1796, 'lng': 129.0756},
      '대구': {'lat': 35.8714, 'lng': 128.6014},
      '인천': {'lat': 37.4563, 'lng': 126.7052},
      '광주': {'lat': 35.1595, 'lng': 126.8526},
      '대전': {'lat': 36.3504, 'lng': 127.3845},
      '울산': {'lat': 35.5384, 'lng': 129.3114},
      '세종': {'lat': 36.4800, 'lng': 127.2890},
      '천안': {'lat': 36.8151, 'lng': 127.1139}, // 🔥 천안 = 충남
      '경기': {'lat': 37.4138, 'lng': 127.5183},
      '강원': {'lat': 37.8228, 'lng': 128.1555},
      '충북': {'lat': 36.6355, 'lng': 127.4916},
      '충남': {'lat': 36.5184, 'lng': 126.8000},
      '전북': {'lat': 35.7175, 'lng': 127.1530},
      '전남': {'lat': 34.8679, 'lng': 126.9910},
      '경북': {'lat': 36.4919, 'lng': 128.8889},
      '경남': {'lat': 35.4606, 'lng': 128.2132},
      '제주': {'lat': 33.4996, 'lng': 126.5312},
    };

    String? nearestRegion;
    double minDistance = double.infinity;

    for (var entry in regionCenters.entries) {
      double regionLat = entry.value['lat']!;
      double regionLng = entry.value['lng']!;

      double distance = math.sqrt(
          math.pow(lat - regionLat, 2) + math.pow(lng - regionLng, 2)
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestRegion = entry.key;
      }
    }

    // 🔥 천안이 가장 가까우면 충남으로 변환
    if (nearestRegion == '천안') {
      nearestRegion = '충남';
    }

    print('📍 가장 가까운 지역: $nearestRegion (거리: ${minDistance.toStringAsFixed(3)})');
    return nearestRegion;
  }

  // 🔥 수정된 지역 필터링 - 모든 감지된 지역 허용
  List<Hospital> _filterHospitalsByDetectedRegions(
      List<Hospital> hospitals,
      String? targetRegion,
      ) {
    if (hospitals.isEmpty) return hospitals;

    // 감지된 모든 지역 수집
    Set<String> detectedRegions =
    hospitals
        .where((h) => h.region != null && h.region!.isNotEmpty)
        .map((h) => h.region!)
        .toSet();

    print('감지된 지역들: ${detectedRegions.join(", ")}');

    // 타겟 지역이 있고 감지된 지역에 포함되어 있으면 해당 지역 우선
    if (targetRegion != null && detectedRegions.contains(targetRegion)) {
      var targetRegionHospitals =
      hospitals.where((h) => h.region == targetRegion).toList();
      print('타겟 지역 $targetRegion의 병원 ${targetRegionHospitals.length}개 우선 반환');

      if (targetRegionHospitals.isNotEmpty) {
        return targetRegionHospitals;
      }
    }

    // 모든 감지된 지역의 병원들 반환 (지역 정보가 있는 것들만)
    var validHospitals =
    hospitals
        .where((h) => h.region != null && h.region!.isNotEmpty)
        .toList();
    print('지역 정보가 있는 병원 ${validHospitals.length}개 반환');

    return validHospitals;
  }

  // 🔥 수정된 메인 함수 - findOptimalHospitals
  Future<List<Hospital>> findOptimalHospitals(
      double latitude,
      double longitude,
      String patientCondition,
      String patientSeverity, {
        double? searchRadius,
      }) async {
    print(
      '병원 추천 요청 - 위치: LatLng($latitude, $longitude), 상태: $patientCondition, 중증도: $patientSeverity',
    );

    // 환자 위치의 행정구역 정보 확인
    String? patientRegion = await _getAdministrativeArea(latitude, longitude);
    print('환자 위치 원본 지역: $patientRegion');

    // 지역 키 추출 (환자 위치 기반)
    String? targetRegion;
    if (patientRegion != null) {
      String patientRegionLower = patientRegion.toLowerCase();
      for (var entry in regionKeywords.entries) {
        if (patientRegionLower.contains(entry.key.toLowerCase())) {
          targetRegion = entry.value;
          break;
        }
      }
    }

    print('타겟 지역: $targetRegion');

    // 지역 설정 가져오기
    final regionConfigs = getRegionConfigs();
    RegionConfig? regionConfig =
    targetRegion != null ? regionConfigs[targetRegion] : null;

    // 검색 반경 결정
    double adjustedRadius;

    if (regionConfig != null) {
      adjustedRadius = searchRadius ?? regionConfig.searchRadius;
      print('${regionConfig.regionName} 지역 감지 - 검색 반경: ${adjustedRadius}km');
    } else {
      // 알 수 없는 지역인 경우 기본값 사용
      adjustedRadius = searchRadius ?? 40.0;
      print('알 수 없는 지역 - 기본 반경 ${adjustedRadius}km 사용, 서울/경기 지역 포함');
    }

    // 주변 병원 검색 (API + 더미)
    final hospitals = await findNearbyHospitals(
      latitude,
      longitude,
      adjustedRadius,
    );
    print('검색된 총 병원 수: ${hospitals.length}');

    // 🔥 동적 지역 필터링 적용
    List<Hospital> regionFilteredHospitals = _filterHospitalsByDetectedRegions(
      hospitals,
      targetRegion,
    );
    print('지역 필터링 후 병원 수: ${regionFilteredHospitals.length}');

    // 환자 상태에 따른 적합성 검사
    List<Hospital> suitableHospitals =
    regionFilteredHospitals.where((hospital) {
      // 기본 조건: 응급실이 있어야 함
      if (!hospital.hasEmergencyRoom) return false;

      // 환자 상태별 특별 조건
      switch (patientCondition) {
        case '심장마비':
          return hospital.canTreatCardiac && hospital.hasICU;
        case '뇌출혈':
          return hospital.canTreatStroke && hospital.hasICU;
        case '다발성 외상':
          return hospital.canTreatTrauma && hospital.hasICU;
        case '심한 출혈':
          return hospital.canTreatTrauma;
        case '화상':
          return hospital.hasICU; // 화상은 ICU가 있는 병원
        default:
          return true; // 기타 상태는 응급실만 있으면 OK
      }
    }).toList();

    print('최종 적합한 병원 수: ${suitableHospitals.length}');

    // 병원이 없으면 지역 제한 완화하여 재검색
    if (suitableHospitals.isEmpty && regionFilteredHospitals.isNotEmpty) {
      print('적합한 병원이 없어 조건을 완화하여 재검색');
      suitableHospitals =
          regionFilteredHospitals.where((hospital) {
            return hospital.hasEmergencyRoom; // 최소 조건만 적용
          }).toList();
    }

    // 중증도와 거리에 따른 우선순위 계산
    final conditionWeights =
        regionConfig?.conditionWeights ?? {patientCondition: 1.0};

    double conditionWeight = conditionWeights[patientCondition] ?? 0.5;

    for (var hospital in suitableHospitals) {
      // 거리 점수 (가까울수록 높은 점수)
      double distanceScore = math.max(
        0,
        1 - (hospital.distance / 50000),
      ); // 50km 기준

      // 병상 점수
      double bedScore = math.min(1.0, hospital.availableBeds / 10.0);

      // 전문성 점수
      double specialtyScore = _calculateSpecialtyScore(
        hospital,
        patientCondition,
      );

      // 최종 점수 계산
      hospital.estimatedTimeSeconds =
          (hospital.distance / 1000 / 60 * 60).round() * 60;
    }

    // 거리순 정렬 (가장 중요한 요소)
    suitableHospitals.sort((a, b) => a.distance.compareTo(b.distance));

    // 지역별 분포 로깅
    Map<String, int> finalRegionDistribution = {};
    for (var hospital in suitableHospitals) {
      String region = hospital.region ?? '미분류';
      finalRegionDistribution[region] =
          (finalRegionDistribution[region] ?? 0) + 1;
    }
    print('최종 지역별 병원 분포: $finalRegionDistribution');

    print('${suitableHospitals.length}개의 병원 추천 완료');
    return suitableHospitals;
  }

  // 전문성 점수 계산
  double _calculateSpecialtyScore(Hospital hospital, String condition) {
    double score = 0.5; // 기본 점수

    switch (condition) {
      case '심장마비':
        if (hospital.canTreatCardiac) score += 0.3;
        if (hospital.hasICU) score += 0.2;
        break;
      case '뇌출혈':
        if (hospital.canTreatStroke) score += 0.3;
        if (hospital.hasICU) score += 0.2;
        break;
      case '다발성 외상':
        if (hospital.canTreatTrauma) score += 0.3;
        if (hospital.hasICU) score += 0.2;
        break;
      case '심한 출혈':
        if (hospital.canTreatTrauma) score += 0.3;
        break;
      case '화상':
        if (hospital.hasICU) score += 0.3;
        break;
    }

    return math.min(1.0, score);
  }
}