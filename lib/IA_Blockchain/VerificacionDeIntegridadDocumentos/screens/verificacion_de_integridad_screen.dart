import 'package:flutter/material.dart';
import 'package:histolink/IA_Blockchain/VerificacionDeIntegridadDocumentos/services/verificacion_service.dart';
import 'package:histolink/shared/theme/app_colors.dart';

class VerificacionDeIntegridadScreen extends StatefulWidget {
  const VerificacionDeIntegridadScreen({
    super.key,
    required this.consultaId,
    this.tituloConsulta,
  });

  final int consultaId;
  final String? tituloConsulta;

  @override
  State<VerificacionDeIntegridadScreen> createState() =>
      _VerificacionDeIntegridadScreenState();
}

class _VerificacionDeIntegridadScreenState
    extends State<VerificacionDeIntegridadScreen>
    with SingleTickerProviderStateMixin {
  final _service = VerificacionService();

  bool _loading = true;
  String? _error;
  VerificacionResult? _result;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _verificar();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    setState(() { _loading = true; _error = null; _result = null; });
    _animCtrl.reset();
    try {
      final result = await _service.verificarDocumento(widget.consultaId);
      if (!mounted) return;
      setState(() { _result = result; _loading = false; });
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: Text(widget.tituloConsulta ?? 'Verificar Integridad'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.azulPuro,
        onRefresh: _verificar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
          children: [
            if (_loading) _LoadingView(),
            if (!_loading && _error != null) _ErrorView(error: _error!),
            if (!_loading && _error == null && _result != null)
              _ResultView(result: _result!, scaleAnim: _scaleAnim),
          ],
        ),
      ),
    );
  }
}

// ── Cargando ──────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 60),
      const CircularProgressIndicator(color: AppColors.azulElectrico, strokeWidth: 3),
      const SizedBox(height: 24),
      Text(
        'Contrastando con la Blockchain…',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: Colors.grey[600], fontStyle: FontStyle.italic),
      ),
    ]);
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(error, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14))),
      ]),
    );
  }
}

// ── Resultado ─────────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.scaleAnim});
  final VerificacionResult result;
  final Animation<double> scaleAnim;

  @override
  Widget build(BuildContext context) {
    if (result.sinFirma) return const _SinFirmaView();

    final esValido = result.esValido;
    final color     = esValido ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final colorBg   = esValido ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5);
    final colorBord = esValido ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final icon      = esValido ? Icons.verified_rounded : Icons.gpp_bad_rounded;
    final titulo    = esValido
        ? 'Documento Original Verificado'
        : 'Documento Alterado';
    final subtitulo = esValido
        ? 'La historia clínica no ha sido modificada desde su firma.'
        : 'Se detectó un cambio en el documento. El contenido no coincide con el registro en blockchain.';

    return Column(children: [
      // Ícono animado
      ScaleTransition(
        scale: scaleAnim,
        child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: colorBg, shape: BoxShape.circle, border: Border.all(color: colorBord, width: 2)),
          child: Icon(icon, size: 64, color: color),
        ),
      ),
      const SizedBox(height: 24),

      // Título de estado
      Text(titulo,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 10),
      Text(subtitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
      const SizedBox(height: 32),

      // Tarjeta de detalles
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETALLES DE FIRMA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8)),
          const SizedBox(height: 14),
          if (result.firmadoPor != null)
            _DetalleFila(icon: Icons.person_outline_rounded, label: 'Firmado por', value: result.firmadoPor!),
          if (result.firmadoEn != null)
            _DetalleFila(icon: Icons.schedule_rounded, label: 'Fecha de firma', value: _formatFecha(result.firmadoEn!)),
          if (result.didFirmante != null)
            _DetalleFila(icon: Icons.fingerprint_rounded, label: 'DID', value: result.didFirmante!, mono: true),
          if (result.bloqueNumero != null)
            _DetalleFila(icon: Icons.link_rounded, label: 'Bloque #', value: result.bloqueNumero.toString()),
          if (!esValido) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La lectura de este documento ha sido bloqueada por integridad comprometida.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }

  String _formatFecha(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SinFirmaView extends StatelessWidget {
  const _SinFirmaView();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 60),
      Icon(Icons.lock_open_rounded, size: 72, color: Colors.grey[400]),
      const SizedBox(height: 20),
      const Text('Sin Firma Digital',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
      const SizedBox(height: 8),
      const Text(
        'Este documento aún no ha sido firmado digitalmente.\nNo se puede verificar su integridad.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), height: 1.5),
      ),
    ]);
  }
}

class _DetalleFila extends StatelessWidget {
  const _DetalleFila({required this.icon, required this.label, required this.value, this.mono = false});
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF1A1A2E),
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
