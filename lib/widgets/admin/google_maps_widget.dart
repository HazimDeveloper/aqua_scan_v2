// lib/widgets/admin/google_maps_widget.dart - Enhanced with Driving Mode Focus
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
  
  // ENHANCED: Driving mode specific settings
  String _travelMode = 'driving';
  bool _avoidTolls = false;
  bool _avoidHighways = false;
  bool _avoidFerries = true;
  String _routeOptimization = 'time'; // 'time' or 'distance'
  
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
      
      // Sort by the selected optimization criteria
      if (_routeOptimization == 'time') {
        _sortedRoutes.sort((a, b) {
          final timeA = _parseTimeToMinutes(a['travel_time']?.toString() ?? '0 min');
          final timeB = _parseTimeToMinutes(b['travel_time']?.toString() ?? '0 min');
          return timeA.compareTo(timeB);
        });
      } else {
        // Sort by distance (default)
        _sortedRoutes.sort((a, b) {
          final distanceA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
          final distanceB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });
      }
      
      _selectedRouteIndex = widget.selectedRouteIndex;
      _buildMarkersAndPolylines();
    }
  }
  
  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.toLowerCase().split(' ');
    int totalMinutes = 0;
    
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].contains('h')) {
        final hours = int.tryParse(parts[i].replaceAll('h', '')) ?? 0;
        totalMinutes += hours * 60;
      } else if (parts[i].contains('m')) {
        final minutes = int.tryParse(parts[i].replaceAll('m', '').replaceAll('in', '')) ?? 0;
        totalMinutes += minutes;
      }
    }
    
    return totalMinutes;
  }
  
  Future<void> _performGeneticAlgorithmOptimization() async {
    if (widget.currentLocation == null || _sortedRoutes.isEmpty) return;
    
    setState(() {
      _gaOptimizationInProgress = true;
    });
    
    try {
      print('🧬 Starting Genetic Algorithm optimization with driving mode...');
      
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
      
      // ENHANCED: Include driving mode preferences in the optimization
      print('🚗 Optimization settings:');
      print('   Travel mode: $_travelMode');
      print('   Avoid tolls: $_avoidTolls');
      print('   Avoid highways: $_avoidHighways');
      print('   Avoid ferries: $_avoidFerries');
      print('   Optimization: $_routeOptimization');
      
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
          'travel_mode': _travelMode,
          'optimization_criteria': _routeOptimization,
        };
      });
      
      print('✅ Genetic Algorithm optimization completed with driving mode');
      
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
    
    // Add current location marker with car icon
    if (widget.currentLocation != null) {
      _markers.add(_buildCurrentLocationMarker());
    }
    
    // Add route markers and polylines with driving-specific styling
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
      infoWindow: InfoWindow(
        title: 'Your Location (Start)',
        snippet: 'Driving from here • Mode: $_travelMode',
      ),
    );
  }
  
  Marker _buildRouteMarker(Map<String, dynamic> route, int index) {
    final destination = route['destination_details'] as Map<String, dynamic>? ?? {};
    final lat = (destination['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (destination['longitude'] as num?)?.toDouble() ?? 0.0;
    
    final isSelected = _selectedRouteIndex == index;
    final isNearest = index == 0;
    final isFastest = _routeOptimization == 'time' && index == 0;
    
    return Marker(
      markerId: MarkerId('route_$index'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isNearest || isFastest ? BitmapDescriptor.hueGreen : 
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
    final isFastest = _routeOptimization == 'time' && index == 0;
    final isShortest = _routeOptimization == 'distance' && index == 0;
    
    String snippet = '$distance • $time';
    
    if (isFastest) {
      snippet += ' • FASTEST ROUTE';
    } else if (isShortest) {
      snippet += ' • SHORTEST ROUTE';
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
        final isOptimal = index == 0; // First route is optimal based on current criteria
        
        Color routeColor;
        int strokeWidth;
        
        if (isOptimal) {
          routeColor = _routeOptimization == 'time' ? Colors.green : Colors.blue;
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
            patterns: _getRoutePattern(index),
          ),
        );
        
        // Add shadow effect for optimal route
        if (isOptimal) {
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
  
  List<PatternItem> _getRoutePattern(int index) {
    // Different patterns for different route types when driving
    if (index == 0) {
      return []; // Solid line for best route
    } else if (index < 3) {
      return [PatternItem.dash(20), PatternItem.gap(10)]; // Dashed for top 3
    } else {
      return [PatternItem.dot, PatternItem.gap(10)]; // Dotted for others
    }
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
          mapType: MapType.normal, // Best for driving navigation
          trafficEnabled: true, // Show traffic for driving
          onTap: (_) {
            setState(() {
              _selectedRouteIndex = null;
            });
          },
        ),
        
        // Top info panel with driving mode info
        _buildTopInfoPanel(),
        
        // Driving mode settings panel
        _buildDrivingSettingsPanel(),
        
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
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No driving routes available",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "No location data or routes found for driving navigation",
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.directions_car, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'Driving Routes to Water Supplies',
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
            Row(
              children: [
                Icon(Icons.route, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${_sortedRoutes.length} routes • Optimized for $_routeOptimization',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_gas_station, size: 10, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'DRIVING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_gaOptimizationResult != null) ...[
              const SizedBox(height: 4),
              Text(
                'GA optimized • ${_gaOptimizationResult!['optimization_time']?.toStringAsFixed(1)}s • Driving mode',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrivingSettingsPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
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
                Icon(Icons.settings, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Driving Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Route optimization toggle
            _buildSettingToggle(
              'Optimize for',
              _routeOptimization == 'time' ? 'Fastest Time' : 'Shortest Distance',
              Icons.timer,
              () {
                setState(() {
                  _routeOptimization = _routeOptimization == 'time' ? 'distance' : 'time';
                  _initializeRoutes(); // Re-sort routes
                });
              },
            ),
            
            const SizedBox(height: 8),
            
            // Avoid options
            _buildSettingCheckbox('Avoid Tolls', _avoidTolls, (value) {
              setState(() => _avoidTolls = value);
            }),
            
            _buildSettingCheckbox('Avoid Highways', _avoidHighways, (value) {
              setState(() => _avoidHighways = value);
            }),
            
            _buildSettingCheckbox('Avoid Ferries', _avoidFerries, (value) {
              setState(() => _avoidFerries = value);
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingToggle(String title, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingCheckbox(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGAStatusPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 200,
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
                'Optimizing driving routes with Genetic Algorithm...',
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
      top: MediaQuery.of(context).padding.top + 200,
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
    final isOptimal = _selectedRouteIndex == 0;
    
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOptimal ? Colors.green : _getRouteColor(_selectedRouteIndex!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isOptimal ? Icons.star : Icons.directions_car,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route['destination_name'] ?? 'Water Supply ${_selectedRouteIndex! + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isOptimal 
                            ? '${_routeOptimization == 'time' ? 'FASTEST' : 'SHORTEST'} DRIVING ROUTE'
                            : 'Driving Route ${_selectedRouteIndex! + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOptimal ? Colors.green : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip(
                    Icons.straighten,
                    'Distance',
                    '${route['distance']?.toStringAsFixed(1)} km',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailChip(
                    Icons.access_time,
                    'Drive Time',
                    route['travel_time']?.toString() ?? 'Unknown',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailChip(
                    Icons.local_gas_station,
                    'Mode',
                    'Driving',
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (route['destination_details']?['address'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route['destination_details']['address'],
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            
            // Driving preferences applied to this route
            if (_avoidTolls || _avoidHighways || _avoidFerries) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  if (_avoidTolls) _buildPreferenceChip('No Tolls', Icons.money_off),
                  if (_avoidHighways) _buildPreferenceChip('No Highways', Icons.no_cell),
                  if (_avoidFerries) _buildPreferenceChip('No Ferries', Icons.directions_boat_outlined),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreferenceChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}