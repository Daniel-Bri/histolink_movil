import 'dart:async';
import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import 'package:histolink/IA_Blockchain/PrediccionDeRiesgosClinicos/services/riesgo_service.dart';
import 'package:histolink/IA_Blockchain/PrediccionDeRiesgosClinicos/widgets/riesgo_clinico_widget.dart';

class PrediccionDeRiesgosClinicosScreen extends StatefulWidget {
  const PrediccionDeRiesgosClinicosScreen({super.key, this.pacienteId});

  /// ID del paciente pre-seleccionado (navegación desde detalle del paciente).
  /// Si es null, el médico usa el buscador interactivo.
  final int? pacienteId;

  @override
  State<PrediccionDeRiesgosClinicosScreen> createState() =>
      _PrediccionDeRiesgosClinicosScreenState();
}

class _PrediccionDeRiesgosClinicosScreenState
    extends State<PrediccionDeRiesgosClinicosScreen> {
  // ── Servicios ──────────────────────────────────────────────────────────────
  final _riesgoService   = RiesgoService();
  final _pacienteService = PacienteService();

  // ── Buscador interactivo ───────────────────────────────────────────────────
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  List<PacienteModel> _sugerencias        = [];
  PacienteModel?      _pacienteSeleccionado;
  bool                _buscando           = false;

  // ── Análisis de riesgo ─────────────────────────────────────────────────────
  int?                  _pacienteId;
  bool                  _cargando = false;
  String?               _error;
  Map<String, dynamic>? _data;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.pacienteId != null) {
      // Precarga: recupera el nombre para el campo y lanza el análisis.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _cargarPacienteInicial(widget.pacienteId!),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  // ── Precarga (vía navegación desde detalle del paciente) ───────────────────

  Future<void> _cargarPacienteInicial(int id) async {
    setState(() => _buscando = true);
    try {
      final p = await _pacienteService.obtener(id);
      if (!mounted) return;
      // Llena el campo con el nombre y dispara el análisis directamente.
      _seleccionar(p);
    } on PacienteApiException catch (_) {
      if (!mounted) return;
      // Si falla la resolución del nombre (raro), analiza de todas formas.
      setState(() { _pacienteId = id; _buscando = false; });
      _fetchRiesgo();
    }
  }

  // ── Búsqueda en vivo ───────────────────────────────────────────────────────

  void _onBusquedaChanged(String valor) {
    // Al editar el campo se descarta la selección anterior.
    _pacienteSeleccionado = null;

    _debounce?.cancel();

    if (valor.trim().isEmpty) {
      setState(() { _sugerencias = []; _buscando = false; });
      return;
    }

    setState(() => _buscando = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _buscarPacientes(valor.trim()),
    );
  }

  Future<void> _buscarPacientes(String query) async {
    try {
      final lista = await _pacienteService.listar(search: query);
      if (!mounted) return;
      setState(() { _sugerencias = lista; _buscando = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  // ── Selección de un paciente de las sugerencias ────────────────────────────

  /// Llena el campo de búsqueda, fija el ID en el estado y lanza el análisis.
  void _seleccionar(PacienteModel p) {
    setState(() {
      _pacienteSeleccionado = p;
      _pacienteId           = p.id;
      _sugerencias          = [];
      _buscando             = false;
      _busquedaCtrl.text    = '${p.nombreCompleto}  •  CI: ${p.ciCompleto}';
    });
    _fetchRiesgo();
  }

  // ── Llamada al endpoint de IA ──────────────────────────────────────────────

  Future<void> _fetchRiesgo() async {
    final id = _pacienteId;
    if (id == null) return;

    setState(() { _cargando = true; _error = null; _data = null; });

    try {
      final data = await _riesgoService.obtenerRiesgo(id);
      if (!mounted) return;
      setState(() { _data = data; _cargando = false; });
    } on RiesgoApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Alertas de Riesgo Clínico'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const LoadingIndicator(message: 'Calculando riesgo con IA…')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildBannerIA(),
                const SizedBox(height: 20),
                _buildBuscador(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorBanner(),
                ],
                if (_data != null) ...[
                  const SizedBox(height: 20),
                  _buildResultadosHeader(),
                  const SizedBox(height: 12),
                  RiesgoClinicoWidget(data: _data!),
                  const SizedBox(height: 20),
                  const _LeyendaColores(),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  // ── Secciones del cuerpo ───────────────────────────────────────────────────

  Widget _buildBannerIA() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.azulElectrico, Color(0xFF5C35CC)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: const [
          Icon(Icons.psychology_rounded, color: Colors.white, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Predicción de Riesgos Clínicos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Modelo de IA para detección temprana de patologías',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscador() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscar paciente',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Escriba el nombre completo o el CI',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),

          // ── Campo de búsqueda ──────────────────────────────────────────
          TextField(
            controller: _busquedaCtrl,
            onChanged: _onBusquedaChanged,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ej: Juan Pérez  o  1234567',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _pacienteSeleccionado != null
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),

          // ── Dropdown de sugerencias ────────────────────────────────────
          if (_sugerencias.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final p = _sugerencias[i];
                  final inicial = p.nombreCompleto.isNotEmpty
                      ? p.nombreCompleto[0].toUpperCase()
                      : '?';
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.azulElectrico,
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      p.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'CI: ${p.ciCompleto}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () => _seleccionar(p),
                  );
                },
              ),
            ),

          // ── Estado vacío tras búsqueda sin resultados ──────────────────
          if (!_buscando &&
              _sugerencias.isEmpty &&
              _pacienteSeleccionado == null &&
              _busquedaCtrl.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Sin coincidencias. Intente con otro término.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.alerta,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _fetchRiesgo,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.azulElectrico,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildResultadosHeader() {
    final nombreLabel = _pacienteSeleccionado?.nombreCompleto ?? 'Paciente #$_pacienteId';

    return Row(
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Resultados del análisis',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        Flexible(
          child: Text(
            nombreLabel,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ── Leyenda de colores semánticos ──────────────────────────────────────────

class _LeyendaItem {
  const _LeyendaItem({required this.color, required this.label});
  final Color  color;
  final String label;
}

class _LeyendaColores extends StatelessWidget {
  const _LeyendaColores();

  static const _items = [
    _LeyendaItem(color: Colors.purple, label: 'Crítico'),
    _LeyendaItem(color: Colors.red,    label: 'Alto'),
    _LeyendaItem(color: Colors.orange, label: 'Moderado'),
    _LeyendaItem(color: Colors.green,  label: 'Bajo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leyenda de niveles de alerta',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _items
                .map(
                  (e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(e.label,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
