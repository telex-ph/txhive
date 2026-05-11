import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<bool> tryAutoLogin() async {
    _loading = true;
    notifyListeners();
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        _loading = false;
        notifyListeners();
        return false;
      }
      final data = await ApiService.get('/auth/me');
      _user = User.fromJson(data);
      await SocketService.connect();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await ApiService.clearToken();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.post('/auth/login', {'email': email, 'password': password}, auth: false);
      await ApiService.setToken(data['token']);
      _user = User.fromJson(data);
      await SocketService.connect();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.post(
        '/auth/register',
        {'name': name, 'email': email, 'password': password},
        auth: false,
      );
      await ApiService.setToken(data['token']);
      _user = User.fromJson(data);
      await SocketService.connect();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    SocketService.disconnect();
    _user = null;
    notifyListeners();
  }
}
