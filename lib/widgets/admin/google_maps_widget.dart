// lib/widgets/admin/google_maps_widget.dart - ENHANCED: Added Custom Zoom Controls
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
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
  double _currentZoom = 12.0;
  
  // NEW: Zoom control states
  bool _showZoomControls = true;
  Timer? _hideControlsTimer;
  
  // Address Cache untuk performance
  final Map<String, String> _addressCache = {};
  bool _loadingAddresses = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _selectedRouteIndex = widget.selectedRouteIndex;
    _preloadAddresses();
    _updateMarkersAndPolylines();
    _startHideControlsTimer(); // Auto-hide controls after 3 seconds
  }
  
  @override
  void didUpdateWidget(GoogleMapsRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.polylineRoutes != widget.polylineRoutes ||
        oldWidget.selectedRouteIndex != widget.selectedRouteIndex ||
        oldWidget.reports != widget.reports) {
      _selectedRouteIndex = widget.selectedRouteIndex;
      _preloadAddresses();
      _updateMarkersAndPolylines();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _reporterPulseController.dispose();
    _hideControlsTimer?.cancel();
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
  
  // NEW: Timer functions for auto-hiding controls
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showZoomControls = false;
        });
      }
    });
  }
  
  void _showControlsTemporarily() {
    if (mounted) {
      setState(() {
        _showZoomControls = true;
      });
      _startHideControlsTimer();
    }
  }
  
  // NEW: Zoom control functions
  Future<void> _zoomIn() async {
    if (_mapController != null) {
      final double newZoom = math.min(_currentZoom + 1.0, 20.0);
      await _mapController!.animateCamera(
        CameraUpdate.zoomTo(newZoom),
      );
      setState(() {
        _currentZoom = newZoom;
      });
      _showControlsTemporarily();
    }
  }
  
  Future<void> _zoomOut() async {
    if (_mapController != null) {
      final double newZoom = math.max(_currentZoom - 1.0, 2.0);
      await _mapController!.animateCamera(
        CameraUpdate.zoomTo(newZoom),
      );
      setState(() {
        _currentZoom = newZoom;
      });
      _showControlsTemporarily();
    }
  }
  
  // NEW: Fit all routes with padding
  Future<void> _fitAllRoutes() async {
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
      
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      );
    }
    
    _showControlsTemporarily();
  }
  
  // NEW: Go to current location
  Future<void> _goToCurrentLocation() async {
    if (_mapController != null && widget.currentLocation != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.currentLocation!.latitude,
              widget.currentLocation!.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
      setState(() {
        _currentZoom = 16.0;
      });
      _showControlsTemporarily();
    }
  }
  
  // Preload addresses untuk semua locations
  Future<void> _preloadAddresses() async {
    if (_loadingAddresses) return;
    
    setState(() {
      _loadingAddresses = true;
    });
    
    try {
      print('📍 Loading simple addresses for all locations...');
      
      List<Future<void>> addressFutures = [];
      
      // Load current location address
      if (widget.currentLocation != null) {
        final currentKey = '${widget.currentLocation!.latitude},${widget.currentLocation!.longitude}';
        if (!_addressCache.containsKey(currentKey)) {
          addressFutures.add(_loadSimpleAddressForLocation(
            widget.currentLocation!.latitude,
            widget.currentLocation!.longitude,
            'Current Location'
          ));
        }
      }
      
      // Load route destination addresses
      if (widget.polylineRoutes != null) {
        for (final route in widget.polylineRoutes!) {
          final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
          final lat = (destination['latitude'] as num?)?.toDouble();
          final lng = (destination['longitude'] as num?)?.toDouble();
          
          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            final routeKey = '$lat,$lng';
            if (!_addressCache.containsKey(routeKey)) {
              final name = route['destination_name'] ?? 'Water Supply';
              addressFutures.add(_loadSimpleAddressForLocation(lat, lng, name));
            }
          }
        }
      }
      
      // Load report addresses
      for (final report in widget.reports) {
        final reportKey = '${report.location.latitude},${report.location.longitude}';
        if (!_addressCache.containsKey(reportKey)) {
          addressFutures.add(_loadSimpleAddressForLocation(
            report.location.latitude,
            report.location.longitude,
            report.title
          ));
        }
      }
      
      // Execute all address loading in parallel
      await Future.wait(addressFutures);
      
      print('✅ Simple address loading completed. Cache size: ${_addressCache.length}');
      
      // Update markers dengan addresses yang baru loaded
      if (mounted) {
        _updateMarkersAndPolylines();
      }
      
    } catch (e) {
      print('⚠️ Error loading simple addresses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingAddresses = false;
        });
      }
    }
  }
  
  // Load simple address untuk specific location
  Future<void> _loadSimpleAddressForLocation(double lat, double lng, String fallbackName) async {
    final key = '$lat,$lng';
    
    try {
      final address = await _getSimpleAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _addressCache[key] = address;
        });
      }
      print('📍 Simple address loaded for $fallbackName: $address');
    } catch (e) {
      print('⚠️ Failed to load address for $fallbackName: $e');
      // Use fallback address
      if (mounted) {
        setState(() {
          _addressCache[key] = 'Near $fallbackName';
        });
      }
    }
  }
  
  // Get simple address dari coordinates
  Future<String> _getSimpleAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        // Build simple address (cuma main parts sahaja)
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        
        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        } else {
          return 'Location at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
        }
      }
      
      return 'Unknown location';
    } catch (e) {
      print('Geocoding error: $e');
      return 'Location at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }
  
  // Get cached address atau loading message
  String _getCachedAddress(double lat, double lng, {String fallback = 'Loading address...'}) {
    final key = '$lat,$lng';
    return _addressCache[key] ?? fallback;
  }
  
  void _updateMarkersAndPolylines() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    
    print('🗺️ Updating map with ${widget.polylineRoutes?.length ?? 0} routes and ${widget.reports.length} reports');
    
    // Add current location marker with simple address
    if (widget.currentLocation != null && _shouldShowCurrentLocationMarker()) {
      newMarkers.add(_buildSimpleCurrentLocationMarker());
    }
    
    // Add route markers and polylines with simple addresses
    if (widget.polylineRoutes != null) {
      for (int i = 0; i < widget.polylineRoutes!.length; i++) {
        final route = widget.polylineRoutes![i];
        
        // Add destination marker with simple address info
        final marker = _buildSimpleRouteMarker(route, i);
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
    
    // Add reporter markers with simple addresses
    for (final report in widget.reports) {
      newMarkers.add(_buildSimpleReporterMarker(report));
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _polylines = newPolylines;
      });
      
      print('✅ Map updated: ${_markers.length} markers, ${_polylines.length} polylines');
    }
  }
  
  bool _shouldShowCurrentLocationMarker() {
    return widget.reports.isEmpty || 
           widget.reports.length < 3 || 
           _currentZoom < 13.0;
  }
  
  // Current location marker dengan simple address
  Marker _buildSimpleCurrentLocationMarker() {
    final currentLat = widget.currentLocation!.latitude;
    final currentLng = widget.currentLocation!.longitude;
    final address = _getCachedAddress(currentLat, currentLng, fallback: 'Getting address...');
    
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(currentLat, currentLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Your Location',
        snippet: address,
      ),
    );
  }
  
  // Route marker dengan simple address info sahaja
  Marker? _buildSimpleRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble();
    final lng = (destination['longitude'] as num?)?.toDouble();
    
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return null;
    }
    
    final isSelected = _selectedRouteIndex == index;
    final isShortest = route['is_shortest'] == true;
    final isNearest = route['is_nearest'] == true;
    
    // Get simple address dari cache
    final simpleAddress = _getCachedAddress(lat, lng, fallback: 'Loading address...');
    
    // Determine marker color
    BitmapDescriptor markerIcon;
    if (isNearest) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (isShortest) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (isSelected) {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(index));
    }
    
    // Simple info window - cuma nama dan address
    final routeName = route['destination_name'] ?? 'Water Supply ${index + 1}';
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: markerIcon,
      infoWindow: InfoWindow(
        title: routeName,
        snippet: simpleAddress,
      ),
      onTap: () {
        _onRouteMarkerTap(route, index);
      },
    );
  }
  
  // Reporter marker dengan simple address
  Marker _buildSimpleReporterMarker(ReportModel report) {
    final isSelected = _selectedReport?.id == report.id;
    final reportLat = report.location.latitude;
    final reportLng = report.location.longitude;
    
    // Get simple address untuk report location
    final simpleAddress = _getCachedAddress(
      reportLat, 
      reportLng, 
      fallback: report.address.isNotEmpty ? report.address : 'Loading address...'
    );
    
    return Marker(
      markerId: MarkerId('reporter_${report.id}'),
      position: LatLng(reportLat, reportLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(_getReporterMarkerHue(report.waterQuality)),
      infoWindow: InfoWindow(
        title: report.title,
        snippet: simpleAddress,
      ),
      onTap: () => _onReporterMarkerTap(report),
    );
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
    final isNearest = route['is_nearest'] == true;
    
    Color routeColor;
    int strokeWidth;
    double opacity;
    List<PatternItem> patterns = [];
    
    if (isNearest) {
      routeColor = Colors.red.shade600;
      strokeWidth = 8;
      opacity = 1.0;
      patterns = [PatternItem.dash(20), PatternItem.gap(10)];
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
  
  void _onRouteMarkerTap(Map<String, dynamic> route, int index) {
    setState(() {
      if (_selectedRouteIndex == index) {
        _selectedRouteIndex = null;
      } else {
        _selectedRouteIndex = index;
        _selectedReport = null;
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
      } else {
        _selectedReport = report;
        _selectedRouteIndex = null;
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
    
    return GestureDetector(
      onTap: () {
        // Show controls when user taps on map
        _showControlsTemporarily();
      },
      child: Stack(
        children: [
          // Main Google Map
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
            zoomControlsEnabled: true, // Disable default zoom controls
            mapToolbarEnabled: true,
            compassEnabled: true,
            zoomGesturesEnabled: true,
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
                _selectedReport = null;
              });
              _updateMarkersAndPolylines();
              widget.onRouteSelected?.call(-1);
              _showControlsTemporarily();
            },
          ),
          
          // NEW: Custom Zoom Controls Panel (Right side)
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            right: _showZoomControls ? 16 : -80,
            top: MediaQuery.of(context).padding.top + 80,
            child: _buildZoomControlsPanel(),
          ),
          
          // NEW: Map Control Buttons (Bottom right)
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            right: _showZoomControls ? 16 : -100,
            bottom: 100,
            child: _buildMapControlButtons(),
          ),
          
          // NEW: Zoom Level Indicator (Top right)
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            right: _showZoomControls ? 16 : -120,
            top: MediaQuery.of(context).padding.top + 20,
            child: _buildZoomLevelIndicator(),
          ),
          
          // Loading indicator untuk addresses
          if (_loadingAddresses)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Loading addresses...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
  
  // NEW: Build custom zoom controls panel
  Widget _buildZoomControlsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _currentZoom < 20.0 ? _zoomIn : null,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.add,
                  color: _currentZoom < 20.0 ? Colors.blue.shade700 : Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          
          // Zoom Out Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _currentZoom > 2.0 ? _zoomOut : null,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Container(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.remove,
                  color: _currentZoom > 2.0 ? Colors.blue.shade700 : Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // NEW: Build map control buttons
  Widget _buildMapControlButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fit All Routes Button
        _buildControlButton(
          icon: Icons.center_focus_strong,
          onTap: _fitAllRoutes,
          tooltip: 'Fit All Routes',
          color: Colors.green,
        ),
        
        SizedBox(height: 8),
        
        // My Location Button
        if (widget.currentLocation != null)
          _buildControlButton(
            icon: Icons.my_location,
            onTap: _goToCurrentLocation,
            tooltip: 'My Location',
            color: Colors.blue,
          ),
      ],
    );
  }
  
  // NEW: Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
  
  // NEW: Build zoom level indicator
  Widget _buildZoomLevelIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.zoom_in,
            color: Colors.white,
            size: 14,
          ),
          SizedBox(width: 6),
          Text(
            '${_currentZoom.toStringAsFixed(1)}x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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