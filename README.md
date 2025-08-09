# nadiAir - Water Quality Monitoring System

A Flutter application for water quality monitoring and reporting with enhanced AI-powered analysis.

## Features

### 🔬 Double AI Verification System
- **API Model**: Traditional water quality analysis using backend API
- **Gemini AI**: Advanced visual analysis using Google's Gemini AI
- **Combined Assessment**: Enhanced accuracy through dual AI verification
- **Safety Assessment**: Comprehensive water safety evaluation

### 📱 User Features
- **Photo Capture**: Take photos of water sources
- **AI Analysis**: Automatic water quality detection
- **Location Tracking**: GPS-based location services
- **Report Submission**: Submit water quality reports
- **Real-time Results**: Instant analysis feedback

### 🗺️ Admin Features
- **Route Management**: View water supply routes
- **Report Management**: Handle user reports
- **Map Integration**: Google Maps integration
- **Data Analytics**: Comprehensive reporting system

## Technical Stack

- **Frontend**: Flutter/Dart
- **AI Models**: 
  - Custom API model for water quality analysis
  - Google Gemini AI for visual assessment
- **Maps**: Google Maps API
- **Location**: Geolocator package
- **Image Processing**: Image picker and processing

## Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd aquascan_v2
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API keys**
   - Update `lib/services/api_service.dart` with your Google Maps API key
   - Gemini API key is already configured in `lib/services/gemini_service.dart`

4. **Start the backend server**
   - Ensure your Python backend server is running on the configured IP address

5. **Run the application**
   ```bash
   flutter run
   ```

## Double Verification System

The application uses two AI models for enhanced water quality assessment:

### API Model
- Analyzes water quality parameters
- Provides confidence scores
- Handles various water quality states

### Gemini AI
- Visual analysis of water images
- Safety assessment
- Detailed quality observations
- Confidence scoring

### Combined Results
- **Agreement Level**: Shows if both models agree
- **Final Safety Assessment**: Combined safety evaluation
- **Enhanced Confidence**: Average of both model confidences
- **Recommendations**: Actionable insights

## Water Quality States

- **Optimum**: Safe water quality
- **High pH**: Elevated pH levels
- **Low pH**: Reduced pH levels
- **Low Temperature**: Below optimal temperature
- **High pH & Low Temp**: Multiple parameter issues
- **Low Temp & High pH**: Multiple parameter issues

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.
