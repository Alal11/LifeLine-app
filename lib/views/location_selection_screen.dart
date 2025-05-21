import 'dart:async';
import 'dart:math' show Random, cos, pi, max, min;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationSelectionScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  _LocationSelectionScreenState createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  GoogleMapController? mapController;
  LatLng? currentLocationCoord;
  Set<Marker> markers = {};
  bool isLoading = false;
  double bottomSheetHeight = 200.0; // 하단 위치 목록 높이 변수 추가
  bool isBottomSheetExpanded = false; // 확장 상태 추가

  // 위치 목록 정의
  final List<PredefinedLocation> predefinedLocations = [
    PredefinedLocation(
      name: '천안 (시청)',
      coordinates: const LatLng(36.8151, 127.1135),
    ),
    PredefinedLocation(
      name: '천안 (터미널)',
      coordinates: const LatLng(36.8207, 127.1562),
    ),
    PredefinedLocation(
      name: '천안 (백석대학교)',
      coordinates: const LatLng(36.8403, 127.0695),
    ),
    PredefinedLocation(
      name: '천안 (순천향대학교 부속병원)',
      coordinates: const LatLng(36.7957, 127.1345),
    ),
    PredefinedLocation(
      name: '천안 (단국대학교 병원)',
      coordinates: const LatLng(36.8178, 127.1535),
    ),
    PredefinedLocation(
      name: '서울 (시청)',
      coordinates: const LatLng(37.5665, 126.9780),
    ),
    PredefinedLocation(
      name: '서울 (서울역)',
      coordinates: const LatLng(37.5546, 126.9706),
    ),
    PredefinedLocation(
      name: '서울 (강남역)',
      coordinates: const LatLng(37.4980, 127.0276),
    ),
    PredefinedLocation(
      name: '서울 (서울대병원)',
      coordinates: const LatLng(37.5798, 126.9989),
    ),
    PredefinedLocation(
      name: '서울 (여의도)',
      coordinates: const LatLng(37.5255, 126.9241),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 초기 위치 설정
    developer.log('LocationSelectionScreen - initState');
    currentLocationCoord = widget.initialLocation ?? const LatLng(37.5665, 126.9780);
    developer.log('초기 위치: $currentLocationCoord');
    _updateMarker();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    developer.log('지도 컨트롤러 생성됨');
  }

  void _updateMarker() {
    if (currentLocationCoord != null) {
      setState(() {
        markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: currentLocationCoord!,
            infoWindow: const InfoWindow(title: '선택된 위치'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        };
      });
      developer.log('마커 업데이트: ${currentLocationCoord!.latitude}, ${currentLocationCoord!.longitude}');
    }
  }

  void _updateLocation(LatLng newLocation) {
    developer.log('위치 업데이트: ${newLocation.latitude}, ${newLocation.longitude}');
    setState(() {
      currentLocationCoord = newLocation;

      // 카메라 위치 업데이트
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocationCoord!,
            zoom: 15.0,
          ),
        ),
      );

      // 마커 업데이트
      _updateMarker();
    });
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        isLoading = true;
      });
      developer.log('현재 위치 가져오기 시작');

      // 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다')),
          );
          setState(() {
            isLoading = false;
          });
          developer.log('위치 권한 거부됨');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 권한이 영구적으로 거부된 경우
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.')),
        );
        setState(() {
          isLoading = false;
        });
        developer.log('위치 권한 영구 거부됨');
        return;
      }

      // 위치 가져오기
      Position position = await Geolocator.getCurrentPosition();
      developer.log('현재 위치 받음: ${position.latitude}, ${position.longitude}');
      _updateLocation(LatLng(position.latitude, position.longitude));

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      developer.log('위치 가져오기 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치를 가져오는 중 오류: $e')),
      );
    }
  }

  // 랜덤 위치 생성
  void _generateRandomLocation() {
    final random = Random();
    LatLng baseLocation = currentLocationCoord ?? const LatLng(37.5665, 126.9780);

    double latOffset = (random.nextDouble() * 0.09 - 0.045);
    double lngOffset = (random.nextDouble() * 0.09 - 0.045) / cos(baseLocation.latitude * pi / 180);

    double newLat = baseLocation.latitude + latOffset;
    double newLng = baseLocation.longitude + lngOffset;

    newLat = max(33.0, min(38.0, newLat));
    newLng = max(125.0, min(132.0, newLng));

    developer.log('랜덤 위치 생성: $newLat, $newLng');
    _updateLocation(LatLng(newLat, newLng));
  }

  // 하단 시트의 높이 토글
  void _toggleBottomSheetHeight() {
    setState(() {
      if (isBottomSheetExpanded) {
        // 접기
        bottomSheetHeight = 200.0;
        isBottomSheetExpanded = false;
        developer.log('하단 시트 접기: $bottomSheetHeight');
      } else {
        // 펼치기
        bottomSheetHeight = 400.0;
        isBottomSheetExpanded = true;
        developer.log('하단 시트 펼치기: $bottomSheetHeight');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 변경'),
        actions: [
          // 위치 선택 완료 버튼
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // 선택한 위치를 원래 화면으로 전달하고 돌아가기
              developer.log('위치 선택 완료: ${currentLocationCoord!.latitude}, ${currentLocationCoord!.longitude}');
              Navigator.pop(context, currentLocationCoord);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 지도 표시
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLocationCoord!,
              zoom: 15.0,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            onTap: (LatLng position) {
              // 지도 탭하여 위치 변경
              developer.log('지도 탭 위치: ${position.latitude}, ${position.longitude}');
              _updateLocation(position);
            },
          ),

          // 로딩 인디케이터
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

          // 하단 위치 목록
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: bottomSheetHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 드래그 핸들
                  GestureDetector(
                    onTap: _toggleBottomSheetHeight,
                    child: Container(
                      width: double.infinity,
                      height: 24,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // 위치 옵션 버튼들
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.my_location),
                          label: const Text('현재 위치'),
                          onPressed: _getCurrentLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.shuffle),
                          label: const Text('랜덤 위치'),
                          onPressed: _generateRandomLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 위치 목록
                  Expanded(
                    child: ListView.builder(
                      itemCount: predefinedLocations.length,
                      itemBuilder: (context, index) {
                        final location = predefinedLocations[index];
                        return ListTile(
                          title: Text(location.name),
                          subtitle: Text(
                            '${location.coordinates.latitude.toStringAsFixed(4)}, ${location.coordinates.longitude.toStringAsFixed(4)}',
                          ),
                          onTap: () {
                            developer.log('목록에서 위치 선택: ${location.name}');
                            _updateLocation(location.coordinates);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 미리 정의된 위치 데이터 클래스
class PredefinedLocation {
  final String name;
  final LatLng coordinates;

  PredefinedLocation({required this.name, required this.coordinates});
}