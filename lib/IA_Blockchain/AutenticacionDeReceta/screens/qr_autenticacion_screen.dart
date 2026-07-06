import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/qr_autenticacion_model.dart';
import '../services/autenticacion_receta_service.dart';

/// Sprint 5 — Muestra el QR de autenticación en grande con un reloj
/// regresivo de 5 minutos. Al expirar, el QR se bloquea y se puede
/// regenerar uno nuevo sin salir de la pantalla.
class QrAutenticacionScreen extends StatefulWidget {
  const QrAutenticacionScreen({
    super.key,
    required this.recetaUuid,
    required this.numeroReceta,
  });

  final String recetaUuid;
  final String numeroReceta;

  @override
  State<QrAutenticacionScreen> createState() => _QrAutenticacionScreenState();
}

class _QrAutenticacionScreenState extends State<QrAutenticacionScreen> {
  final _service = AutenticacionRecetaService();

  QrAutenticacionModel? _qr;
  bool _loading = true;
  String? _error;
  int _segundosRestantes = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generar() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await _service.generarQr(widget.recetaUuid);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _segundosRestantes = qr.expiraEnSegundos;
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _segundosRestantes--;
          if (_segundosRestantes <= 0) {
            _segundosRestantes = 0;
            t.cancel();
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _expirado => !_loading && _qr != null && _segundosRestantes <= 0;

  String get _reloj {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('QR de Autenticación'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.numeroReceta,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.azulElectrico,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'La farmacia escanea este código para verificar la '
                'autenticidad de la receta en blockchain.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: CircularProgressIndicator(color: AppColors.azulElectrico),
                )
              else if (_error != null) ...[
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent)),
              ] else if (_qr != null) ...[
                // ── QR en grande ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azulElectrico.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: _expirado ? 0.15 : 1,
                    child: QrImageView(
                      data: _qr!.urlVerificacion,
                      version: QrVersions.auto,
                      size: 280,
                      gapless: true,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Reloj regresivo / estado ─────────────────────────────
                if (_expirado) ...[
                  const Text(
                    'QR EXPIRADO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Genera uno nuevo para mostrarlo en farmacia.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: _segundosRestantes <= 60
                            ? Colors.redAccent
                            : AppColors.azulElectrico,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Válido por $_reloj',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _segundosRestantes <= 60
                              ? Colors.redAccent
                              : AppColors.azulElectrico,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'El código caduca a los 5 minutos por seguridad.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generar,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(_expirado || _error != null
                      ? 'Generar nuevo QR'
                      : 'Regenerar QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulElectrico,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
