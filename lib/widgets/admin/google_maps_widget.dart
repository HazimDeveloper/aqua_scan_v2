// lib/widgets/admin/google_maps_widget.dart - ENHANCED: Reporter Locations + Conditional Current Location
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
  late AnimationController _reporterPulseController; // ADDED: For reporter markers
  late Animation<double> _pulseAnimation;
  late Animation<double> _reporterPulseAnimation; // ADDED
  
  // UI State
  int? _selectedRouteIndex;
  ReportModel? _selectedReport; // ADDED: Track selected report
  Map<String, dynamic>? _selectedRoute;
  bool _showRouteDetails = false;
  bool _showReporterDetails = false; // ADDED
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
        oldWidget.reports != widget.reports) { // ADDED: Check reports changes
      _selectedRouteIndex = widget.selectedRouteIndex;
      _updateMarkersAndPolylines();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _reporterPulseController.dispose(); // ADDED
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    // ADDED: Reporter markers animation
    _reporterPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // ADDED: Reporter pulse animation
    _reporterPulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _reporterPulseController, curve: Curves.easeInOut),
    );
  }
  
  void _updateMarkersAndPolylines() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    
    print('🗺️ Updating map with ${widget.polylineRoutes?.length ?? 0} routes and ${widget.reports.length} reports');
    
    // ENHANCED: Conditional current location marker - only show if no reports OR if admin needs reference point
    if (widget.currentLocation != null && _shouldShowCurrentLocationMarker()) {
      newMarkers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines
    if (widget.polylineRoutes != null) {
      for (int i = 0; i < widget.polylineRoutes!.length; i++) {
        final route = widget.polylineRoutes![i];
        
        // Add destination marker
        final marker = _buildRouteMarker(route, i);
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
    
    // ADDED: Add reporter markers
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
  
  // ADDED: Determine if current location marker should be shown
  bool _shouldShowCurrentLocationMarker() {
    // Show current location if:
    // 1. No reports exist (water supply network only)
    // 2. Less than 3 reports (need reference point)
    // 3. Map is zoomed out (provides context)
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
  
  Marker? _buildRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble();
    final lng = (destination['longitude'] as num?)?.toDouble();
    
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isShortest = route['is_shortest'] == true; // ENHANCED: Check shortest route flag
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isShortest ? BitmapDescriptor.hueGreen : // ENHANCED: Green for shortest
        isSelected ? BitmapDescriptor.hueBlue :
        _getMarkerHue(index),
      ),
      infoWindow: InfoWindow(
        title: '${isShortest ? "🌟 " : ""}${route['destination_name'] ?? 'Water Supply ${index + 1}'}', // ENHANCED: Star for shortest
        snippet: _buildRouteSnippet(route, index, isShortest),
      ),
      onTap: () {
        _onRouteMarkerTap(route, index);
      },
    );
  }
  
  String _buildRouteSnippet(Map<String, dynamic> route, int index, bool isShortest) {
    final distance = '${(route['distance'] as num?)?.toStringAsFixed(1) ?? '?'}km';
    final time = route['travel_time'] ?? '? min';
    
    String snippet = '$distance • $time';
    
    if (isShortest) {
      snippet += ' • 🏆 SHORTEST ROUTE'; // ENHANCED: Better shortest route indicator
    }
    
    final routeSource = route['route_source'] as String?;
    if (routeSource == 'google_directions') {
      snippet += ' • 🗺️ Google';
    } else if (routeSource == 'enhanced_fallback') {
      snippet += ' • 🛣️ Enhanced';
    }
    
    return snippet;
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
    final isShortest = route['is_shortest'] == true; // ENHANCED
    
    Color routeColor;
    int strokeWidth;
    double opacity;
    
    if (isShortest) {
      // ENHANCED: Special styling for shortest route
      routeColor = Colors.green;
      strokeWidth = 8;
      opacity = 0.9;
    } else if (isSelected) {
      routeColor = Colors.blue;
      strokeWidth = 6;
      opacity = 0.8;
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
      patterns: isSelected ? [PatternItem.dash(10), PatternItem.gap(5)] : 
               isShortest ? [PatternItem.dash(15), PatternItem.gap(8)] : [], // ENHANCED: Dashed pattern for shortest
    );
  }
  
  // ADDED: Build reporter marker
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
  
  // ADDED: Get reporter marker color based on water quality
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
  
  // ADDED: Get user-friendly water quality name
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
        // Clear reporter selection
        _selectedReport = null;
        _showReporterDetails = false;
      }
    });
    
    _updateMarkersAndPolylines();
    widget.onRouteSelected?.call(_selectedRouteIndex ?? -1);
    _zoomToRoute(route);
  }
  
  // ADDED: Handle reporter marker tap
  void _onReporterMarkerTap(ReportModel report) {
    setState(() {
      if (_selectedReport?.id == report.id) {
        _selectedReport = null;
        _showReporterDetails = false;
      } else {
        _selectedReport = report;
        _showReporterDetails = true;
        // Clear route selection
        _selectedRouteIndex = null;
        _selectedRoute = null;
        _showRouteDetails = false;
      }
    });
    
    // Notify parent
    widget.onReportTap?.call(report);
    
    // Zoom to report location
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
  
  // ADDED: Zoom to specific location
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
    
    // Include current location if shown
    if (widget.currentLocation != null && _shouldShowCurrentLocationMarker()) {
      minLat = math.min(minLat, widget.currentLocation!.latitude);
      maxLat = math.max(maxLat, widget.currentLocation!.latitude);
      minLng = math.min(minLng, widget.currentLocation!.longitude);
      maxLng = math.max(maxLng, widget.currentLocation!.longitude);
      hasValidCoordinates = true;
    }
    
    // Include all route points
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
    
    // ADDED: Include all reporter locations
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
    
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            print('🗺️ Google Map created successfully');
            
            Future.delayed(Duration(milliseconds: 500), () {
              _fitAllRoutes();
            });
          },
          initialCameraPosition: CameraPosition(
            target: widget.reports.isNotEmpty 
              ? LatLng(widget.reports.first.location.latitude, widget.reports.first.location.longitude) // ENHANCED: Focus on reports if available
              : LatLng(
                  widget.currentLocation?.latitude ?? 3.1390,
                  widget.currentLocation?.longitude ?? 101.6869,
                ),
            zoom: 12.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: false, // ENHANCED: Disable since we show custom marker
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: true,
          compassEnabled: true,
          mapType: MapType.normal,
          trafficEnabled: true,
          onCameraMove: (CameraPosition position) {
            _currentZoom = position.zoom;
            // Update current location marker visibility based on zoom
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
        ),
        
        // Top info panel - ENHANCED with reporter info
        _buildTopInfoPanel(),
        
        // Zoom controls
        _buildZoomControls(),
        
        // Route details panel
        if (_showRouteDetails && _selectedRoute != null)
          _buildRouteDetailsPanel(),
        
        // ADDED: Reporter details panel
        if (_showReporterDetails && _selectedReport != null)
          _buildReporterDetailsPanel(),
        
        // Map controls
        _buildMapControls(),
      ],
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
  
  Widget _buildTopInfoPanel() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // ENHANCED: Show different title based on data
                      widget.reports.isEmpty ? 'Water Supply Network' : 'Admin Dashboard',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      // ENHANCED: Better subtitle with reporter info
                      widget.reports.isEmpty 
                        ? '${widget.polylineRoutes?.length ?? 0} water supplies • No reports'
                        : '${widget.polylineRoutes?.length ?? 0} supplies • ${widget.reports.length} reports • Zoom: ${_currentZoom.toStringAsFixed(1)}x',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // ENHANCED: Show current location status
              if (!_shouldShowCurrentLocationMarker() && widget.currentLocation != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    'FOCUS MODE',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      top: 100,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            IconButton(
              icon: Icon(Icons.zoom_in),
              onPressed: () {
                _mapController?.animateCamera(CameraUpdate.zoomIn());
              },
            ),
            Container(height: 1, width: 30, color: Colors.grey.shade300),
            IconButton(
              icon: Icon(Icons.zoom_out),
              onPressed: () {
                _mapController?.animateCamera(CameraUpdate.zoomOut());
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: _showRouteDetails || _showReporterDetails ? 320 : 100,
      child: Column(
        children: [
          // Fit all button
          FloatingActionButton(
            heroTag: "fit_all",
            mini: true,
            onPressed: _fitAllRoutes,
            child: Icon(Icons.center_focus_strong),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          SizedBox(height: 8),
          // My location button (only show if current location available)
          if (widget.currentLocation != null)
            FloatingActionButton(
              heroTag: "my_location",
              mini: true,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        widget.currentLocation!.latitude,
                        widget.currentLocation!.longitude,
                      ),
                      zoom: 15.0,
                    ),
                  ),
                );
              },
              child: Icon(_shouldShowCurrentLocationMarker() ? Icons.my_location : Icons.location_searching),
              backgroundColor: _shouldShowCurrentLocationMarker() ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
        ],
      ),
    );
  }
  
  Widget _buildRouteDetailsPanel() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedRoute!['is_shortest'] == true ? Colors.green : Colors.blue, // ENHANCED
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _selectedRoute!['is_shortest'] == true 
                        ? Icon(Icons.star, color: Colors.white, size: 16) // ENHANCED: Star for shortest
                        : Text(
                            '${(_selectedRouteIndex ?? 0) + 1}',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // ENHANCED: Show shortest route indicator
                          _selectedRoute!['is_shortest'] == true 
                            ? '🏆 Shortest Route'
                            : _selectedRoute!['destination_name'] ?? 'Water Supply',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: _selectedRoute!['is_shortest'] == true ? Colors.green : Colors.blue,
                          ),
                        ),
                        Text(
                          _selectedRoute!['destination_address'] ?? 'Terengganu Water Infrastructure',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedRouteIndex = null;
                        _selectedRoute = null;
                        _showRouteDetails = false;
                      });
                      _updateMarkersAndPolylines();
                      widget.onRouteSelected?.call(-1);
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Route details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.straighten,
                      'Distance',
                      '${(_selectedRoute!['distance'] as num?)?.toStringAsFixed(1) ?? '?'} km',
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.access_time,
                      'Travel Time',
                      _selectedRoute!['travel_time'] ?? '? min',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.flag,
                      'Priority',
                      _selectedRoute!['is_shortest'] == true ? 'Shortest Route' : 'Route ${(_selectedRouteIndex ?? 0) + 1}', // ENHANCED
                      _selectedRoute!['is_shortest'] == true ? Colors.green : Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.route,
                      'Source',
                      _getRouteSourceLabel(_selectedRoute!['route_source'] as String?),
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _zoomToRoute(_selectedRoute!);
                      },
                      icon: Icon(Icons.zoom_in_map, size: 18),
                      label: Text('Zoom to Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        print('🚗 Navigate to: ${_selectedRoute!['destination_name']}');
                      },
                      icon: Icon(Icons.navigation, size: 18),
                      label: Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ADDED: Reporter details panel
  Widget _buildReporterDetailsPanel() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade50, Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getReporterColor(_selectedReport!.waterQuality),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.report_problem, color: Colors.white, size: 16),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedReport!.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        ),
                        Text(
                          'Reporter: ${_selectedReport!.userName}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedReport = null;
                        _showReporterDetails = false;
                      });
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Report details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.water_drop,
                      'Water Quality',
                      _getWaterQualityDisplayName(_selectedReport!.waterQuality),
                      _getReporterColor(_selectedReport!.waterQuality),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.schedule,
                      'Reported',
                      '${_selectedReport!.createdAt.day}/${_selectedReport!.createdAt.month}',
                      Colors.grey,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Description
              if (_selectedReport!.description.isNotEmpty) ...[
                Text(
                  'Description:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                ),
                SizedBox(height: 4),
                Text(
                  _selectedReport!.description,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
              ],
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _zoomToLocation(LatLng(_selectedReport!.location.latitude, _selectedReport!.location.longitude));
                      },
                      icon: Icon(Icons.zoom_in_map, size: 18),
                      label: Text('Zoom to Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Find nearest water supply
                        _findAndShowNearestWaterSupply();
                      },
                      icon: Icon(Icons.water_drop, size: 18),
                      label: Text('Nearest Supply'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ADDED: Find and highlight nearest water supply to reporter
  void _findAndShowNearestWaterSupply() {
    if (_selectedReport == null || widget.polylineRoutes == null) return;
    
    double nearestDistance = double.infinity;
    int nearestIndex = -1;
    
    for (int i = 0; i < widget.polylineRoutes!.length; i++) {
      final route = widget.polylineRoutes![i];
      final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destination['latitude'] as num?)?.toDouble();
      final lng = (destination['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final distance = _calculateDistance(
          _selectedReport!.location.latitude,
          _selectedReport!.location.longitude,
          lat,
          lng,
        );
        
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }
    }
    
    if (nearestIndex >= 0) {
      setState(() {
        _selectedRouteIndex = nearestIndex;
        _selectedRoute = widget.polylineRoutes![nearestIndex];
        _showRouteDetails = true;
        _showReporterDetails = false;
      });
      
      _updateMarkersAndPolylines();
      widget.onRouteSelected?.call(nearestIndex);
      _zoomToRoute(widget.polylineRoutes![nearestIndex]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nearest water supply: ${nearestDistance.toStringAsFixed(1)} km away'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  
  // ADDED: Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  // ADDED: Get reporter marker color
  Color _getReporterColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.cyan;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Colors.orange;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  String _getRouteSourceLabel(String? source) {
    switch (source) {
      case 'google_directions':
        return 'Google Maps';
      case 'enhanced_fallback':
        return 'Enhanced Route';
      case 'offline_fallback':
        return 'Offline Route';
      default:
        return 'Basic Route';
    }
  }
}