// lib/widgets/admin/google_maps_widget.dart - SIMPLIFIED VERSION WITHOUT CLUSTERING
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/api_service.dart';

class GoogleMapsRouteWidget extends StatefulWidget {
  final List<Map<String, dynamic>>? polylineRoutes;
  final List<ReportModel> reports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final Function(int)? onRouteSelected;
  final bool showMultipleRoutes;
  final int? selectedRouteIndex;
  final bool enableGeneticAlgorithm;
  final GAParameters? gaParameters;

  const GoogleMapsRouteWidget({
    Key? key,
    this.polylineRoutes,
    required this.reports,
    this.currentLocation,
    this.onReportTap,
    this.onRouteSelected,
    this.showMultipleRoutes = true,
    this.selectedRouteIndex,
    this.enableGeneticAlgorithm = true,
    this.gaParameters,
  }) : super(key: key);

  @override
  _GoogleMapsRouteWidgetState createState() => _GoogleMapsRouteWidgetState();
}

class _GoogleMapsRouteWidgetState extends State<GoogleMapsRouteWidget>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedRouteIndex;
  List<Map<String, dynamic>> _sortedRoutes = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRoutes();
  }
  
  @override
  void didUpdateWidget(GoogleMapsRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.polylineRoutes != widget.polylineRoutes) {
      _initializeRoutes();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  void _initializeRoutes() {
    if (widget.polylineRoutes != null) {
      _sortedRoutes = List<Map<String, dynamic>>.from(widget.polylineRoutes!);
      
      // Sort by distance (default)
      _sortedRoutes.sort((a, b) {
        final distanceA = (a['distance'] as num?)?.toDouble() ?? 0.0;
        final distanceB = (b['distance'] as num?)?.toDouble() ?? 0.0;
        return distanceA.compareTo(distanceB);
      });
      
      _updateMarkersAndPolylines();
    }
  }
  
  void _updateMarkersAndPolylines() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    
    // Add current location marker
    if (widget.currentLocation != null) {
      newMarkers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines
    for (int i = 0; i < _sortedRoutes.length; i++) {
      final route = _sortedRoutes[i];
      
      // Add destination marker
      newMarkers.add(_buildRouteMarker(route, i));
      
      // Add polyline
      newPolylines.addAll(_buildRoutePolylines(route, i));
    }
    
    // Add report markers
    for (final report in widget.reports) {
      newMarkers.add(_buildReportMarker(report));
    }
    
    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(
        title: 'Your Location',
        snippet: 'Current GPS position',
      ),
    );
  }
  
  Marker _buildRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (destination['longitude'] as num?)?.toDouble() ?? 0.0;
    
    final isSelected = _selectedRouteIndex == index;
    final isNearest = index == 0;
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isNearest ? BitmapDescriptor.hueGreen :
        isSelected ? BitmapDescriptor.hueBlue :
        _getMarkerHue(index),
      ),
      infoWindow: InfoWindow(
        title: route['destination_name'] ?? 'Water Supply ${index + 1}',
        snippet: _buildRouteSnippet(route, index),
      ),
      onTap: () {
        setState(() {
          _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
        });
        widget.onRouteSelected?.call(index);
      },
    );
  }
  
  String _buildRouteSnippet(Map<String, dynamic> route, int index) {
    final distance = '${route['distance']?.toStringAsFixed(1)}km';
    final time = route['travel_time'];
    final isNearest = index == 0;
    
    String snippet = '$distance • $time';
    
    if (isNearest) {
      snippet += ' • NEAREST ROUTE';
    }
    
    snippet += ' • Driving';
    
    return snippet;
  }
  
  Marker _buildReportMarker(ReportModel report) {
    return Marker(
      markerId: MarkerId('report_${report.id}'),
      position: LatLng(report.location.latitude, report.location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: report.title,
        snippet: '${report.waterQuality.name} • ${report.address}',
      ),
      onTap: () => widget.onReportTap?.call(report),
    );
  }
  
  List<Polyline> _buildRoutePolylines(Map<String, dynamic> route, int index) {
    final polylines = <Polyline>[];
    
    if (route.containsKey('polyline_points') && route['polyline_points'] is List) {
      final polylineData = route['polyline_points'] as List<dynamic>;
      final points = <LatLng>[];
      
      for (final point in polylineData) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      
      if (points.length >= 2) {
        final isSelected = _selectedRouteIndex == index;
        final isNearest = index == 0;
        
        Color routeColor;
        int strokeWidth;
        
        if (isNearest) {
          routeColor = Colors.green;
          strokeWidth = 6;
        } else if (isSelected) {
          routeColor = Colors.blue;
          strokeWidth = 5;
        } else {
          routeColor = _getRouteColor(index);
          strokeWidth = 3;
        }
        
        // Main route polyline
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_$index'),
            points: points,
            color: routeColor,
            width: strokeWidth,
            geodesic: true,
          ),
        );
        
        // Add shadow effect for nearest route
        if (isNearest) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('route_${index}_shadow'),
              points: points,
              color: routeColor.withOpacity(0.3),
              width: strokeWidth + 3,
              geodesic: true,
            ),
          );
        }
      }
    }
    
    return polylines;
  }
  
  void _updateMapBounds() {
    if (_mapController == null || _sortedRoutes.isEmpty) return;
    
    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }
  
  LatLngBounds _calculateBounds() {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    // Include current location
    if (widget.currentLocation != null) {
      minLat = math.min(minLat, widget.currentLocation!.latitude);
      maxLat = math.max(maxLat, widget.currentLocation!.latitude);
      minLng = math.min(minLng, widget.currentLocation!.longitude);
      maxLng = math.max(maxLng, widget.currentLocation!.longitude);
    }
    
    // Include route destinations
    for (final route in _sortedRoutes) {
      final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destination['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (destination['longitude'] as num?)?.toDouble() ?? 0.0;
      
      if (lat != 0.0 && lng != 0.0) {
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLng = math.min(minLng, lng);
        maxLng = math.max(maxLng, lng);
      }
    }
    
    // Include report locations
    for (final report in widget.reports) {
      minLat = math.min(minLat, report.location.latitude);
      maxLat = math.max(maxLat, report.location.latitude);
      minLng = math.min(minLng, report.location.longitude);
      maxLng = math.max(maxLng, report.location.longitude);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  Color _getRouteColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }
  
  double _getMarkerHue(int index) {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueMagenta,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueRose,
      BitmapDescriptor.hueAzure,
    ];
    return hues[index % hues.length];
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null && widget.reports.isEmpty && 
        (widget.polylineRoutes?.isEmpty ?? true)) {
      return _buildNoDataView();
    }
    
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _updateMapBounds();
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
              widget.currentLocation?.latitude ?? 3.1390,
              widget.currentLocation?.longitude ?? 101.6869,
            ),
            zoom: 12.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
          trafficEnabled: true,
          onTap: (_) {
            setState(() {
              _selectedRouteIndex = null;
            });
          },
        ),
        
        // Info panel
        if (_sortedRoutes.isNotEmpty)
          _buildTopInfoPanel(),
        
        // Error message
        if (_errorMessage != null)
          _buildErrorMessage(),
      ],
    );
  }
  
  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No driving routes available",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "No location data or routes found",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopInfoPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.route, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_sortedRoutes.length} routes found • Google Maps',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}