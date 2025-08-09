// lib/models/report_model.dart - ENHANCED FOR WATER COMPLAINT SYSTEM
// Removed all Firebase dependencies and added complaint types

enum WaterQualityState {
  highPh,       // 'HIGH_PH'
  highPhTemp,   // 'HIGH_PH; HIGH_TEMP'
  lowPh,        // 'LOW_PH'
  lowTemp,      // 'LOW_TEMP'
  lowTempHighPh,// 'LOW_TEMP;HIGH_PH'
  optimum,      // 'OPTIMUM'
  unknown       // Default fallback
}

enum ComplaintType {
  billingIssues,    // Low priority - Yellow
  supplyDisruption, // High priority - Red
  poorQuality,      // Medium priority - Orange
  pollution,        // High priority - Red
  leakingPipes,     // Medium priority - Orange
  lowPressure,      // Medium priority - Orange
  noAccess,         // Low priority - Yellow
  chemicalSpill,    // Critical priority - Purple
  other             // Default - Blue
}

enum ComplaintPriority {
  low,      // Yellow
  medium,   // Orange
  high,     // Red
  critical  // Purple
}

enum ComplaintStatus {
  new_,     // Just reported
  inProgress, // Being addressed
  resolved,   // Issue fixed
  closed      // Closed without resolution
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
  
  // New fields for water complaint system
  final ComplaintType complaintType;
  final ComplaintPriority priority;
  final ComplaintStatus status;
  final String? assignedTo;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

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
    this.complaintType = ComplaintType.other,
    this.priority = ComplaintPriority.medium,
    this.status = ComplaintStatus.new_,
    this.assignedTo,
    this.resolvedAt,
    this.resolutionNotes,
  });
  
  // Get priority color based on complaint type
  static ComplaintPriority getPriorityFromComplaintType(ComplaintType type) {
    switch (type) {
      case ComplaintType.supplyDisruption:
      case ComplaintType.pollution:
        return ComplaintPriority.high;
      case ComplaintType.poorQuality:
      case ComplaintType.leakingPipes:
      case ComplaintType.lowPressure:
        return ComplaintPriority.medium;
      case ComplaintType.billingIssues:
      case ComplaintType.noAccess:
        return ComplaintPriority.low;
      case ComplaintType.chemicalSpill:
        return ComplaintPriority.critical;
      case ComplaintType.other:
      default:
        return ComplaintPriority.medium;
    }
  }

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
      
      // Parse complaint type
      ComplaintType complaintType = ComplaintType.other;
      if (json['complaintType'] != null) {
        final complaintTypeValue = json['complaintType'];
        if (complaintTypeValue is int) {
          if (complaintTypeValue >= 0 && complaintTypeValue < ComplaintType.values.length) {
            complaintType = ComplaintType.values[complaintTypeValue];
          }
        }
      }
      
      // Parse priority
      ComplaintPriority priority = getPriorityFromComplaintType(complaintType);
      if (json['priority'] != null) {
        final priorityValue = json['priority'];
        if (priorityValue is int) {
          if (priorityValue >= 0 && priorityValue < ComplaintPriority.values.length) {
            priority = ComplaintPriority.values[priorityValue];
          }
        }
      }
      
      // Parse status
      ComplaintStatus status = ComplaintStatus.new_;
      if (json['status'] != null) {
        final statusValue = json['status'];
        if (statusValue is int) {
          if (statusValue >= 0 && statusValue < ComplaintStatus.values.length) {
            status = ComplaintStatus.values[statusValue];
          }
        }
      } else {
        // For backward compatibility
        status = json['isResolved'] == true ? ComplaintStatus.resolved : ComplaintStatus.new_;
      }
      
      // Parse resolvedAt
      DateTime? resolvedAt;
      if (json['resolvedAt'] != null) {
        final resolvedAtValue = json['resolvedAt'];
        if (resolvedAtValue is String) {
          try {
            resolvedAt = DateTime.parse(resolvedAtValue);
          } catch (e) {
            print('Error parsing resolvedAt string: $e');
          }
        } else if (resolvedAtValue is int) {
          resolvedAt = DateTime.fromMillisecondsSinceEpoch(resolvedAtValue);
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
        complaintType: complaintType,
        priority: priority,
        status: status,
        assignedTo: json['assignedTo']?.toString(),
        resolvedAt: resolvedAt,
        resolutionNotes: json['resolutionNotes']?.toString(),
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

  // ENHANCED: Store dates as ISO strings for local storage with new complaint fields
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
      'complaintType': complaintType.index,
      'priority': priority.index,
      'status': status.index,
      'assignedTo': assignedTo,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolutionNotes': resolutionNotes,
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
    ComplaintType? complaintType,
    ComplaintPriority? priority,
    ComplaintStatus? status,
    String? assignedTo,
    DateTime? resolvedAt,
    String? resolutionNotes,
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
      complaintType: complaintType ?? this.complaintType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
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