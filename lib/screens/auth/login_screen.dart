import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _autoLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final savedEmail = await _storage.read(key: 'saved_email');
    final savedPassword = await _storage.read(key: 'saved_password');
    final autoLoginStr = await _storage.read(key: 'auto_login');
    final autoLogin = autoLoginStr == 'true';

    if (savedEmail != null && savedPassword != null && autoLogin) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _autoLogin = autoLogin;
      });

      // UI 렌더링 후 자동 로그인 시도
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _login();
        }
      });
    }
  }

  Future<void> _saveCredentials() async {
    if (_autoLogin) {
      await _storage.write(key: 'saved_email', value: _emailController.text.trim());
      await _storage.write(key: 'saved_password', value: _passwordController.text);
      await _storage.write(key: 'auto_login', value: 'true');
    } else {
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
      await _storage.delete(key: 'auto_login');
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // 이전 에러 초기화
      authProvider.clearError();
      
      final success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success) {
        // 로그인 성공 시 자격 증명 저장
        await _saveCredentials();
        
        // main.dart의 AuthWrapper에서 자동으로 적절한 화면으로 이동됨
        // 여기서는 별도의 네비게이션이 필요 없음
      } else {
        // 로그인 실패 시 에러 메시지가 authProvider.error에 설정됨
        print('로그인 실패: ${authProvider.error}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 화면 터치 시 키보드 숨기기
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 40.h),
                  // 앱 로고/제목
                  Icon(
                    Icons.cloud,
                    size: 80.sp,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '날씨 알림',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '위치 기반 날씨 정보를 받아보세요',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 48.h),

                  // 이메일 입력
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: '이메일',
                      labelStyle: TextStyle(fontSize: 14.sp),
                      prefixIcon: Icon(Icons.email, size: 20.sp),
                      border: const OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해주세요';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return '올바른 이메일 형식이 아닙니다';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // 비밀번호 입력
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(fontSize: 14.sp),
                    onFieldSubmitted: (_) {
                      // Done 버튼 클릭 시 키보드 숨기고 로그인 시도
                      FocusScope.of(context).unfocus();
                      _login();
                    },
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      labelStyle: TextStyle(fontSize: 14.sp),
                      prefixIcon: Icon(Icons.lock, size: 20.sp),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          size: 20.sp,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // 자동 로그인 체크박스
                  Row(
                    children: [
                      Checkbox(
                        value: _autoLogin,
                        onChanged: (value) {
                          setState(() {
                            _autoLogin = value ?? false;
                          });
                        },
                      ),
                      Text('자동 로그인', style: TextStyle(fontSize: 14.sp)),
                      const Spacer(),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // 로그인 버튼
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                        ),
                        child: authProvider.isLoading
                            ? SizedBox(
                                height: 20.h,
                                width: 20.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('로그인', style: TextStyle(fontSize: 16.sp)),
                      );
                    },
                  ),
                  SizedBox(height: 16.h),

                  // 회원가입 링크
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      '계정이 없으신가요? 회원가입',
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ),

                  // 에러 메시지
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.error != null) {
                        return Container(
                          margin: EdgeInsets.only(top: 16.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            authProvider.error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}