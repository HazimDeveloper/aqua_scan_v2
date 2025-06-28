// lib/screens/simplified/simple_report_screen.dart - FIXED: Handle Low Confidence Results
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../utils/water_quality_utils.dart';
import '../../widgets/common/custom_loader.dart';

class SimpleReportScreen extends StatefulWidget {
  final bool isAdmin;
  
  const SimpleReportScreen({
    Key? key,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _SimpleReportScreenState createState() => _SimpleReportScreenState();
}

class _SimpleReportScreenState extends State<SimpleReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _reporterNameController = TextEditingController();
  
  List<File> _imageFiles = [];
  List<String> _savedImagePaths = [];
  final int _maxImages = 10;
  
  bool _isLoading = false;
  bool _isDetecting = false;
  bool _isSavingImages = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence;
  String? _originalClass;
  
  // ENHANCED: Better state tracking
  bool _waterDetected = false;
  String? _analysisMessage;
  bool _analysisCompleted = false;
  String? _detectionError;
  bool _isLowConfidence = false; // ADDED: Track low confidence results
  
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  final bool _debugMode = true;
  
  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _reporterNameController.text = widget.isAdmin ? 'Admin User' : 'Test User';
    
    _logDebug('SimpleReportScreen initialized with LOW CONFIDENCE handling');
    _getCurrentLocation();
  }
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('📱 SimpleReport: $message');
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      _logDebug('Getting current location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        _logDebug('Location obtained: ${position.latitude}, ${position.longitude}');
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        _logDebug('Address resolved: $address');
        
        setState(() {
          _location = _locationService.positionToGeoPoint(position);
          _autoAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logDebug('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxImages) {
      _showMessage('Maximum $_maxImages images allowed', isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    title: 'Camera',
                    subtitle: 'Take new photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.photo_library,
                    title: 'Gallery',
                    subtitle: 'Choose existing',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: widget.isAdmin ? Colors.orange : AppTheme.primaryColor),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      _logDebug('Opening image picker from ${source.name}...');
      final picker = ImagePicker();
      
      final pickedFile = await picker.pickImage(
        source: source, 
        imageQuality: 85,
        maxWidth: 1920,          
        maxHeight: 1080,         
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        if (!await imageFile.exists()) {
          _showMessage('Error: Could not access selected image', isError: true);
          return;
        }
        
        try {
          setState(() {
            _isSavingImages = true;
          });
          
          final processedImageFile = await _processImageForAnalysis(imageFile, source);
          
          final folder = widget.isAdmin ? 'admin_reports' : 'reports';
          final localPath = await _storageService.uploadImage(processedImageFile, folder);
          
          _logDebug('Image saved to local storage: $localPath');
          
          setState(() {
            _imageFiles.add(File(localPath));
            _savedImagePaths.add(localPath);
            _isSavingImages = false;
          });
          
          // FIXED: Reset analysis results when new image added
          if (_imageFiles.length == 1) {
            setState(() {
              _detectedQuality = WaterQualityState.unknown;
              _confidence = null;
              _originalClass = null;
              _waterDetected = false;
              _analysisMessage = null;
              _analysisCompleted = false;
              _detectionError = null;
              _isLowConfidence = false; // ADDED
            });
          }
          
          _showMessage('Image processed and saved successfully!', isError: false);
          
          if (_imageFiles.length == 1) {
            _logDebug('Auto-analyzing first image with LOW CONFIDENCE handling...');
            await _detectWaterQuality(File(localPath));
          }
          
        } catch (e) {
          setState(() {
            _isSavingImages = false;
          });
          _showMessage('Error processing image: $e', isError: true);
        }
      }
    } catch (e) {
      setState(() {
        _isSavingImages = false;
      });
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<File> _processImageForAnalysis(File originalFile, ImageSource source) async {
    try {
      _logDebug('🔧 Processing image for water quality analysis...');
      
      final imageBytes = await originalFile.readAsBytes();
      _logDebug('Original size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = path.join(tempDir.path, 'processed_${timestamp}.jpg');
      
      final processedFile = await originalFile.copy(processedPath);
      
      if (await processedFile.exists()) {
        final processedSize = await processedFile.length();
        _logDebug('Processed size: ${(processedSize / 1024).toStringAsFixed(2)} KB');
        _logDebug('✅ Image processing complete - ready for analysis');
        return processedFile;
      } else {
        throw Exception('Failed to create processed image');
      }
      
    } catch (e) {
      _logDebug('❌ Error processing image: $e');
      return originalFile;
    }
  }

  // FIXED: Enhanced water quality detection with low confidence handling
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
        _waterDetected = false;
        _analysisMessage = null;
        _analysisCompleted = false;
        _detectionError = null;
        _isLowConfidence = false; // ADDED
      });
      
      _logDebug('🔬 Starting water quality detection...');
      _logDebug('📁 Image file: ${image.path}');
      _logDebug('📤 Sending to backend: ${image.path}');
      _logDebug('📤 File exists: ${await image.exists()}');
      _logDebug('📤 File size: ${await image.length()} bytes');
      
      if (!await image.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final fileSize = await image.length();
      _logDebug('📏 Image size: ${fileSize} bytes');
      
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      _logDebug('🔗 Testing backend connection...');
      final isConnected = await _apiService.testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server is not running.\n\nPlease start Python server:\n1. cd backend_version_2\n2. python main.py\n3. Ensure server runs on port 8000');
      }
      
      _logDebug('✅ Backend connected, sending image for analysis...');
      
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      _logDebug('✅ API Analysis completed');
      _logDebug('🔍 Water detected: ${result.waterDetected}');
      _logDebug('🎯 Quality: ${result.waterQuality}');
      _logDebug('📊 Confidence: ${result.confidence}%');
      _logDebug('🏷️ Original class: ${result.originalClass}');
      _logDebug('⚠️ Is low confidence: ${result.isLowConfidence}');
      _logDebug('📝 Message: ${result.errorMessage}');
      
      setState(() {
        _waterDetected = result.waterDetected;
        _detectedQuality = result.waterQuality;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _analysisMessage = result.errorMessage;
        _analysisCompleted = true;
        _isDetecting = false;
        _isLowConfidence = result.isLowConfidence; // ADDED
      });
      
      // FIXED: Handle different analysis scenarios with proper low confidence handling
      if (!result.waterDetected) {
        // NO WATER DETECTED CASE
        _logDebug('⚠️ No water detected in image');
        
        _showMessage(
          'No water detected in image. Please take a photo that clearly shows water for quality analysis.',
          isError: true,
          duration: 6,
        );
        
      } else if (result.waterDetected && result.isLowConfidence && result.waterQuality != WaterQualityState.unknown) {
        // FIXED: LOW CONFIDENCE BUT VALID RESULTS CASE
        _logDebug('⚠️ Water detected with LOW CONFIDENCE but valid analysis');
        
        final qualityText = WaterQualityUtils.getWaterQualityText(result.waterQuality);
        
        _showMessage(
          'Water detected! Quality: $qualityText\nLow confidence (${result.confidence.toStringAsFixed(1)}%) - Consider retaking photo for better accuracy.',
          isError: false,
          duration: 7,
        );
        
      } else if (result.waterDetected && result.confidence > 0) {
        // HIGH CONFIDENCE WATER ANALYSIS CASE
        _logDebug('✅ Water detected and analyzed with good confidence');
        
        final qualityText = WaterQualityUtils.getWaterQualityText(result.waterQuality);
        String confidenceAssessment;
        
        if (result.confidence >= 90) {
          confidenceAssessment = "EXCELLENT confidence";
        } else if (result.confidence >= 80) {
          confidenceAssessment = "HIGH confidence";
        } else if (result.confidence >= 70) {
          confidenceAssessment = "GOOD confidence";
        } else if (result.confidence >= 60) {
          confidenceAssessment = "Moderate confidence";
        } else {
          confidenceAssessment = "Low confidence";
        }
        
        _showMessage(
          'Water detected! Quality: $qualityText\n$confidenceAssessment (${result.confidence.toStringAsFixed(1)}%)',
          isError: false,
          duration: 5,
        );
        
      } else if (result.waterDetected && result.confidence == 0) {
        // WATER DETECTED BUT ANALYSIS FAILED CASE
        _logDebug('⚠️ Water detected but analysis failed');
        
        final message = result.errorMessage ?? 'Analysis failed with very low confidence';
        
        _showMessage(
          'Water detected but analysis failed: $message\nTry retaking the photo with better lighting.',
          isError: true,
          duration: 6,
        );
        
      } else {
        // UNKNOWN ERROR CASE
        _logDebug('❓ Unknown analysis result');
        
        final message = result.errorMessage ?? 'Unknown analysis error';
        
        _showMessage(
          'Analysis error: $message',
          isError: true,
          duration: 5,
        );
      }
      
    } catch (e) {
      _logDebug('❌ Analysis failed: $e');
      
      setState(() {
        _isDetecting = false;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
        _waterDetected = false;
        _analysisCompleted = true;
        _detectionError = e.toString();
        _isLowConfidence = false; // ADDED
      });
      
      String errorMessage = 'Water quality analysis failed: ';
      
      if (e.toString().contains('Backend server') || e.toString().contains('backend')) {
        errorMessage += 'Backend server not running. Please start the Python server (main.py).';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage += 'Network connection error. Check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage += 'Analysis timeout. Try with a smaller image or check server.';
      } else if (e.toString().contains('Image file')) {
        errorMessage += 'Image file error. Please try taking a new photo.';
      } else {
        errorMessage += e.toString().length > 100 ? 'Internal error occurred' : e.toString();
      }
      
      _showMessage(errorMessage, isError: true, duration: 8);
    }
  }
  
  void _removeImage(int index) {
    if (index >= 0 && index < _imageFiles.length) {
      final file = _imageFiles[index];
      final localPath = _savedImagePaths[index];
      
      setState(() {
        _imageFiles.removeAt(index);
        _savedImagePaths.removeAt(index);
        
        if (_imageFiles.isEmpty) {
          _detectedQuality = WaterQualityState.unknown;
          _confidence = null;
          _originalClass = null;
          _waterDetected = false;
          _analysisMessage = null;
          _analysisCompleted = false;
          _detectionError = null;
          _isLowConfidence = false; // ADDED
        }
      });
      
      try {
        if (file.existsSync()) {
          file.deleteSync();
          _logDebug('Deleted local file: $localPath');
        }
      } catch (e) {
        _logDebug('Error deleting local file: $e');
      }
    }
  }
  
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_location == null) {
      _showMessage('Location is required. Please try again.', isError: true);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _logDebug('Starting report submission...');
      
      final imageUrls = List<String>.from(_savedImagePaths);
      
      _logDebug('Using ${imageUrls.length} local image paths');
      for (int i = 0; i < imageUrls.length; i++) {
        _logDebug('Image ${i + 1}: ${imageUrls[i]}');
      }
      
      final now = DateTime.now();
      final report = ReportModel(
        id: '',
        userId: widget.isAdmin ? 'admin-test' : 'user-test',
        userName: _reporterNameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _location!,
        address: _addressController.text.trim(),
        imageUrls: imageUrls,
        waterQuality: _detectedQuality,
        isResolved: false,
        createdAt: now,
        updatedAt: now,
      );
      
      final reportId = await _databaseService.createReport(report);
      
      _logDebug('✅ Report created successfully with ID: $reportId');
      
      if (mounted) {
        String successMessage = 'Report submitted successfully with ${imageUrls.length} image${imageUrls.length == 1 ? '' : 's'}!';
        
        // FIXED: Add analysis summary including low confidence results
        if (_analysisCompleted && _waterDetected && _confidence != null) {
          if (_isLowConfidence) {
            successMessage += '\nLow confidence analysis included (${_confidence!.toStringAsFixed(1)}%) - Consider retaking photos for better accuracy.';
          } else if (_confidence! >= 80) {
            successMessage += '\nHigh confidence analysis included (${_confidence!.toStringAsFixed(1)}%)';
          } else if (_confidence! >= 60) {
            successMessage += '\nModerate confidence analysis included (${_confidence!.toStringAsFixed(1)}%)';
          } else {
            successMessage += '\nLow confidence analysis included (${_confidence!.toStringAsFixed(1)}%)';
          }
        } else if (_analysisCompleted && !_waterDetected) {
          successMessage += '\nNote: No water detected in images';
        }
        
        _showMessage(successMessage, isError: false, duration: 6);
        
        Navigator.pop(context);
      }
    } catch (e) {
      _logDebug('❌ Error submitting report: $e');
      _showMessage('Error submitting report: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showMessage(String message, {required bool isError, int duration = 4}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle, 
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: duration),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isAdmin ? Colors.orange : AppTheme.primaryColor;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Create Admin Report' : 'Report Water Issue'),
        backgroundColor: themeColor,
        elevation: 0,
        actions: [
          if (_imageFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '${_imageFiles.length}/$_maxImages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && !_isSavingImages
        ? Center(
            child: WaterFillLoader(
              message: 'Getting your location...',
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isAdmin) _buildAdminIndicator(),
                  
                  _buildImageSection(themeColor),
                  
                  const SizedBox(height: 16),
                  
                  _buildDetailsSection(),
                  
                  const SizedBox(height: 24),
                  
                  _buildSubmitButton(themeColor),
                ],
              ),
            ),
          ),
    );
  }
  
  // FIXED: Enhanced image tile to show low confidence status
  Widget _buildModernImageTile(int index, Color themeColor) {
    final isMainPhoto = index == 0;
    final file = _imageFiles[index];
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isMainPhoto 
                ? Border.all(color: themeColor, width: 3)
                : Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder, color: Colors.grey.shade400, size: 20),
                          SizedBox(height: 4),
                          Text(
                            'Local\nStorage',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        
        if (isMainPhoto)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // FIXED: Analysis status indicator with low confidence handling
        if (isMainPhoto && _analysisCompleted)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _getAnalysisStatusColor(),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getAnalysisStatusIcon(),
                    color: Colors.white,
                    size: 8,
                  ),
                  SizedBox(width: 2),
                  Text(
                    _getAnalysisStatusText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: Helper methods for analysis status
  Color _getAnalysisStatusColor() {
    if (!_waterDetected) return Colors.orange;
    if (_isLowConfidence) return Colors.amber;
    if (_confidence != null && _confidence! >= 80) return Colors.green;
    return Colors.lightGreen;
  }
  
  IconData _getAnalysisStatusIcon() {
    if (!_waterDetected) return Icons.warning;
    if (_isLowConfidence) return Icons.info;
    return Icons.check_circle;
  }
  
  String _getAnalysisStatusText() {
    if (!_waterDetected) return 'NO H2O';
    if (_isLowConfidence) return 'LOW';
    if (_confidence != null && _confidence! >= 80) return 'HIGH';
    return 'OK';
  }

  // FIXED: Enhanced image section with low confidence handling
  Widget _buildImageSection(Color themeColor) {
    return Column(
      children: [
        // Header Card (same as before)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColor.withOpacity(0.1),
                  themeColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAdmin ? 'Advanced AI Analysis' : 'Enhanced Water Detection',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_imageFiles.length}/$_maxImages photos • Low confidence handling',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_imageFiles.length < _maxImages)
                        Container(
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _isSavingImages ? null : _pickImage,
                            icon: _isSavingImages 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.add, color: Colors.white),
                            tooltip: 'Add Photo',
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // FIXED: Enhanced status banner with low confidence info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor().withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_getStatusIcon(), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusTitle(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStatusSubtitle(),
                                style: TextStyle(
                                  color: _getStatusColor().withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Photos Grid Card (same as before but with enhanced status)
        if (_imageFiles.isNotEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Saved Photos',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getAnalysisStatusColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getAnalysisStatusIcon(),
                              size: 12,
                              color: _getAnalysisStatusColor(),
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getAnalysisStatusText(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getAnalysisStatusColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      return _buildModernImageTile(index, themeColor);
                    },
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Camera Button Card (same as before)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  _isSavingImages ? Icons.hourglass_empty : Icons.add_a_photo,
                  size: 48,
                  color: _isSavingImages 
                      ? Colors.orange 
                      : _imageFiles.length < _maxImages 
                          ? themeColor 
                          : Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  _isSavingImages
                      ? 'Processing for Analysis...'
                      : _imageFiles.isEmpty 
                          ? 'Take Your First Photo' 
                          : _imageFiles.length < _maxImages 
                              ? 'Add Another Photo' 
                              : 'Maximum Photos Reached',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isSavingImages || _imageFiles.length < _maxImages 
                        ? Colors.black87 
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSavingImages
                      ? 'Preparing for water detection and quality analysis...'
                      : _imageFiles.isEmpty
                          ? 'AI will analyze for water presence and quality (handles low confidence results)'
                          : 'Multiple photos improve detection accuracy',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_imageFiles.length < _maxImages && !_isSavingImages) ? _pickImage : null,
                    icon: _isSavingImages
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _imageFiles.isEmpty ? Icons.camera_alt : Icons.add_a_photo,
                          ),
                    label: Text(
                      _isSavingImages
                          ? 'Processing...'
                          : _imageFiles.isEmpty 
                              ? 'Take Photo' 
                              : _imageFiles.length < _maxImages 
                                  ? 'Add More Photos' 
                                  : 'Limit Reached',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _imageFiles.length < _maxImages && !_isSavingImages
                          ? themeColor 
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Analysis State Cards (same logic as before)
        if (_isDetecting)
          _buildAnalyzingCard(themeColor)
        else if (_analysisCompleted)
          _buildAnalysisResultCard(themeColor)
        else if (_imageFiles.isNotEmpty)
          _buildAnalysisPrompt(themeColor),
      ],
    );
  }

  // FIXED: Helper methods for status display with low confidence handling
  Color _getStatusColor() {
    if (_isDetecting) return Colors.blue;
    if (_analysisCompleted && _waterDetected && _isLowConfidence) return Colors.amber;
    if (_analysisCompleted && _waterDetected) return Colors.green;
    if (_analysisCompleted && !_waterDetected) return Colors.orange;
    if (_detectionError != null) return Colors.red;
    return Colors.grey;
  }
  
  IconData _getStatusIcon() {
    if (_isDetecting) return Icons.search;
    if (_analysisCompleted && _waterDetected && _isLowConfidence) return Icons.info;
    if (_analysisCompleted && _waterDetected) return Icons.check_circle;
    if (_analysisCompleted && !_waterDetected) return Icons.warning;
    if (_detectionError != null) return Icons.error;
    return Icons.psychology;
  }
  
  String _getStatusTitle() {
    if (_isDetecting) return 'Analyzing Image...';
    if (_analysisCompleted && _waterDetected && _isLowConfidence) return 'Low Confidence Result';
    if (_analysisCompleted && _waterDetected) return 'Water Quality Analyzed';
    if (_analysisCompleted && !_waterDetected) return 'No Water Detected';
    if (_detectionError != null) return 'Analysis Error';
    return 'Enhanced AI Ready';
  }
  
  String _getStatusSubtitle() {
    if (_isDetecting) return 'Smart AI is checking for water presence and quality';
    if (_analysisCompleted && _waterDetected && _isLowConfidence) return 'Water detected but low confidence - consider retaking photo';
    if (_analysisCompleted && _waterDetected) return 'Quality analysis completed successfully';
    if (_analysisCompleted && !_waterDetected) return 'Please retake photo showing clear water';
    if (_detectionError != null) return 'Check connection and try again';
    return 'Automatic water detection with quality analysis (handles all confidence levels)';
  }

  // Keep all other build methods the same...
  Widget _buildAnalyzingCard(Color themeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.shade300],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Enhanced Water Detection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'AI is analyzing your image to detect water presence and assess quality. All confidence levels are handled.',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Backend: Low Confidence Handling',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisPrompt(Color themeColor) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor.withOpacity(0.1),
              themeColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology,
                  size: 40,
                  color: themeColor,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Ready for Water Detection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Your photos are ready for AI analysis. The system will detect water and analyze quality, including low confidence results.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _detectWaterQuality(_imageFiles.first),
                  icon: Icon(Icons.search, size: 24),
                  label: Text(
                    'Start Water Detection',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Enhanced result card with low confidence handling
  Widget _buildAnalysisResultCard(Color themeColor) {
    if (!_analysisCompleted) return Container();
    
    final resultColor = _waterDetected 
        ? (_isLowConfidence ? Colors.amber : WaterQualityUtils.getWaterQualityColor(_detectedQuality))
        : Colors.orange;
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              resultColor.withOpacity(0.03),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _waterDetected 
                            ? (_isLowConfidence 
                                ? [Colors.amber, Colors.amber.shade400]
                                : [Colors.green, Colors.green.shade400])
                            : [Colors.orange, Colors.orange.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _waterDetected 
                          ? (_isLowConfidence ? Icons.info : Icons.check_circle)
                          : Icons.warning,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _waterDetected 
                              ? (_isLowConfidence ? 'Low Confidence Result' : 'Analysis Complete')
                              : 'Water Not Detected',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _waterDetected 
                              ? (_isLowConfidence 
                                  ? 'Water detected but consider retaking photo'
                                  : 'Water quality analyzed successfully')
                              : 'No water found in image',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _detectWaterQuality(_imageFiles.first),
                    icon: Icon(Icons.refresh, color: themeColor),
                    tooltip: 'Re-analyze',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Main result display
              if (_waterDetected) ...[
                // WATER DETECTED - SHOW QUALITY RESULTS (including low confidence)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: resultColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: resultColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: resultColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              WaterQualityUtils.getWaterQualityIcon(_detectedQuality),
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  WaterQualityUtils.getWaterQualityText(_detectedQuality),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: resultColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (_originalClass != null && _originalClass!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: resultColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Class: $_originalClass',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: resultColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    
                                    // ADDED: Low confidence indicator
                                    if (_isLowConfidence) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info, size: 12, color: Colors.amber.shade700),
                                            SizedBox(width: 4),
                                            Text(
                                              'LOW CONF',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.amber.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Confidence section
                      if (_confidence != null) ...[
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Confidence Level',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getConfidenceColor(_confidence!),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getConfidenceColor(_confidence!).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isLowConfidence)
                                        Icon(Icons.info, color: Colors.white, size: 14),
                                      if (_isLowConfidence)
                                        SizedBox(width: 4),
                                      Text(
                                        '${_confidence!.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            Text(
                              _getConfidenceLevelText(_confidence!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getConfidenceColor(_confidence!),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.grey.shade200,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _confidence! / 100,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getConfidenceColor(_confidence!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    WaterQualityUtils.getWaterQualityDescription(_detectedQuality),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                // ADDED: Low confidence guidance
                if (_isLowConfidence) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade50, Colors.amber.shade100.withOpacity(0.3)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Low Confidence Result:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _analysisMessage ?? 'The analysis found water and determined quality, but confidence is below the preferred threshold. Consider retaking the photo with better lighting or a clearer view of the water for higher accuracy.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade800,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // NO WATER DETECTED - SHOW GUIDANCE (same as before)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 48,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Water Detected',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _analysisMessage ?? 'The AI system could not detect water in your image.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Tips for Better Detection:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Take photo showing clear water surface\n'
                              '• Ensure good lighting conditions\n'
                              '• Avoid photos with only containers or pipes\n'
                              '• Include water body in the frame',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 90) return Colors.green.shade600;
    if (confidence >= 80) return Colors.lightGreen.shade600;
    if (confidence >= 70) return Colors.orange.shade600;
    if (confidence >= 60) return Colors.deepOrange.shade600;
    return Colors.red.shade600;
  }
  
  String _getConfidenceLevelText(double confidence) {
    if (confidence >= 90) return 'EXCELLENT CONFIDENCE';
    if (confidence >= 80) return 'HIGH CONFIDENCE';
    if (confidence >= 70) return 'GOOD CONFIDENCE';
    if (confidence >= 60) return 'MODERATE CONFIDENCE';
    return 'LOW CONFIDENCE';
  }

  // Keep all other build methods exactly the same...
  Widget _buildAdminIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100.withOpacity(0.3),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Mode with Low Confidence Handling',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Advanced water detection with quality analysis - now handles all confidence levels properly',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: widget.isAdmin ? Colors.orange : AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Report Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _reporterNameController,
              decoration: InputDecoration(
                labelText: 'Reporter Name *',
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter reporter name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Issue Title *',
                hintText: 'Brief title describing the issue',
                prefixIcon: Icon(Icons.title),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Detailed description of the water issue',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: widget.isAdmin ? 4 : 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Location Address *',
                hintText: 'Where is this issue located?',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton(Color themeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor,
              themeColor.withOpacity(0.8),
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: (_isLoading || _isSavingImages) ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isLoading || _isSavingImages
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isSavingImages 
                        ? 'Preparing for analysis...'
                        : widget.isAdmin
                          ? 'Creating admin report...'
                          : 'Submitting report...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isAdmin ? Icons.admin_panel_settings : Icons.send,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isAdmin ? 'Create Enhanced Report' : 'Submit Enhanced Report',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _reporterNameController.dispose();
    
    super.dispose();
  }
}