import 'dart:async';
import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import '../../RegistroDeTriaje/models/ficha_model.dart';
import '../services/ficha_service.dart';

class AperturaFichaYColaDeAtencionScreen extends StatefulWidget {
  final UserModel user;
  const AperturaFichaYColaDeAtencionScreen({super.key, required this.user});

  @override
  State<AperturaFichaYColaDeAtencionScreen> createState() =>
      _AperturaFichaYColaDeAtencionScreenState();
}

class _AperturaFichaYColaDeAtencionScreenState
    extends State<AperturaFichaYColaDeAtencionScreen> {
  final _service = FichaService();
  List<FichaModel> _fichas = [];
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchFichas();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchFichas(silently: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFichas({bool silently = false}) async {
    if (!silently) setState(() => _loading = true);
    try {
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final list = await _service.listarFichasDelDia(dateStr);
      if (mounted) {
        setState(() {
          _fichas = list;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silently) _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchFichas();
    }
  }

  Future<void> _abrirCrearFicha() async {
    final creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CrearFichaSheet(service: _service),
    );
    if (creada == true) _fetchFichas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: widget.user, activeLabel: 'Fichas del Día'),
      appBar: AppBar(
        title: const Text(
          'Fichas del día',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchFichas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearFicha,
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Ficha', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: _loading && _fichas.isEmpty
                ? const LoadingIndicator(message: 'Cargando fichas...')
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchFichas(silently: true),
                        child: _fichas.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _fichas.length,
                                itemBuilder: (context, index) =>
                                    _FichaCard(ficha: _fichas[index]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.azulElectrico,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.azulCielo,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_fichas.length} total',
              style: const TextStyle(
                color: AppColors.azulElectrico,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.assignment_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No hay fichas para este día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _FichaCard extends StatelessWidget {
  final FichaModel ficha;
  const _FichaCard({required this.ficha});

  Color _getUrgenciaColor(String? nivel) {
    switch (nivel?.toUpperCase()) {
      case 'ROJO':
        return const Color(0xFFEF4444);
      case 'NARANJA':
        return const Color(0xFFF97316);
      case 'AMARILLO':
        return const Color(0xFFF59E0B);
      case 'VERDE':
        return const Color(0xFF10B981);
      case 'AZUL':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey.shade400;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return const Color(0xFFF59E0B);
      case 'EN_ATENCION':
        return const Color(0xFF3B82F6);
      case 'EN_TRIAJE':
        return const Color(0xFF06B6D4);
      case 'FINALIZADO':
        return const Color(0xFF10B981);
      case 'CANCELADO':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = ficha.paciente.nombreCompleto.isNotEmpty
        ? ficha.paciente.nombreCompleto
            .split(' ')
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    final urgColor = _getUrgenciaColor(ficha.nivelUrgencia);

    final apertura = DateTime.tryParse(ficha.fechaApertura);
    int waitMin = 0;
    if (apertura != null) {
      waitMin = DateTime.now().difference(apertura.toLocal()).inMinutes;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: urgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(ficha.estado).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ficha.estadoLabel,
                            style: TextStyle(
                              color: _getEstadoColor(ficha.estado),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'Ficha #${ficha.correlativo}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.azulElectrico,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ficha.paciente.nombreCompleto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'CI: ${ficha.paciente.ci}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadge(Icons.access_time, _formatTime(apertura)),
                        _buildBadge(
                          Icons.timer_outlined,
                          '$waitMin min',
                          color: AppColors.azulElectrico,
                        ),
                        if (ficha.nivelUrgencia != null)
                          _buildBadge(
                            Icons.emergency_outlined,
                            ficha.nivelUrgencia!,
                            color: urgColor,
                          ),
                      ],
                    ),
                    if (ficha.motivoConsulta != null &&
                        ficha.motivoConsulta!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '"${ficha.motivoConsulta}"',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, {Color color = Colors.grey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }
}

// ── Bottom sheet: Crear nueva ficha ──────────────────────────────────────────
class _CrearFichaSheet extends StatefulWidget {
  final FichaService service;
  const _CrearFichaSheet({required this.service});

  @override
  State<_CrearFichaSheet> createState() => _CrearFichaSheetState();
}

class _CrearFichaSheetState extends State<_CrearFichaSheet> {
  final _pacienteService = PacienteService();
  final _busquedaCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  Timer? _debounce;

  List<PacienteModel> _resultados = [];
  PacienteModel? _pacienteSeleccionado;
  bool _buscando = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _onBusquedaChanged(String valor) {
    _debounce?.cancel();
    if (valor.trim().isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(valor));
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    try {
      final lista = await _pacienteService.listar(search: query);
      if (mounted) setState(() { _resultados = lista; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _seleccionar(PacienteModel p) {
    setState(() {
      _pacienteSeleccionado = p;
      _resultados = [];
      _busquedaCtrl.text = '${p.nombreCompleto} — CI: ${p.ci}';
    });
  }

  Future<void> _crear() async {
    if (_pacienteSeleccionado == null) {
      setState(() => _error = 'Selecciona un paciente');
      return;
    }
    setState(() { _guardando = true; _error = null; });
    try {
      await widget.service.crearFicha(
        pacienteId: _pacienteSeleccionado!.id,
        motivoConsulta: _motivoCtrl.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FichaApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _guardando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _guardando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nueva Ficha de Atención',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Búsqueda de paciente
            const Text('Paciente *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _busquedaCtrl,
              onChanged: (v) {
                _pacienteSeleccionado = null;
                _onBusquedaChanged(v);
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o CI...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),

            // Lista de resultados
            if (_resultados.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _resultados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _resultados[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.azulElectrico,
                        child: Text(
                          p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(p.nombreCompleto,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('CI: ${p.ci}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      onTap: () => _seleccionar(p),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Motivo consulta
            const Text('Motivo de consulta',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe brevemente el motivo de la visita...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _crear,
                icon: _guardando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_guardando ? 'Creando...' : 'Crear Ficha',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulElectrico,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
