// lib/screens/simplified/simple_report_screen.dart - FIXED: Better Threshold/Low Confidence Error Handling
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
  
  // ENHANCED: Better error state management
  bool _waterDetected = false;
  String? _analysisMessage;
  bool _analysisCompleted = false;
  String? _detectionError;
  bool _isLowConfidence = false;
  bool _canSubmitWithLowConfidence = false; // NEW: Allow submission even with low confidence
  
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _reporterNameController.text = widget.isAdmin ? 'Admin User' : 'Test User';
    
    print('📱 SimpleReport initialized with ENHANCED error handling');
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        setState(() {
          _location = _locationService.positionToGeoPoint(position);
          _autoAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxImages) {
      _showMessage('Maximum $_maxImages images allowed', isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Text('Add Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  title: 'Camera',
                  subtitle: 'Take new photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                )),
                SizedBox(width: 16),
                Expanded(child: _buildImageSourceOption(
                  icon: Icons.photo_library,
                  title: 'Gallery',
                  subtitle: 'Choose existing',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                )),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 32, color: widget.isAdmin ? Colors.orange : AppTheme.primaryColor),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      print('📷 Opening image picker...');
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
          setState(() => _isSavingImages = true);
          
          final processedImageFile = await _processImageForAnalysis(imageFile, source);
          final folder = widget.isAdmin ? 'admin_reports' : 'reports';
          final localPath = await _storageService.uploadImage(processedImageFile, folder);
          
          print('📁 Image saved to local storage: $localPath');
          
          setState(() {
            _imageFiles.add(File(localPath));
            _savedImagePaths.add(localPath);
            _isSavingImages = false;
          });
          
          // Reset analysis results when new image added
          if (_imageFiles.length == 1) {
            _resetAnalysisState();
          }
          
          _showMessage('Image processed and saved successfully!', isError: false);
          
          if (_imageFiles.length == 1) {
            print('🔬 Auto-analyzing first image...');
            await _detectWaterQuality(File(localPath));
          }
          
        } catch (e) {
          setState(() => _isSavingImages = false);
          _showMessage('Error processing image: $e', isError: true);
        }
      }
    } catch (e) {
      setState(() => _isSavingImages = false);
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<File> _processImageForAnalysis(File originalFile, ImageSource source) async {
    try {
      print('🔧 Processing image for analysis...');
      
      final imageBytes = await originalFile.readAsBytes();
      print('📏 Original size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = path.join(tempDir.path, 'processed_${timestamp}.jpg');
      
      final processedFile = await originalFile.copy(processedPath);
      
      if (await processedFile.exists()) {
        final processedSize = await processedFile.length();
        print('✅ Image processed: ${(processedSize / 1024).toStringAsFixed(2)} KB');
        return processedFile;
      } else {
        throw Exception('Failed to create processed image');
      }
      
    } catch (e) {
      print('❌ Error processing image: $e');
      return originalFile;
    }
  }

  // ENHANCED: Water quality detection with comprehensive error handling
  Future<void> _detectWaterQuality(File image) async {
    try {
      _resetAnalysisState();
      setState(() => _isDetecting = true);
      
      print('🔬 Starting enhanced water quality detection...');
      
      // Validate image file
      if (!await image.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final fileSize = await image.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      print('📏 Image size: ${fileSize} bytes');
      
      // Test backend connection
      final isConnected = await _apiService.testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server is not running. Please start the Python server.');
      }
      
      print('✅ Backend connected, analyzing image...');
      
      // Analyze water quality with comprehensive error handling
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      print('📊 Analysis result:');
      print('   Water detected: ${result.waterDetected}');
      print('   Quality: ${result.waterQuality}');
      print('   Confidence: ${result.confidence}%');
      print('   Low confidence: ${result.isLowConfidence}');
      
      setState(() {
        _waterDetected = result.waterDetected;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _analysisCompleted = true;
        _isDetecting = false;
        _isLowConfidence = result.isLowConfidence;
        _canSubmitWithLowConfidence = true; // ENHANCED: Always allow submission
      });
      
      // ENHANCED: Handle all possible scenarios without blocking submission
      _handleAnalysisResult(result);
      
    } catch (e) {
      print('❌ Analysis failed: $e');
      
      setState(() {
        _isDetecting = false;
        _analysisCompleted = true;
        _detectionError = e.toString();
        _canSubmitWithLowConfidence = true; // ENHANCED: Allow submission even on error
      });
      
      _handleAnalysisError(e);
    }
  }
  
  // ENHANCED: Handle analysis results without blocking user
  void _handleAnalysisResult(WaterAnalysisResult result) {
    if (!result.waterDetected) {
      // NO WATER DETECTED
      _showMessage(
        'No water detected in image. You can still submit the report, but consider adding photos that clearly show water.',
        isError: false,
        duration: 6,
      );
      
    } else if (result.isLowConfidence) {
      // LOW CONFIDENCE BUT DETECTED
     
      
    } else if (result.confidence != null && result.confidence! > 0) {

      
    } else {
      // ANALYSIS FAILED BUT WATER DETECTED
      _showMessage(
        'Water detected but analysis had issues. You can still submit the report with your observations.',
        isError: false,
        duration: 6,
      );
    }
  }
  
  // ENHANCED: Handle analysis errors gracefully
  void _handleAnalysisError(dynamic error) {
    String userFriendlyMessage = 'Analysis error occurred, but you can still submit your report manually.';
    
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('backend') || errorStr.contains('server')) {
      userFriendlyMessage = 'Backend server not available. You can still submit the report without AI analysis.';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      userFriendlyMessage = 'Network connection issue. You can still submit the report offline.';
    } else if (errorStr.contains('timeout')) {
      userFriendlyMessage = 'Analysis timeout. You can still submit the report with your manual assessment.';
    } else if (errorStr.contains('image')) {
      userFriendlyMessage = 'Image processing issue. Try another photo or submit with current observations.';
    }
    
    _showMessage(userFriendlyMessage, isError: false, duration: 8);
  }
  
  void _resetAnalysisState() {
    setState(() {
      _detectedQuality = WaterQualityState.unknown;
      _confidence = null;
      _originalClass = null;
      _waterDetected = false;
      _analysisMessage = null;
      _analysisCompleted = false;
      _detectionError = null;
      _isLowConfidence = false;
      _canSubmitWithLowConfidence = false;
    });
  }
  
  void _removeImage(int index) {
    if (index >= 0 && index < _imageFiles.length) {
      final file = _imageFiles[index];
      final localPath = _savedImagePaths[index];
      
      setState(() {
        _imageFiles.removeAt(index);
        _savedImagePaths.removeAt(index);
        
        if (_imageFiles.isEmpty) {
          _resetAnalysisState();
        }
      });
      
      try {
        if (file.existsSync()) {
          file.deleteSync();
          print('🗑️ Deleted local file: $localPath');
        }
      } catch (e) {
        print('❌ Error deleting local file: $e');
      }
    }
  }
  
  // ENHANCED: Allow submission regardless of analysis state
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_location == null) {
      _showMessage('Location is required. Please try again.', isError: true);
      return;
    }
    
    // ENHANCED: Show confirmation dialog for low confidence or no analysis
    if ((_isLowConfidence || _detectionError != null || !_waterDetected) && _imageFiles.isNotEmpty) {
      final shouldContinue = await _showSubmissionConfirmationDialog();
      if (!shouldContinue) return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('📝 Starting report submission...');
      
      final imageUrls = List<String>.from(_savedImagePaths);
      
      print('📸 Using ${imageUrls.length} local image paths');
      
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
      
      print('✅ Report created successfully with ID: $reportId');
      
      if (mounted) {
        String successMessage = _buildSuccessMessage(imageUrls.length);
        _showMessage(successMessage, isError: false, duration: 6);
        Navigator.pop(context);
      }
      
    } catch (e) {
      print('❌ Error submitting report: $e');
      _showMessage('Error submitting report: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // NEW: Show confirmation dialog for problematic submissions
  Future<bool> _showSubmissionConfirmationDialog() async {
    String title = 'Confirm Submission';
    String message = '';
    
    if (_detectionError != null) {
      title = 'Submit Without Analysis?';
      message = 'AI analysis failed, but you can still submit this report with your manual observations. Continue?';
    } else if (!_waterDetected && _imageFiles.isNotEmpty) {
      title = 'No Water Detected';
      message = 'AI did not detect water in your images. Do you still want to submit this report?';
    } else if (_isLowConfidence) {
      title = 'Low Confidence Result';
      message = 'AI analysis has low confidence (${_confidence?.toStringAsFixed(1)}%). The result might not be accurate. Continue with submission?';
    } else {
      return true; // No confirmation needed
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('Submit Anyway'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  String _buildSuccessMessage(int imageCount) {
    String baseMessage = 'Report submitted successfully with $imageCount image${imageCount == 1 ? '' : 's'}!';
    
    if (_analysisCompleted && _waterDetected && _confidence != null) {
      if (_isLowConfidence) {
        baseMessage += '\nSubmitted with low confidence analysis (${_confidence!.toStringAsFixed(1)}%).';
      } else if (_confidence! >= 80) {
        baseMessage += '\nHigh confidence analysis included (${_confidence!.toStringAsFixed(1)}%).';
      } else {
        baseMessage += '\nAnalysis included with ${_confidence!.toStringAsFixed(1)}% confidence.';
      }
    } else if (_analysisCompleted && !_waterDetected) {
      baseMessage += '\nSubmitted without water detection - manual assessment included.';
    } else if (_detectionError != null) {
      baseMessage += '\nSubmitted without AI analysis - manual assessment recorded.';
    }
    
    return baseMessage;
  }
  
  void _showMessage(String message, {required bool isError, int duration = 4}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: TextStyle(fontSize: 14))),
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
                      Text('${_imageFiles.length}/$_maxImages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && !_isSavingImages
        ? Center(child: WaterFillLoader(message: 'Getting your location...'))
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
  
  // ENHANCED: Better status indicators
  Widget _buildImageSection(Color themeColor) {
    return Column(
      children: [
        // Header Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [themeColor.withOpacity(0.1), themeColor.withOpacity(0.05)],
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
                        decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.analytics, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAdmin ? 'Enhanced AI Analysis' : 'Smart Water Detection',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_imageFiles.length}/$_maxImages photos • Enhanced error handling',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (_imageFiles.length < _maxImages)
                        Container(
                          decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            onPressed: _isSavingImages ? null : _pickImage,
                            icon: _isSavingImages 
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : Icon(Icons.add, color: Colors.white),
                            tooltip: 'Add Photo',
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ENHANCED: Status banner
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
                          decoration: BoxDecoration(color: _getStatusColor(), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_getStatusIcon(), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getStatusTitle(), style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(), fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(_getStatusSubtitle(), style: TextStyle(color: _getStatusColor().withOpacity(0.8), fontSize: 13)),
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
        
        // Photos Grid
        if (_imageFiles.isNotEmpty) _buildPhotosGrid(themeColor),
        
        const SizedBox(height: 16),
        
        // Camera Button
        _buildCameraButton(themeColor),
        
        const SizedBox(height: 16),
        
        // Analysis Results
        if (_isDetecting) _buildAnalyzingCard(themeColor)
        else if (_analysisCompleted) _buildAnalysisResultCard(themeColor)
        else if (_imageFiles.isNotEmpty) _buildAnalysisPrompt(themeColor),
      ],
    );
  }

  Widget _buildPhotosGrid(Color themeColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Saved Photos', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      Icon(_getAnalysisStatusIcon(), size: 12, color: _getAnalysisStatusColor()),
                      SizedBox(width: 4),
                      Text(_getAnalysisStatusText(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getAnalysisStatusColor())),
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
              itemBuilder: (context, index) => _buildImageTile(index, themeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(int index, Color themeColor) {
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
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder, color: Colors.grey.shade400, size: 20),
                          SizedBox(height: 4),
                          Text('Local\nStorage', style: TextStyle(fontSize: 8, color: Colors.grey.shade600), textAlign: TextAlign.center),
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
              decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(6)),
              child: Text('MAIN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        
        // Analysis status
        if (isMainPhoto && _analysisCompleted)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: _getAnalysisStatusColor(), borderRadius: BorderRadius.circular(4)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getAnalysisStatusIcon(), color: Colors.white, size: 8),
                  SizedBox(width: 2),
                  Text(_getAnalysisStatusText(), style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraButton(Color themeColor) {
    return Card(
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
                  ? 'Preparing for enhanced water detection...'
                  : _imageFiles.isEmpty
                      ? 'AI will analyze for water presence and quality (with error recovery)'
                      : 'Multiple photos improve detection accuracy',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_imageFiles.length < _maxImages && !_isSavingImages) ? _pickImage : null,
                icon: _isSavingImages
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Icon(_imageFiles.isEmpty ? Icons.camera_alt : Icons.add_a_photo),
                label: Text(
                  _isSavingImages
                      ? 'Processing...'
                      : _imageFiles.isEmpty 
                          ? 'Take Photo' 
                          : _imageFiles.length < _maxImages 
                              ? 'Add More Photos' 
                              : 'Limit Reached',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _imageFiles.length < _maxImages && !_isSavingImages ? themeColor : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.3)],
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
                  gradient: LinearGradient(colors: [Colors.blue, Colors.blue.shade300]),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Enhanced Water Detection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              const SizedBox(height: 8),
              Text(
                'AI is analyzing your image with enhanced error handling. All scenarios are supported.',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Backend: Enhanced Error Recovery', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
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
            colors: [themeColor.withOpacity(0.1), themeColor.withOpacity(0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.psychology, size: 40, color: themeColor),
              ),
              const SizedBox(height: 16),
              Text('Ready for Water Detection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor)),
              const SizedBox(height: 8),
              Text(
                'Your photos are ready for AI analysis with enhanced error handling. Analysis will work even with challenging images.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _detectWaterQuality(_imageFiles.first),
                  icon: Icon(Icons.search, size: 24),
                  label: Text('Start Water Detection', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ENHANCED: Comprehensive analysis result display
  Widget _buildAnalysisResultCard(Color themeColor) {
    if (!_analysisCompleted) return Container();
    
    Color resultColor = _waterDetected 
        ? (_isLowConfidence ? Colors.amber : WaterQualityUtils.getWaterQualityColor(_detectedQuality))
        : (_detectionError != null ? Colors.red : Colors.orange);
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, resultColor.withOpacity(0.03)],
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
                      gradient: LinearGradient(colors: [resultColor, resultColor.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getResultIcon(), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getResultTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_getResultSubtitle(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
              
              // Main result content
              _buildResultContent(resultColor),
              
              const SizedBox(height: 16),
              
              // ENHANCED: Always show submission option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Report can be submitted regardless of analysis result. Your manual observations are valuable.',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
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
  
  Widget _buildResultContent(Color resultColor) {
    if (_detectionError != null) {
      // ERROR CASE
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Analysis Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            const SizedBox(height: 8),
            Text(
              'AI analysis encountered an error, but you can still submit this report with your manual assessment.',
              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (!_waterDetected) {
      // NO WATER DETECTED
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text('No Water Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
            const SizedBox(height: 8),
            Text(
              _analysisMessage ?? 'AI did not detect water in your image. You can still submit if you observed water quality issues.',
              style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // WATER DETECTED
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: resultColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: resultColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: resultColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: resultColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Icon(WaterQualityUtils.getWaterQualityIcon(_detectedQuality), color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WaterQualityUtils.getWaterQualityText(_detectedQuality),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: resultColor),
                      ),
                      const SizedBox(height: 4),
                      if (_originalClass != null && _originalClass!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: resultColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Class: $_originalClass', style: TextStyle(fontSize: 10, color: resultColor, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (_confidence != null) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confidence Level', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(_confidence!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${_confidence!.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.grey.shade200),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _confidence! / 100,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(_confidence!)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
  }

  // Helper methods for status display
  Color _getStatusColor() {
    if (_isDetecting) return Colors.blue;
    if (_detectionError != null) return Colors.red;
    if (_analysisCompleted && !_waterDetected) return Colors.orange;
    if (_analysisCompleted && _isLowConfidence) return Colors.amber;
    if (_analysisCompleted && _waterDetected) return Colors.green;
    return Colors.grey;
  }
  
  IconData _getStatusIcon() {
    if (_isDetecting) return Icons.search;
    if (_detectionError != null) return Icons.error;
    if (_analysisCompleted && !_waterDetected) return Icons.warning;
    if (_analysisCompleted && _isLowConfidence) return Icons.info;
    if (_analysisCompleted && _waterDetected) return Icons.check_circle;
    return Icons.psychology;
  }
  
  String _getStatusTitle() {
    if (_isDetecting) return 'Analyzing Image...';
    if (_detectionError != null) return 'Analysis Error (Can Still Submit)';
    if (_analysisCompleted && !_waterDetected) return 'No Water Detected (Can Still Submit)';
    if (_analysisCompleted && _isLowConfidence) return 'Low Confidence Result (Can Submit)';
    if (_analysisCompleted && _waterDetected) return 'Water Quality Analyzed';
    return 'Enhanced AI Ready';
  }
  
  String _getStatusSubtitle() {
    if (_isDetecting) return 'Smart AI is checking for water presence and quality';
    if (_detectionError != null) return 'Error occurred but manual submission is available';
    if (_analysisCompleted && !_waterDetected) return 'Submit with manual observations';
    if (_analysisCompleted && _isLowConfidence) return 'Low confidence but result available';
    if (_analysisCompleted && _waterDetected) return 'Quality analysis completed successfully';
    return 'Automatic water detection with enhanced error handling';
  }

  Color _getAnalysisStatusColor() {
    if (_detectionError != null) return Colors.red;
    if (!_waterDetected && _analysisCompleted) return Colors.orange;
    if (_isLowConfidence) return Colors.amber;
    if (_confidence != null && _confidence! >= 80) return Colors.green;
    return Colors.lightGreen;
  }
  
  IconData _getAnalysisStatusIcon() {
    if (_detectionError != null) return Icons.error;
    if (!_waterDetected && _analysisCompleted) return Icons.warning;
    if (_isLowConfidence) return Icons.info;
    return Icons.check_circle;
  }
  
  String _getAnalysisStatusText() {
    if (_detectionError != null) return 'ERROR';
    if (!_waterDetected && _analysisCompleted) return 'NO H2O';
    if (_isLowConfidence) return 'LOW';
    if (_confidence != null && _confidence! >= 80) return 'HIGH';
    return 'OK';
  }

  IconData _getResultIcon() {
    if (_detectionError != null) return Icons.error;
    if (!_waterDetected) return Icons.warning_amber;
    if (_isLowConfidence) return Icons.info;
    return Icons.check_circle;
  }
  
  String _getResultTitle() {
    if (_detectionError != null) return 'Analysis Error';
    if (!_waterDetected) return 'No Water Detected';
    if (_isLowConfidence) return 'Low Confidence Result';
    return 'Water Quality Analyzed';
  }
  
  String _getResultSubtitle() {
    if (_detectionError != null) return 'Error occurred but you can still submit';
    if (!_waterDetected) return 'No water found but you can still submit';
    if (_isLowConfidence) return 'Low confidence but result is available';
    return 'Analysis completed successfully';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 90) return Colors.green.shade600;
    if (confidence >= 80) return Colors.lightGreen.shade600;
    if (confidence >= 70) return Colors.orange.shade600;
    if (confidence >= 60) return Colors.deepOrange.shade600;
    return Colors.red.shade600;
  }

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
              colors: [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.3)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange, Colors.orange.shade600]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Mode with Enhanced Error Handling', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        'Advanced water detection with comprehensive error recovery - all scenarios supported',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 14, height: 1.3),
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
                Text('Report Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            colors: [themeColor, themeColor.withOpacity(0.8)],
          ),
        ),
        child: ElevatedButton(
          onPressed: (_isLoading || _isSavingImages) ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading || _isSavingImages
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                    const SizedBox(width: 16),
                    Text(
                      _isSavingImages 
                        ? 'Preparing for analysis...'
                        : widget.isAdmin
                          ? 'Creating admin report...'
                          : 'Submitting report...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.isAdmin ? Icons.admin_panel_settings : Icons.send, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      widget.isAdmin ? 'Create Enhanced Report' : 'Submit Enhanced Report',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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