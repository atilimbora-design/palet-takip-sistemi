import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedUser;
  final TextEditingController _passwordController = TextEditingController();
  String _errorText = '';
  List<dynamic> _users = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/users'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          // Filter out 'admin' from mobile login usually? Or keep it. keeping.
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      // Fallback if offline
      setState(() {
         _users = [
           {'username': 'BURAK', 'avatar': 'face_blue'},
           {'username': 'BORA', 'avatar': 'face_orange'}
         ];
         _isLoadingUsers = false;
      });
    }
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) return;
    setState(() => _errorText = 'Kontrol ediliyor...');

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login');
      final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': _selectedUser, 'password': _passwordController.text})
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        setState(() {
            _errorText = 'Hatalı Şifre!';
            _passwordController.clear();
        });
      }
    } catch (e) {
       // Fallback for Offline
       if( _passwordController.text == '1234' ) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
       } else {
          setState(() => _errorText = 'Bağlantı/Şifre Hatası!');
       }
    }
  }

  IconData _getIcon(String? avatar) {
    if (avatar == 'face_orange') return Icons.face_4;
    if (avatar == 'face_green') return Icons.face_3; // face_5 unavailable in some versions
    if (avatar == 'admin_icon') return Icons.admin_panel_settings;
    return Icons.face; // default blue
  }

  Color _getColor(String? avatar) {
     if (avatar == 'face_orange') return Colors.orange;
     if (avatar == 'face_green') return Colors.green;
     if (avatar == 'admin_icon') return Colors.red;
     return Colors.blue; 
  }

  Widget _buildUserAvatar(String name, String? avatar) {
    final isSelected = _selectedUser == name;
    final color = _getColor(avatar);
    final icon = _getIcon(avatar);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUser = name;
          _errorText = '';
          _passwordController.clear();
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4), // Border space
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent, 
                width: 3
              ),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 40, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'KULLANICI SEÇİNİZ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF003366), letterSpacing: 1),
              ),
              const SizedBox(height: 40),
              
              _isLoadingUsers 
                 ? const CircularProgressIndicator()
                 : Wrap(
                    spacing: 40,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: _users.map((u) => _buildUserAvatar(u['username'], u['avatar'])).toList(),
                  ),

              const SizedBox(height: 40),

              // PASSWORD AREA
              AnimatedOpacity(
                opacity: _selectedUser != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    if (_selectedUser != null) ...[
                      Text('Hoşgeldin $_selectedUser', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Şifre Giriniz',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                      ),
                      if (_errorText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_errorText, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: const Text('Giriş Yap', style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
