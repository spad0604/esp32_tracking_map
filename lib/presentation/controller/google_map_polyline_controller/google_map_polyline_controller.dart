import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:google_map_in_flutter/database/database_helper.dart';
import 'package:google_map_in_flutter/service/firebase_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../model/data_model.dart';

class GoogleMapPolylineController extends SuperController {
  final database = DatabaseHelper.instance;
  final FirebaseService firebaseService = FirebaseService();
  final List<LatLng> pointOnMap = [];

  final RxInt elapsedMinutes = 0.obs;

  Rxn<double> speed = Rxn<double>();
  Rxn<double> distance = Rxn<double>(0.0);

  Rx<bool> isFirstTimeOpen = true.obs;

  Rxn<DataModel> model1 = Rxn<DataModel>();
  Rxn<DataModel> model2 = Rxn<DataModel>();

  Rxn<LatLng> currentLocation = Rxn<LatLng>();
  RxSet<Polyline> polyline = RxSet<Polyline>();
  RxSet<Marker> markers = RxSet<Marker>();

  @override
  void onInit() async {
    final DateTime dateTime = DateTime.now();
    final String formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);


    Timer.periodic(const Duration(minutes: 1), (timer) {
      elapsedMinutes.value += 1;
    });

    int? maxInDay = await database.queryMaxTimeInDayByDateTime(formattedDate);

    firebaseService.getSingleItemStream(maxInDay != null ? maxInDay + 1 : 0).listen((data) async {
      if (data != null) {
        await updateLocationAndMap(data);
      }
    });

    super.onInit();
    initializeMarkersAndPolyline();
  }

  Future<void> updateLocationAndMap(DataModel data) async {
    currentLocation.value = LatLng(data.latitude, data.longtitude);
    speed.value = data.speed;

    if (isFirstTimeOpen.value) {
      model1.value = data;
      isFirstTimeOpen.value = false;
    } else {
      model2.value = model1.value;
      model1.value = data;

      double distanceBetweenPoints = calculateDistance(
          model2.value!.latitude,
          model2.value!.longtitude,
          model1.value!.latitude,
          model1.value!.longtitude
      );

      distance.value = double.parse((distance.value! + distanceBetweenPoints).toStringAsFixed(2));
    }

    await database.insertDataModel(data);

    pointOnMap.add(LatLng(data.latitude, data.longtitude));
    markers.add(
      Marker(
        markerId: MarkerId(pointOnMap.length.toString()),
        position: LatLng(data.latitude, data.longtitude),
        infoWindow: InfoWindow(
          title: "New Location",
          snippet: "Speed: ${data.speed}",
        ),
        icon: BitmapDescriptor.defaultMarker,
      ),
    );

    polyline.clear();
    polyline.add(
      Polyline(
        polylineId: const PolylineId("Id"),
        points: pointOnMap,
        color: Colors.blue,
        width: 5,
      ),
    );

    debugPrint('haloo ${polyline.length}');

  }

  void initializeMarkersAndPolyline() {
    for (int i = 0; i < pointOnMap.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId(i.toString()),
          position: pointOnMap[i],
          infoWindow: const InfoWindow(
            title: "Place around my Country",
            snippet: "So Beautiful",
          ),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
    }

    polyline.add(
      Polyline(
        polylineId: const PolylineId("Id"),
        points: pointOnMap,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    lat1 = lat1 * pi / 180;
    lat2 = lat2 * pi / 180;

    double a = pow(sin(dLat / 2), 2) +
        cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  @override
  void onDetached() {}

  @override
  void onHidden() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {}
}
