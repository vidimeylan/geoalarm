import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth_service.dart';
import '../../services/token_storage.dart';
import '../home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    print('[AuthGate] Checking authentication...');
    // Check if we have a valid token
    final token = await AuthService().getValidAccessToken();
    print('[AuthGate] Token check result: ${token != null ? "valid token found" : "no valid token"}');

    if (token != null) {
      print('[AuthGate] User authenticated, showing home screen');
      setState(() => _authenticated = true);
    } else {
      print('[AuthGate] User not authenticated, showing login screen');
      setState(() => _authenticated = false);
    }
    setState(() => _checking = false);
  }

  void _handleAuthenticated() {
    setState(() => _authenticated = true);
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_authenticated) {
      return const HomeScreen();
    }

    return AuthScreen(
      onAuthenticated: _handleAuthenticated,
    );
  }
}

class AuthScreen extends StatelessWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Siaga Turun - Autentikasi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Masuk'),
              Tab(text: 'Daftar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LoginForm(onAuthenticated: onAuthenticated),
            RegisterForm(),
          ],
        ),
        bottomNavigationBar: const _AuthActions(),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginForm({super.key, required this.onAuthenticated});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _loadingGoogle = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masuk',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          iconSize: 20, // Smaller icon size
                          padding: EdgeInsets.zero, // Remove padding
                          constraints: const BoxConstraints(), // Remove constraints
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_loading || _loadingGoogle) ? null : _loginWithGoogle,
                        icon: _loadingGoogle
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login, size: 18), // Smaller icon
                        label: const Text('Masuk dengan Google', style: TextStyle(fontSize: 14)), // Smaller text
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Smaller padding
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ResetFlowScreen()),
                          );
                        },
                        child: const Text('Lupa password?'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final idToken = await _obtainGoogleIdToken();
      if (idToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Google dibatalkan.')),
        );
        return;
      }
      await AuthService().loginWithGoogle(idToken: idToken);
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<String?> _obtainGoogleIdToken() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '410623037085-b3bnjvhqsv96p782ahep9vuh8s2mht89.apps.googleusercontent.com',
      );
      final account = await googleSignIn.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.idToken;
    } catch (e) {
      rethrow;
    }
  }
}

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

enum _RegisterStep { form, otp }

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _loading = false;
  _RegisterStep _step = _RegisterStep.form;
  int _countdown = 0;
  Timer? _timer;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        setState(() => _countdown = 0);
        timer.cancel();
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().sendOtp(_emailController.text.trim());
      await TokenStorage.saveOtpRequestedAtNow();
      _startCountdown();
      if (!mounted) return;
      setState(() => _step = _RegisterStep.otp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP dikirim. Tunggu sekitar 1 menit lalu masukkan kodenya.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerWithOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Masukkan kode OTP terlebih dahulu.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().verifyOtp(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
      await AuthService().register(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil. Silakan login.')),
      );
      DefaultTabController.of(context)?.animateTo(0);
      setState(() {
        _step = _RegisterStep.form;
        _otpController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == _RegisterStep.form
                    ? _buildForm(cardColor)
                    : _buildOtp(cardColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Color cardColor) {
    return Card(
      color: cardColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daftar Akun',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Nama wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Username wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    iconSize: 20, // Smaller icon size
                    padding: EdgeInsets.zero, // Remove padding
                    constraints: const BoxConstraints(), // Remove constraints
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Password wajib diisi';
                  if (value.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim OTP & Lanjut'),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Setelah OTP dikirim, tunggu sekitar 1 menit. Masukkan kode untuk menyelesaikan registrasi.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtp(Color cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verifikasi OTP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'OTP dikirim ke ${_emailController.text}. Tunggu 1 menit jika belum menerima. Kalau gagal, kirim ulang.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: 'Kode OTP'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _registerWithOtp,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verifikasi & Daftar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_loading || _countdown > 0)
                        ? null
                        : () async {
                            await _sendOtp();
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _countdown > 0
                          ? 'Kirim ulang ($_countdown s)'
                          : 'Kirim ulang OTP',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Divider(height: 12),
          ],
        ),
      ),
    );
  }
}

class SendOtpScreen extends StatefulWidget {
  const SendOtpScreen({super.key});

  @override
  State<SendOtpScreen> createState() => _SendOtpScreenState();
}

class _SendOtpScreenState extends State<SendOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  Future<void> _initCountdown() async {
    final requestedAt = await TokenStorage.getOtpRequestedAtMillis();
    if (requestedAt == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((now - requestedAt) ~/ 1000);
    final remaining = 60 - elapsed;
    if (remaining > 0) {
      setState(() => _remainingSeconds = remaining);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        _timer?.cancel();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_remainingSeconds > 0) return;
    setState(() => _loading = true);
    try {
      await AuthService().sendOtp(_emailController.text.trim());
      await TokenStorage.saveOtpRequestedAtNow();
      await _initCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP berhasil dikirim, cek email.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (_remainingSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Tunggu $_remainingSeconds detik sebelum kirim OTP lagi.',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || _remainingSeconds > 0) ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim OTP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  Future<void> _initCountdown() async {
    final requestedAt = await TokenStorage.getOtpRequestedAtMillis();
    if (requestedAt == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((now - requestedAt) ~/ 1000);
    final remaining = 60 - elapsed;
    if (remaining > 0) {
      setState(() => _remainingSeconds = remaining);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        _timer?.cancel();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().verifyOtp(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP tervalidasi. Token OTP tersimpan.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(labelText: 'Kode OTP'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'OTP wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verifikasi OTP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetFlowScreen extends StatefulWidget {
  const ResetFlowScreen({super.key});

  @override
  State<ResetFlowScreen> createState() => _ResetFlowScreenState();
}

enum _ResetStep { email, otp, password }

class _ResetFlowScreenState extends State<ResetFlowScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _loading = false;
  int _countdown = 0;
  Timer? _timer;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        setState(() => _countdown = 0);
        timer.cancel();
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Email wajib diisi.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().sendOtp(_emailController.text.trim());
      await TokenStorage.saveOtpRequestedAtNow();
      _startCountdown();
      if (!mounted) return;
      setState(() => _step = _ResetStep.otp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP dikirim. Tunggu sekitar 1 menit.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Masukkan kode OTP terlebih dahulu.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().verifyOtp(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.password);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP valid. Silakan atur password baru.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_passController.text.isEmpty || _confirmController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password wajib diisi.')));
      return;
    }
    if (_passController.text != _confirmController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password tidak sama.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(newPassword: _passController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil direset. Silakan login.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildStep(cardColor),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(Color cardColor) {
    switch (_step) {
      case _ResetStep.email:
        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Masukkan Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim OTP'),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Kami kirimkan OTP ke email. Tunggu 1 menit jika belum menerima.'),
              ],
            ),
          ),
        );
      case _ResetStep.otp:
        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verifikasi OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Email: ${_emailController.text}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'Kode OTP'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verifyOtp,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verifikasi OTP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_loading || _countdown > 0)
                            ? null
                            : () async {
                                await _sendOtp();
                              },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _countdown > 0 ? 'Kirim ulang ($_countdown s)' : 'Kirim ulang OTP',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _ResetStep.password:
        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: 'Password baru',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                  ),
                  obscureText: _obscureNewPassword,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan password'),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
