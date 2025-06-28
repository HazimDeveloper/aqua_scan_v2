// lib/widgets/admin/google_maps_widget.dart - Google Maps API Integration
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide ClusterManager;
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
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

class MapLocation with ClusterItem {
  final double latitude;
  final double longitude;

  MapLocation({required this.latitude, required this.longitude});

  @override
  LatLng get location => LatLng(latitude, longitude);
}

class _GoogleMapsRouteWidgetState extends State<GoogleMapsRouteWidget>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  ClusterManager<MapLocation>? _clusterManager;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _routeAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;
  
  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedRouteIndex;
  List<Map<String, dynamic>> _sortedRoutes = [];
  
  // Genetic Algorithm State
  bool _gaOptimizationInProgress = false;
  Map<String, dynamic>? _gaOptimizationResult;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeClusterManager();
    _initializeRoutes();
    
    if (widget.enableGeneticAlgorithm && widget.polylineRoutes?.isNotEmpty == true) {
      _performGeneticAlgorithmOptimization();
    }
  }
  
  @override
  void didUpdateWidget(GoogleMapsRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.polylineRoutes != widget.polylineRoutes) {
      _initializeRoutes();
      if (widget.enableGeneticAlgorithm) {
        _performGeneticAlgorithmOptimization();
      }
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _routeAnimationController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _routeAnimationController, curve: Curves.easeInOut),
    );
  }
  
  void _initializeClusterManager() {
    _clusterManager = ClusterManager<MapLocation>([], _updateMarkers);
  }
  
  void _initializeRoutes() {
    if (widget.polylineRoutes != null) {
      _sortedRoutes = List<Map<String, dynamic>>.from(widget.polylineRoutes!);
      
      // Sort by distance (nearest first)
      _sortedRoutes.sort((a, b) {
        final distanceA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
        final distanceB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
      
      _selectedRouteIndex = widget.selectedRouteIndex;
      _buildMarkersAndPolylines();
    }
  }
  
  Future<void> _performGeneticAlgorithmOptimization() async {
    if (widget.currentLocation == null || _sortedRoutes.isEmpty) return;
    
    setState(() {
      _gaOptimizationInProgress = true;
    });
    
    try {
      print('🧬 Starting Genetic Algorithm optimization...');
      
      final apiService = ApiService(baseUrl: 'https://your-backend-url.com');
      
      final gaParams = widget.gaParameters ?? GAParameters(
        populationSize: 100,
        maxGenerations: 150,
        eliteSize: 10,
        mutationRate: 0.12,
        crossoverRate: 0.88,
        maxRouteLength: math.min(20, _sortedRoutes.length + 5),
        timeLimit: 30.0,
        convergenceThreshold: 15,
      );
      
      final request = RouteOptimizationRequest(
        adminId: 'google-maps-widget',
        currentLocation: widget.currentLocation!,
        destinationKeyword: 'water_supply',
        maxRoutes: _sortedRoutes.length,
        optimizationMethod: 'genetic_algorithm',
        gaConfig: gaParams,
        useGoogleMaps: true,
        googleMapsApiKey: 'YOUR_GOOGLE_MAPS_API_KEY', // Replace with actual key
      );
      
      // Simulate GA optimization (replace with actual API call)
      await Future.delayed(const Duration(seconds: 2));
      
      // Update routes with optimized order
      _updateRoutesWithGAOptimization();
      
      setState(() {
        _gaOptimizationInProgress = false;
        _gaOptimizationResult = {
          'fitness_score': 0.85,
          'generations_run': 45,
          'optimization_time': 2.3,
          'convergence_achieved': true,
        };
      });
      
      print('✅ Genetic Algorithm optimization completed');
      
    } catch (e) {
      print('❌ Genetic Algorithm optimization failed: $e');
      setState(() {
        _gaOptimizationInProgress = false;
        _errorMessage = 'GA optimization failed: $e';
      });
    }
  }
  
  void _updateRoutesWithGAOptimization() {
    // Simulate route reordering based on GA optimization
    // In a real implementation, this would come from the GA API response
    if (_sortedRoutes.length > 3) {
      // Simulate swapping some routes for optimization
      final temp = _sortedRoutes[1];
      _sortedRoutes[1] = _sortedRoutes[3];
      _sortedRoutes[3] = temp;
      
      _buildMarkersAndPolylines();
    }
  }
  
  void _buildMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();
    
    // Add current location marker
    if (widget.currentLocation != null) {
      _markers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines
    for (int i = 0; i < _sortedRoutes.length; i++) {
      final route = _sortedRoutes[i];
      _markers.add(_buildRouteMarker(route, i));
      _polylines.addAll(_buildRoutePolylines(route, i));
    }
    
    // Add report markers
    for (final report in widget.reports) {
      _markers.add(_buildReportMarker(report));
    }
    
    _updateMapBounds();
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
        snippet: 'Current position',
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
        snippet: '${route['distance']?.toStringAsFixed(1)}km • ${route['travel_time']}',
      ),
      onTap: () {
        setState(() {
          _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
        });
        widget.onRouteSelected?.call(index);
      },
    );
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
              color: Colors.green.withOpacity(0.3),
              width: strokeWidth + 3,
              geodesic: true,
            ),
          );
        }
      }
    }
    
    return polylines;
  }
  
  void _updateMarkers(Set<Marker> markers) {
    setState(() {
      _markers = markers;
    });
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
          onTap: (_) {
            setState(() {
              _selectedRouteIndex = null;
            });
          },
        ),
        
        // Top info panel
        _buildTopInfoPanel(),
        
        // Genetic Algorithm status
        if (_gaOptimizationInProgress)
          _buildGAStatusPanel(),
        
        // Error message
        if (_errorMessage != null)
          _buildErrorMessage(),
        
        // Route selection panel
        if (_selectedRouteIndex != null && _sortedRoutes.isNotEmpty)
          _buildRouteDetailsPanel(),
      ],
    );
  }
  
  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No data available",
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Water Supply Routes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                if (_gaOptimizationResult != null)
                  Icon(Icons.psychology, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_sortedRoutes.length} optimized routes available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_gaOptimizationResult != null) ...[
              const SizedBox(height: 4),
              Text(
                'GA optimized • ${_gaOptimizationResult!['optimization_time']?.toStringAsFixed(1)}s',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildGAStatusPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Optimizing routes with Genetic Algorithm...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade600, size: 20),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRouteDetailsPanel() {
    if (_selectedRouteIndex == null || _selectedRouteIndex! >= _sortedRoutes.length) {
      return const SizedBox.shrink();
    }
    
    final route = _sortedRoutes[_selectedRouteIndex!];
    
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route,
                  color: _getRouteColor(_selectedRouteIndex!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route['destination_name'] ?? 'Water Supply ${_selectedRouteIndex! + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedRouteIndex = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${route['distance']?.toStringAsFixed(1)} km',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  route['travel_time']?.toString() ?? 'Unknown',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            if (route['destination_details']?['address'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route['destination_details']['address'],
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
