import 'dart:async';
import 'dart:convert';

import 'package:fluster/fluster.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skrapai/screens/autogenerated.dart';
import 'package:http/http.dart' as http;
import 'map_helper.dart';
import 'map_marker.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Future<Autogenerated> fetchData;
  @override
  void initState() {
    super.initState();
    fetchData = fecthData();
    getData();
  }

  Future<Autogenerated> fecthData() async {
    var params = {
      'latitude': '41.99793319188289',
      'longitude': '21.400423049926758',
      'other_latitude': '42.01186906039471',
      'other_longitude': '21.43436908721924',
    };
    var query = params.entries.map((p) => '${p.key}=${p.value}').join('&');

    var res = await http.get(Uri.http(
        '0.0.0.0:8000/?latitude=52.32946474208912&longitude=12.904815673828125&other_latitude=52.685540255966465&other_longitude=13.9910888671875',
        '/'));
    if (res.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return Autogenerated.fromJson(jsonDecode(res.body));
    }
    if (res.statusCode != 200) {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('http.get error: statusCode= ${res.statusCode}');
    }
  }

  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = Set();
  final int _minClusterZoom = 0;
  final int _maxClusterZoom = 19;
  Fluster<MapMarker> _clusterManager;
  double _currentZoom = 15;
  bool _isMapLoading = true;
  bool _areMarkersLoading = true;

  final String _markerImageUrl =
      'https://img.icons8.com/office/80/000000/marker.png';

  final Color _clusterColor = Colors.blue;

  final Color _clusterTextColor = Colors.white;

  getData() {
    List lat = [];
    FutureBuilder<Autogenerated>(
      future: fetchData,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _markerLocations
              .add(LatLng(snapshot.data.longitude, snapshot.data.latitude));
          print(lat);
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}");
        }

        // By default, show a loading spinner.
        return CircularProgressIndicator();
      },
    );
  }

  final List<LatLng> _markerLocations = [
    LatLng(52.32946474208912, 12.904815673828125),
    LatLng(52.685540255966465, 13.9910888671875),
    LatLng(40.700682761880564, -74.1020965576171),
    LatLng(40.81147063339219, -73.83052825927734),
  ];

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);

    setState(() {
      _isMapLoading = false;
    });

    _initMarkers();
  }

  void _initMarkers() async {
    final List<MapMarker> markers = [];

    for (LatLng markerLocation in _markerLocations) {
      final BitmapDescriptor markerImage =
          await MapHelper.getMarkerImageFromUrl(_markerImageUrl);

      markers.add(
        MapMarker(
          id: _markerLocations.indexOf(markerLocation).toString(),
          position: markerLocation,
          icon: markerImage,
        ),
      );
    }

    _clusterManager = await MapHelper.initClusterManager(
      markers,
      _minClusterZoom,
      _maxClusterZoom,
    );

    await _updateMarkers();
  }

  Future<void> _updateMarkers([double updatedZoom]) async {
    if (_clusterManager == null || updatedZoom == _currentZoom) return;

    if (updatedZoom != null) {
      _currentZoom = updatedZoom;
    }

    setState(() {
      _areMarkersLoading = true;
    });

    final updatedMarkers = await MapHelper.getClusterMarkers(
      _clusterManager,
      _currentZoom,
      _clusterColor,
      _clusterTextColor,
      80,
    );

    _markers
      ..clear()
      ..addAll(updatedMarkers);

    setState(() {
      _areMarkersLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: Text(
          "RECYCLING CENTERS",
          style: TextStyle(color: Colors.greenAccent, fontFamily: 'Oswald'),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(20),
            width: size.width,
            height: size.height - 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: <Widget>[
                // Google Map widget
                Opacity(
                  opacity: _isMapLoading ? 0 : 1,
                  child: GoogleMap(
                    mapToolbarEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(52.32946474208912, 12.904815673828125),
                      zoom: 7,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) => _onMapCreated(controller),
                    onCameraMove: (position) => _updateMarkers(position.zoom),
                  ),
                ),

                // Map loading indicator
                Opacity(
                  opacity: _isMapLoading ? 1 : 0,
                  child: Center(child: CircularProgressIndicator()),
                ),

                // Map markers loading indicator
                if (_areMarkersLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                        elevation: 2,
                        color: Colors.grey.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            'Loading',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}