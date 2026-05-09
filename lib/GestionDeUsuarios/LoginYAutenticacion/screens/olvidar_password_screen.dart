// ignore_for_file: unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:histolink/shared/config/api_config.dart';

// Colores consistentes con el resto de la app
const _kPrimary = Color(0xFF0023B8);
const _kAccent  = Color(0xFF00A896);
const _kError   = Color(0xFFDC2626);
const _kFondo   = Color(0xFFF0F6FF);

/// Flujo de 3 pasos para recuperar la contraseña vía email.
/// Paso 1 → ingresa email → Paso 2 → ingresa código → Paso 3 → nueva contraseña.
class OlvidarPasswordScreen extends StatefulWidget {
  const OlvidarPasswordScreen({super.key});

  @override
  State<OlvidarPasswordScreen> createState() => _OlvidarPasswordScreenState();
}

class _OlvidarPasswordScreenState extends State<OlvidarPasswordScreen> {
  int _paso = 1;

  // Controladores
  final _emailCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  // ── Paso 1: solicitar código ──────────────────────────────────────────
  Future<void> _sendCode() async {
    setState(() { _error = null; _loading = true; });
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() { _error = 'Ingresa tu correo electrónico.'; _loading = false; });
      return;
    }
    try {
      final resp = await http.post(
        ApiConfig.uri('/api/auth/forgot-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (resp.statusCode == 200) {
        setState(() { _paso = 2; _loading = false; });
      } else {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _error = (data['error'] ?? 'Error al enviar el código.').toString();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() { _error = 'Error de conexión. Verifica tu red.'; _loading = false; });
    }
  }

  // ── Paso 2: verificar código (solo formato, validación real en paso 3) ──
  void _verifyCode() {
    setState(() => _error = null);
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'El código debe ser de 6 dígitos numéricos.');
      return;
    }
    setState(() => _paso = 3);
  }

  // ── Paso 3: nueva contraseña ──────────────────────────────────────────
  Future<void> _resetPassword() async {
    setState(() { _error = null; _loading = true; });
    final pass1 = _pass1Ctrl.text;
    final pass2 = _pass2Ctrl.text;
    if (pass1.length < 8) {
      setState(() { _error = 'La contraseña debe tener al menos 8 caracteres.'; _loading = false; });
      return;
    }
    if (pass1 != pass2) {
      setState(() { _error = 'Las contraseñas no coinciden.'; _loading = false; });
      return;
    }
    try {
      final resp = await http.post(
        ApiConfig.uri('/api/auth/reset-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':                _emailCtrl.text.trim().toLowerCase(),
          'code':                 _codeCtrl.text.trim(),
          'new_password':         pass1,
          'new_password_confirm': pass2,
        }),
      );
      if (resp.statusCode == 200) {
        setState(() { _paso = 4; _loading = false; });
      } else {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _error = (data['error'] ?? 'Código inválido o expirado.').toString();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() { _error = 'Error de conexión. Verifica tu red.'; _loading = false; });
    }
  }

  // ── Layout base ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 200,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF122268),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.lock_reset_outlined, color: _kPrimary, size: 40),
        ),
        const SizedBox(height: 12),
        const Text('Histolink', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        const Text('Recuperar contraseña', style: TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: switch (_paso) {
        1 => _buildPaso1(),
        2 => _buildPaso2(),
        3 => _buildPaso3(),
        _ => _buildExito(),
      },
    );
  }

  // ── Paso 1 UI ─────────────────────────────────────────────────────────
  Widget _buildPaso1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary)),
        const SizedBox(height: 6),
        const Text('Ingresa tu correo y te enviaremos un código de 6 dígitos.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 24),
        _buildField(
          controller: _emailCtrl,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _sendCode(),
        ),
        if (_error != null) _buildError(_error!),
        const SizedBox(height: 20),
        _buildPrimaryBtn('Enviar código', _loading ? null : _sendCode, loading: _loading),
        const SizedBox(height: 10),
        _buildBackBtn(() => Navigator.pop(context)),
      ],
    );
  }

  // ── Paso 2 UI ─────────────────────────────────────────────────────────
  Widget _buildPaso2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Código de verificación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Enviamos un código a ',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            children: [
              TextSpan(text: _emailCtrl.text.trim(), style: const TextStyle(fontWeight: FontWeight.w600, color: _kPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10, color: _kPrimary),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(fontSize: 22, color: Colors.grey.shade300, letterSpacing: 10),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onChanged: (v) => _codeCtrl.value = _codeCtrl.value.copyWith(
            text: v.replaceAll(RegExp(r'\D'), ''),
            selection: TextSelection.collapsed(offset: v.replaceAll(RegExp(r'\D'), '').length),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        if (_error != null) _buildError(_error!),
        const SizedBox(height: 20),
        _buildPrimaryBtn('Verificar código', _verifyCode),
        const SizedBox(height: 10),
        _buildOutlineBtn('Reenviar código', _loading ? null : _sendCode),
        const SizedBox(height: 6),
        _buildBackBtn(() => setState(() { _paso = 1; _error = null; })),
      ],
    );
  }

  // ── Paso 3 UI ─────────────────────────────────────────────────────────
  Widget _buildPaso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nueva contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary)),
        const SizedBox(height: 6),
        const Text('Mínimo 8 caracteres.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(
          controller: _pass1Ctrl,
          obscureText: _obscure1,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: const Icon(Icons.lock_outline, color: _kPrimary),
            suffixIcon: IconButton(
              icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _kPrimary),
              onPressed: () => setState(() => _obscure1 = !_obscure1),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pass2Ctrl,
          obscureText: _obscure2,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outline, color: _kPrimary),
            suffixIcon: IconButton(
              icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _kPrimary),
              onPressed: () => setState(() => _obscure2 = !_obscure2),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
          ),
          onSubmitted: (_) => _resetPassword(),
        ),
        if (_error != null) _buildError(_error!),
        const SizedBox(height: 20),
        _buildPrimaryBtn('Cambiar contraseña', _loading ? null : _resetPassword, loading: _loading),
        const SizedBox(height: 10),
        _buildBackBtn(() => setState(() { _paso = 2; _error = null; })),
      ],
    );
  }

  // ── Paso 4: éxito ─────────────────────────────────────────────────────
  Widget _buildExito() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 56),
        ),
        const SizedBox(height: 20),
        const Text('¡Contraseña actualizada!', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _kPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text('Tu contraseña fue cambiada exitosamente.\nYa puedes iniciar sesión.', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _buildPrimaryBtn('Ir al Login', () => Navigator.pop(context)),
      ],
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kPrimary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kError.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _kError, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: _kError, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryBtn(String label, VoidCallback? onTap, {bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildOutlineBtn(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBackBtn(VoidCallback onTap) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back, size: 15, color: Colors.grey),
        label: const Text('Volver', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ),
    );
  }
}
