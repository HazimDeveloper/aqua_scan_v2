// lib/widgets/admin/google_maps_widget.dart - ENHANCED: Auto Info Window untuk Nearest Route
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  const GoogleMapsRouteWidget({
    Key? key,
    this.polylineRoutes,
    required this.reports,
    this.currentLocation,
    this.onReportTap,
    this.onRouteSelected,
    this.showMultipleRoutes = true,
    this.selectedRouteIndex,
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
  late AnimationController _reporterPulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _reporterPulseAnimation;
  
  // UI State
  int? _selectedRouteIndex;
  ReportModel? _selectedReport;
  Map<String, dynamic>? _selectedRoute;
  bool _showRouteDetails = false;
  bool _showReporterDetails = false;
  double _currentZoom = 12.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _selectedRouteIndex = widget.selectedRouteIndex;
    _updateMarkersAndPolylines();
  }
  
  @override
  void didUpdateWidget(GoogleMapsRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.polylineRoutes != widget.polylineRoutes ||
        oldWidget.selectedRouteIndex != widget.selectedRouteIndex ||
        oldWidget.reports != widget.reports) {
      _selectedRouteIndex = widget.selectedRouteIndex;
      _updateMarkersAndPolylines();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _reporterPulseController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _reporterPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _reporterPulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _reporterPulseController, curve: Curves.easeInOut),
    );
  }
  
  void _updateMarkersAndPolylines() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    
    print('🗺️ Updating map with ${widget.polylineRoutes?.length ?? 0} routes and ${widget.reports.length} reports');
    
    // Add current location marker only if needed
    if (widget.currentLocation != null && _shouldShowCurrentLocationMarker()) {
      newMarkers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines
    if (widget.polylineRoutes != null) {
      for (int i = 0; i < widget.polylineRoutes!.length; i++) {
        final route = widget.polylineRoutes![i];
        
        // Add destination marker with enhanced info window
        final marker = _buildEnhancedRouteMarker(route, i);
        if (marker != null) {
          newMarkers.add(marker);
        }
        
        // Add polyline
        final polyline = _buildRoutePolyline(route, i);
        if (polyline != null) {
          newPolylines.add(polyline);
        }
      }
    }
    
    // Add reporter markers
    for (final report in widget.reports) {
      newMarkers.add(_buildReporterMarker(report));
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _polylines = newPolylines;
      });
      
      print('✅ Map updated: ${_markers.length} markers (${widget.reports.length} reporters), ${_polylines.length} polylines');
    }
  }
  
  bool _shouldShowCurrentLocationMarker() {
    return widget.reports.isEmpty || 
           widget.reports.length < 3 || 
           _currentZoom < 13.0;
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: '📍 Admin Location',
        snippet: 'Current GPS position (${widget.reports.isEmpty ? "no reports" : "${widget.reports.length} reports"})',
      ),
    );
  }
  
  // ENHANCED: Route marker dengan auto info window untuk nearest
  Marker? _buildEnhancedRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble();
    final lng = (destination['longitude'] as num?)?.toDouble();
    
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isShortest = route['is_shortest'] == true;
    final isNearest = route['is_nearest'] == true; // NEW: Check if nearest
    final showInfoWindow = route['show_info_window'] == true; // NEW: Auto show info window
    
    // Determine marker color and icon
    BitmapDescriptor markerIcon;
    if (isNearest) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed); // Red for nearest
    } else if (isShortest) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen); // Green for shortest
    } else if (isSelected) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue); // Blue for selected
    } else {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(index));
    }
    
    // Build info window
    InfoWindow infoWindow;
    if (showInfoWindow && isNearest) {
      // ENHANCED: Special info window for nearest route
      infoWindow = InfoWindow(
        title: route['info_window_title'] ?? '🎯 NEAREST ROUTE',
        snippet: route['info_window_snippet'] ?? _buildNearestRouteSnippet(route, index),
        onTap: () => _onRouteMarkerTap(route, index),
      );
    } else {
      // Standard info window
      infoWindow = InfoWindow(
        title: _buildRouteTitle(route, index, isShortest, isNearest),
        snippet: _buildRouteSnippet(route, index, isShortest, isNearest),
        onTap: () => _onRouteMarkerTap(route, index),
      );
    }
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: markerIcon,
      infoWindow: infoWindow,
      onTap: () {
        _onRouteMarkerTap(route, index);
      },
    );
  }
  
  // NEW: Build enhanced title for route markers
  String _buildRouteTitle(Map<String, dynamic> route, int index, bool isShortest, bool isNearest) {
    String title = route['destination_name'] ?? 'Water Supply ${index + 1}';
    
    if (isNearest) {
      return '🎯 $title';
    } else if (isShortest) {
      return '🌟 $title';
    }
    
    return title;
  }
  
  // NEW: Build enhanced snippet for route markers
  String _buildRouteSnippet(Map<String, dynamic> route, int index, bool isShortest, bool isNearest) {
    final distance = '${(route['distance'] as num?)?.toStringAsFixed(1) ?? '?'}km';
    final time = route['travel_time'] ?? '? min';
    
    String snippet = '$distance • $time';
    
    if (isNearest) {
      snippet += ' • 🎯 NEAREST & RECOMMENDED';
    } else if (isShortest) {
      snippet += ' • 🏆 SHORTEST ROUTE';
    }
    
    final routeSource = route['route_source'] as String?;
    if (routeSource == 'google_directions_api') {
      snippet += ' • 🗺️ Google';
    } else if (routeSource == 'genetic_algorithm') {
      snippet += ' • 🧬 AI Optimized';
    }
    
    return snippet;
  }
  
  // NEW: Build special snippet for nearest route
  String _buildNearestRouteSnippet(Map<String, dynamic> route, int index) {
    final distance = '${(route['distance'] as num?)?.toStringAsFixed(1) ?? '?'}km';
    final time = route['travel_time'] ?? '? min';
    
    return '$distance away • $time drive • RECOMMENDED ROUTE';
  }
  
  Polyline? _buildRoutePolyline(Map<String, dynamic> route, int index) {
    final polylinePoints = route['polyline_points'] as List<dynamic>?;
    
    if (polylinePoints == null || polylinePoints.isEmpty) {
      return null;
    }
    
    final points = <LatLng>[];
    
    for (final point in polylinePoints) {
      if (point is Map<String, dynamic>) {
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    
    if (points.length < 2) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isShortest = route['is_shortest'] == true;
    final isNearest = route['is_nearest'] == true; // NEW: Check nearest
    
    Color routeColor;
    int strokeWidth;
    double opacity;
    List<PatternItem> patterns = [];
    
    if (isNearest) {
      // ENHANCED: Special styling for nearest route
      routeColor = Colors.red.shade600; // Bright red for nearest
      strokeWidth = 8;
      opacity = 1.0;
      patterns = [PatternItem.dash(20), PatternItem.gap(10)]; // Special dashed pattern
    } else if (isShortest) {
      routeColor = Colors.green;
      strokeWidth = 6;
      opacity = 0.9;
      patterns = [PatternItem.dash(15), PatternItem.gap(8)];
    } else if (isSelected) {
      routeColor = Colors.blue;
      strokeWidth = 6;
      opacity = 0.8;
      patterns = [PatternItem.dash(10), PatternItem.gap(5)];
    } else {
      routeColor = _getRouteColor(index);
      strokeWidth = 4;
      opacity = 0.6;
    }
    
    return Polyline(
      polylineId: PolylineId('route_$index'),
      points: points,
      color: routeColor.withOpacity(opacity),
      width: strokeWidth,
      geodesic: true,
      patterns: patterns,
    );
  }
  
  Marker _buildReporterMarker(ReportModel report) {
    final isSelected = _selectedReport?.id == report.id;
    
    return Marker(
      markerId: MarkerId('reporter_${report.id}'),
      position: LatLng(report.location.latitude, report.location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(_getReporterMarkerHue(report.waterQuality)),
      infoWindow: InfoWindow(
        title: '📋 ${report.title}',
        snippet: 'By: ${report.userName} • ${_getWaterQualityDisplayName(report.waterQuality)}',
      ),
      onTap: () => _onReporterMarkerTap(report),
    );
  }
  
  double _getReporterMarkerHue(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return BitmapDescriptor.hueBlue;
      case WaterQualityState.lowTemp:
        return BitmapDescriptor.hueCyan;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return BitmapDescriptor.hueOrange;
      case WaterQualityState.highPhTemp:
        return BitmapDescriptor.hueRed;
      case WaterQualityState.lowTempHighPh:
        return BitmapDescriptor.hueViolet;
      case WaterQualityState.unknown:
      default:
        return BitmapDescriptor.hueYellow;
    }
  }
  
  String _getWaterQualityDisplayName(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum Quality';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.highPhTemp:
        return 'High pH & Temp';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Contaminated Water';
    }
  }
  
  void _onRouteMarkerTap(Map<String, dynamic> route, int index) {
    setState(() {
      if (_selectedRouteIndex == index) {
        _selectedRouteIndex = null;
        _selectedRoute = null;
        _showRouteDetails = false;
      } else {
        _selectedRouteIndex = index;
        _selectedRoute = route;
        _showRouteDetails = true;
        _selectedReport = null;
        _showReporterDetails = false;
      }
    });
    
    _updateMarkersAndPolylines();
    widget.onRouteSelected?.call(_selectedRouteIndex ?? -1);
    _zoomToRoute(route);
  }
  
  void _onReporterMarkerTap(ReportModel report) {
    setState(() {
      if (_selectedReport?.id == report.id) {
        _selectedReport = null;
        _showReporterDetails = false;
      } else {
        _selectedReport = report;
        _showReporterDetails = true;
        _selectedRouteIndex = null;
        _selectedRoute = null;
        _showRouteDetails = false;
      }
    });
    
    widget.onReportTap?.call(report);
    _zoomToLocation(LatLng(report.location.latitude, report.location.longitude));
  }
  
  void _zoomToRoute(Map<String, dynamic> route) {
    final polylinePoints = route['polyline_points'] as List<dynamic>?;
    if (polylinePoints == null || polylinePoints.isEmpty || _mapController == null) {
      return;
    }
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final point in polylinePoints) {
      if (point is Map<String, dynamic>) {
        final lat = (point['latitude'] as num?)?.toDouble();
        final lng = (point['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          minLat = math.min(minLat, lat);
          maxLat = math.max(maxLat, lat);
          minLng = math.min(minLng, lng);
          maxLng = math.max(maxLng, lng);
        }
      }
    }
    
    if (minLat != double.infinity) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }
  
  void _zoomToLocation(LatLng location) {
    if (_mapController == null) return;
    
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 16.0,
        ),
      ),
    );
  }
  
  void _fitAllRoutes() {
    if (_mapController == null) return;
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    bool hasValidCoordinates = false;
    
    if (widget.currentLocation != null && _shouldShowCurrentLocationMarker()) {
      minLat = math.min(minLat, widget.currentLocation!.latitude);
      maxLat = math.max(maxLat, widget.currentLocation!.latitude);
      minLng = math.min(minLng, widget.currentLocation!.longitude);
      maxLng = math.max(maxLng, widget.currentLocation!.longitude);
      hasValidCoordinates = true;
    }
    
    if (widget.polylineRoutes != null) {
      for (final route in widget.polylineRoutes!) {
        final polylinePoints = route['polyline_points'] as List<dynamic>?;
        if (polylinePoints != null) {
          for (final point in polylinePoints) {
            if (point is Map<String, dynamic>) {
              final lat = (point['latitude'] as num?)?.toDouble();
              final lng = (point['longitude'] as num?)?.toDouble();
              
              if (lat != null && lng != null) {
                minLat = math.min(minLat, lat);
                maxLat = math.max(maxLat, lat);
                minLng = math.min(minLng, lng);
                maxLng = math.max(maxLng, lng);
                hasValidCoordinates = true;
              }
            }
          }
        }
      }
    }
    
    for (final report in widget.reports) {
      minLat = math.min(minLat, report.location.latitude);
      maxLat = math.max(maxLat, report.location.latitude);
      minLng = math.min(minLng, report.location.longitude);
      maxLng = math.max(maxLng, report.location.longitude);
      hasValidCoordinates = true;
    }
    
    if (hasValidCoordinates && minLat != double.infinity) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      );
    }
  }
  
  Color _getRouteColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
    ];
    return colors[index % colors.length];
  }
  
  double _getMarkerHue(int index) {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueMagenta,
      BitmapDescriptor.hueAzure,
      BitmapDescriptor.hueRose,
    ];
    return hues[index % hues.length];
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null && widget.reports.isEmpty) {
      return _buildNoDataView();
    }
    
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        print('🗺️ Google Map created successfully');
        
        Future.delayed(Duration(milliseconds: 500), () {
          _fitAllRoutes();
        });
      },
      initialCameraPosition: CameraPosition(
        target: widget.reports.isNotEmpty 
          ? LatLng(widget.reports.first.location.latitude, widget.reports.first.location.longitude)
          : LatLng(
              widget.currentLocation?.latitude ?? 3.1390,
              widget.currentLocation?.longitude ?? 101.6869,
            ),
        zoom: 12.0,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: true,
      compassEnabled: true,
      mapType: MapType.normal,
      trafficEnabled: true,
      onCameraMove: (CameraPosition position) {
        _currentZoom = position.zoom;
        if ((_currentZoom < 13.0) != _shouldShowCurrentLocationMarker()) {
          _updateMarkersAndPolylines();
        }
      },
      onTap: (LatLng latLng) {
        setState(() {
          _selectedRouteIndex = null;
          _selectedRoute = null;
          _showRouteDetails = false;
          _selectedReport = null;
          _showReporterDetails = false;
        });
        _updateMarkersAndPolylines();
        widget.onRouteSelected?.call(-1);
      },
    );
  }
  
  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "No data available",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "No location data, routes, or reports found",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}