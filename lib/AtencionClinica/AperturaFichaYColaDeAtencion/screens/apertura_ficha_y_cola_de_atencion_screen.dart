import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/AtencionClinica/RegistroDeTriaje/models/ficha_model.dart';
import 'package:histolink/AtencionClinica/RegistroDeTriaje/services/triaje_service.dart';
import 'package:histolink/AtencionClinica/RegistroDeTriaje/screens/registro_de_triaje_screen.dart';

Color _estadoColor(FichaModel f) {
  if (f.tieneTriage) return const Color(0xFF16A34A);
  return switch (f.estado.toUpperCase()) {
    'ABIERTA'      => AppColors.azulElectrico,
    'EN_TRIAJE'    => const Color(0xFFD97706),
    'EN_ATENCION'  => const Color(0xFF6D28D9),
    _              => Colors.grey,
  };
}

String _tiempoTranscurrido(String fechaIso) {
  if (fechaIso.isEmpty) return '';
  try {
    final dt  = DateTime.parse(fechaIso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  } catch (_) {
    return '';
  }
}

class AperturaFichaYColaDeAtencionScreen extends StatefulWidget {
  const AperturaFichaYColaDeAtencionScreen({super.key});

  @override
  State<AperturaFichaYColaDeAtencionScreen> createState() =>
      _AperturaFichaYColaDeAtencionScreenState();
}

class _AperturaFichaYColaDeAtencionScreenState
    extends State<AperturaFichaYColaDeAtencionScreen> {
  final _service = TriajeService();

  List<FichaModel> _fichas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error    = null;
    });
    try {
      final lista = await _service.listarEnCola();
      if (!mounted) return;
      setState(() => _fichas = lista);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirTriaje(FichaModel ficha) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroDeTriajeScreen(fichaInicial: ficha),
      ),
    );
    if (result == true) _cargar();
  }

  Future<void> _nuevoTriaje() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegistroDeTriajeScreen()),
    );
    if (result == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Cola de atención'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoTriaje,
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo triaje', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando cola de atención…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'No se pudo cargar la cola',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.azulElectrico),
              ),
            ],
          ),
        ),
      );
    }

    if (_fichas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.inbox_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Cola vacía',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'No hay fichas en curso.\nUsa el botón + para registrar un triaje.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      );
    }

    final pendientes = _fichas.where((f) => !f.tieneTriage).toList();
    final triajados  = _fichas.where((f) => f.tieneTriage).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── Resumen ──────────────────────────────────────────────────────
          _ResumenBanner(total: _fichas.length, pendientes: pendientes.length),
          const SizedBox(height: 16),

          // ── Pendientes de triaje ──────────────────────────────────────────
          if (pendientes.isNotEmpty) ...[
            _SeccionHeader(
              label: 'Pendientes de triaje',
              count: pendientes.length,
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(height: 8),
            ...pendientes.map(
              (f) => _FichaQueueCard(
                ficha: f,
                onTap: () => _abrirTriaje(f),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Ya triajados ─────────────────────────────────────────────────
          if (triajados.isNotEmpty) ...[
            _SeccionHeader(
              label: 'Triaje completado',
              count: triajados.length,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 8),
            ...triajados.map(
              (f) => _FichaQueueCard(ficha: f, onTap: null),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _ResumenBanner extends StatelessWidget {
  const _ResumenBanner({required this.total, required this.pendientes});

  final int total;
  final int pendientes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.list_alt_rounded,
            label: 'Total',
            value: '$total',
            color: AppColors.azulElectrico,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.pending_actions_rounded,
            label: 'Pendientes',
            value: '$pendientes',
            color: pendientes > 0 ? const Color(0xFFDC2626) : Colors.grey,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.check_circle_outline_rounded,
            label: 'Triajados',
            value: '${total - pendientes}',
            color: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      );
}

class _SeccionHeader extends StatelessWidget {
  const _SeccionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      );
}

class _FichaQueueCard extends StatelessWidget {
  const _FichaQueueCard({required this.ficha, this.onTap});

  final FichaModel ficha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color    = _estadoColor(ficha);
    final tiempo   = _tiempoTranscurrido(ficha.fechaApertura);
    final disabled = onTap == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: disabled ? 0 : 1,
      color: disabled ? Colors.grey.shade50 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Indicador de color ────────────────────────────────────────
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // ── Contenido ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ficha.paciente.nombreCompleto.isEmpty
                                ? 'Paciente #${ficha.paciente.id}'
                                : ficha.paciente.nombreCompleto,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: disabled ? Colors.grey.shade500 : Colors.black87,
                            ),
                          ),
                        ),
                        if (tiempo.isNotEmpty)
                          Text(
                            tiempo,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          ficha.correlativo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: disabled ? Colors.grey.shade400 : color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ficha.estadoLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ficha.paciente.ci.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'CI: ${ficha.paciente.ci}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Acción ────────────────────────────────────────────────────
              const SizedBox(width: 8),
              if (ficha.tieneTriage)
                Icon(Icons.check_circle_rounded, color: const Color(0xFF16A34A), size: 24)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.azulElectrico,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Triaje',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
