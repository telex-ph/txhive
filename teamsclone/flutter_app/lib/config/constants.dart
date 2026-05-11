class AppConfig {
  // Change this to your deployed Render URL once deployed
  // For local dev:
  //   - Android emulator: http://10.0.2.2:5000
  //   - iOS simulator / desktop: http://localhost:5000
  //   - Real device: http://YOUR_LAN_IP:5000
  static const String baseUrl = 'http://localhost:5000';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;
}

class AppColors {
  static const primaryColor = 0xFF464EB8; // Teams purple
  static const secondaryColor = 0xFF6264A7;
  static const bgDark = 0xFF1F1F1F;
  static const bgLight = 0xFFF5F5F5;
  static const sidebar = 0xFF2D2C2C;
  static const onlineGreen = 0xFF92C353;
  static const awayYellow = 0xFFF9D649;
  static const busyRed = 0xFFC4314B;
}
