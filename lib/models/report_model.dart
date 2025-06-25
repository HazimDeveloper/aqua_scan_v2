// lib/models/report_model.dart - FIXED FOR LOCAL STORAGE ONLY
// Removed all Firebase dependencies

enum WaterQualityState {
  highPh,       // 'HIGH_PH'
  highPhTemp,   // 'HIGH_PH; HIGH_TEMP'
  lowPh,        // 'LOW_PH'
  lowTemp,      // 'LOW_TEMP'
  lowTempHighPh,// 'LOW_TEMP;HIGH_PH'
  optimum,      // 'OPTIMUM'
  unknown       // Default fallback
}

class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;
    
    try {
      if (json.containsKey('latitude') && json['latitude'] != null) {
        lat = json['latitude'] is double
            ? json['latitude'] as double
            : (json['latitude'] as num).toDouble();
      }
      
      if (json.containsKey('longitude') && json['longitude'] != null) {
        lng = json['longitude'] is double
            ? json['longitude'] as double
            : (json['longitude'] as num).toDouble();
      }
    } catch (e) {
      print('Error parsing GeoPoint coordinates: $e');
      // Use defaults
    }
    
    return GeoPoint(
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final GeoPoint location;
  final String address;
  final List<String> imageUrls;
  final WaterQualityState waterQuality;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.location,
    required this.address,
    required this.imageUrls,
    required this.waterQuality,
    required this.isResolved,
    required this.createdAt,
    required this.updatedAt,
  });

  static WaterQualityState getStateFromString(String stateString) {
    switch (stateString.toUpperCase()) {
      case 'HIGH_PH':
        return WaterQualityState.highPh;
      case 'HIGH_PH; HIGH_TEMP':
        return WaterQualityState.highPhTemp;
      case 'LOW_PH':
        return WaterQualityState.lowPh;
      case 'LOW_TEMP':
        return WaterQualityState.lowTemp;
      case 'LOW_TEMP;HIGH_PH':
        return WaterQualityState.lowTempHighPh;
      case 'OPTIMUM':
        return WaterQualityState.optimum;
      default:
        return WaterQualityState.unknown;
    }
  }

  // FIXED: Handle both Firebase and local storage formats
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle dates - support both Timestamp and String/int formats
      DateTime createdAt = DateTime.now();
      DateTime updatedAt = DateTime.now();
      
      // Parse createdAt
      if (json['createdAt'] != null) {
        final createdAtValue = json['createdAt'];
        if (createdAtValue is String) {
          try {
            createdAt = DateTime.parse(createdAtValue);
          } catch (e) {
            print('Error parsing createdAt string: $e');
          }
        } else if (createdAtValue is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
        } else {
          // Handle Timestamp from Firestore (if exists)
          try {
            createdAt = (createdAtValue as dynamic).toDate();
          } catch (e) {
            print('Error parsing createdAt timestamp: $e');
          }
        }
      }
      
      // Parse updatedAt
      if (json['updatedAt'] != null) {
        final updatedAtValue = json['updatedAt'];
        if (updatedAtValue is String) {
          try {
            updatedAt = DateTime.parse(updatedAtValue);
          } catch (e) {
            print('Error parsing updatedAt string: $e');
          }
        } else if (updatedAtValue is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtValue);
        } else {
          // Handle Timestamp from Firestore (if exists)
          try {
            updatedAt = (updatedAtValue as dynamic).toDate();
          } catch (e) {
            print('Error parsing updatedAt timestamp: $e');
          }
        }
      }
      
      // Handle water quality state
      WaterQualityState waterQuality = WaterQualityState.unknown;
      if (json['waterQuality'] != null) {
        final waterQualityValue = json['waterQuality'];
        if (waterQualityValue is int) {
          // Handle enum index
          if (waterQualityValue >= 0 && waterQualityValue < WaterQualityState.values.length) {
            waterQuality = WaterQualityState.values[waterQualityValue];
          }
        } else if (waterQualityValue is String) {
          // Handle string representation
          waterQuality = getStateFromString(waterQualityValue);
        }
      }
      
      return ReportModel(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        location: json['location'] != null 
            ? GeoPoint.fromJson(json['location'] as Map<String, dynamic>)
            : GeoPoint(latitude: 0, longitude: 0),
        address: json['address']?.toString() ?? '',
        imageUrls: json['imageUrls'] != null 
            ? List<String>.from(json['imageUrls'] as List)
            : [],
        waterQuality: waterQuality,
        isResolved: json['isResolved'] == true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      print('Error in ReportModel.fromJson: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      
      // Return a minimal valid model
      return ReportModel(
        id: json['id']?.toString() ?? 'error_${DateTime.now().millisecondsSinceEpoch}',
        userId: json['userId']?.toString() ?? 'unknown',
        userName: json['userName']?.toString() ?? 'Unknown User',
        title: json['title']?.toString() ?? 'Error Loading Report',
        description: json['description']?.toString() ?? 'Could not load report data',
        location: GeoPoint(latitude: 0, longitude: 0),
        address: json['address']?.toString() ?? 'Unknown Location',
        imageUrls: [],
        waterQuality: WaterQualityState.unknown,
        isResolved: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // FIXED: Store dates as ISO strings for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location.toJson(),
      'address': address,
      'imageUrls': imageUrls,
      'waterQuality': waterQuality.index,
      'isResolved': isResolved,
      'createdAt': createdAt.toIso8601String(), // Store as ISO string
      'updatedAt': updatedAt.toIso8601String(), // Store as ISO string
    };
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    GeoPoint? location,
    String? address,
    List<String>? imageUrls,
    WaterQualityState? waterQuality,
    bool? isResolved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      imageUrls: imageUrls ?? this.imageUrls,
      waterQuality: waterQuality ?? this.waterQuality,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoutePoint {
  final String nodeId;
  final GeoPoint location;
  final String address;
  final String? label;

  RoutePoint({
    required this.nodeId,
    required this.location,
    required this.address,
    this.label,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      nodeId: json['nodeId']?.toString() ?? '',
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      address: json['address']?.toString() ?? '',
      label: json['label']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'location': location.toJson(),
      'address': address,
      'label': label,
    };
  }
}

class RouteSegment {
  final RoutePoint from;
  final RoutePoint to;
  final double distance; // in kilometers
  final List<GeoPoint> polyline;

  RouteSegment({
    required this.from,
    required this.to,
    required this.distance,
    required this.polyline,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    // Safely process polyline data
    List<GeoPoint> polylinePoints = [];
    if (json.containsKey('polyline') && json['polyline'] != null) {
      try {
        final polylineData = json['polyline'] as List<dynamic>;
        polylinePoints = polylineData.map((point) {
          if (point is Map<String, dynamic>) {
            try {
              return GeoPoint.fromJson(point);
            } catch (e) {
              print('Error creating GeoPoint from: $point');
              return GeoPoint(latitude: 0, longitude: 0);
            }
          } else {
            print('Polyline point is not a Map: $point');
            return GeoPoint(latitude: 0, longitude: 0);
          }
        }).toList();
      } catch (e) {
        print('Error processing polyline data: $e');
        polylinePoints = [];
      }
    }

    return RouteSegment(
      from: json.containsKey('from') && json['from'] != null
          ? RoutePoint.fromJson(json['from'] as Map<String, dynamic>)
          : RoutePoint(
              nodeId: '',
              location: GeoPoint(latitude: 0, longitude: 0),
              address: '',
            ),
      to: json.containsKey('to') && json['to'] != null
          ? RoutePoint.fromJson(json['to'] as Map<String, dynamic>)
          : RoutePoint(
              nodeId: '',
              location: GeoPoint(latitude: 0, longitude: 0),
              address: '',
            ),
      distance: json.containsKey('distance') && json['distance'] != null
          ? (json['distance'] is double 
              ? json['distance'] as double
              : (json['distance'] as num).toDouble())
          : 0.0,
      polyline: polylinePoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'to': to.toJson(),
      'distance': distance,
      'polyline': polyline.map((point) => point.toJson()).toList(),
    };
  }
}