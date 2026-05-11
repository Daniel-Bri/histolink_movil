import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import '../models/ficha_model.dart';
import '../services/triaje_service.dart';

// ── Tablas de niveles ─────────────────────────────────────────────────────────

const _kLevels = ['ROJO', 'NARANJA', 'AMARILLO', 'VERDE', 'AZUL'];

const _kLevelNum = <String, int>{
  'ROJO': 1, 'NARANJA': 2, 'AMARILLO': 3, 'VERDE': 4, 'AZUL': 5,
};

const _kLevelLabel = <String, String>{
  'ROJO':     'ROJO — Inmediato',
  'NARANJA':  'NARANJA — Muy urgente',
  'AMARILLO': 'AMARILLO — Urgente',
  'VERDE':    'VERDE — Poco urgente',
  'AZUL':     'AZUL — No urgente',
};

Color _nivelColor(String nivel) => switch (nivel.toUpperCase()) {
      'ROJO'     => const Color(0xFFDC2626),
      'NARANJA'  => const Color(0xFFEA580C),
      'AMARILLO' => const Color(0xFFD97706),
      'VERDE'    => const Color(0xFF16A34A),
      'AZUL'     => const Color(0xFF2563EB),
      _          => Colors.grey,
    };

IconData _nivelIcon(String nivel) => switch (nivel.toUpperCase()) {
      'ROJO'     => Icons.emergency_rounded,
      'NARANJA'  => Icons.warning_amber_rounded,
      'AMARILLO' => Icons.info_outline_rounded,
      'VERDE'    => Icons.check_circle_outline_rounded,
      'AZUL'     => Icons.circle_outlined,
      _          => Icons.help_outline_rounded,
    };

// ── Enum de vistas ────────────────────────────────────────────────────────────

enum _Paso { cola, formulario, guardadoOk }

// ── Screen ────────────────────────────────────────────────────────────────────

class RegistroDeTriajeScreen extends StatefulWidget {
  const RegistroDeTriajeScreen({super.key, required this.user, this.fichaInicial});

  final UserModel user;

  /// Ficha preseleccionada (desde otra pantalla).
  final FichaModel? fichaInicial;

  @override
  State<RegistroDeTriajeScreen> createState() => _RegistroDeTriajeScreenState();
}

class _RegistroDeTriajeScreenState extends State<RegistroDeTriajeScreen> {
  final _pacienteService = PacienteService();
  final _triajeService   = TriajeService();

  _Paso _paso = _Paso.cola;

  // ── Cola ──────────────────────────────────────────────────────────────────
  List<FichaModel> _fichasEnCola    = [];
  List<FichaModel> _fichasFiltradas = [];
  bool _cargandoCola = false;

  final _filtroCtrl = TextEditingController();
  Timer? _debounce;

  // ── Formulario ────────────────────────────────────────────────────────────
  FichaModel? _ficha;

  final _motivoCtrl        = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _pesoCtrl          = TextEditingController();
  final _tallaCtrl         = TextEditingController();
  final _fcCtrl            = TextEditingController();
  final _frCtrl            = TextEditingController();
  final _pasCtrl           = TextEditingController();
  final _padCtrl           = TextEditingController();
  final _tempCtrl          = TextEditingController();
  final _spo2Ctrl          = TextEditingController();
  final _glucemiaCtrl      = TextEditingController();
  final _dolorCtrl         = TextEditingController();
  final _glasgowCtrl       = TextEditingController();
  final _justificacionCtrl = TextEditingController();

  bool _clasificando = false;
  Map<String, dynamic>? _resultado;
  String? _nivelFinal;
  bool _override = false;

  bool _guardando = false;
  Map<String, dynamic>? _triajeGuardado;

  @override
  void initState() {
    super.initState();
    if (widget.fichaInicial != null) {
      _ficha = widget.fichaInicial;
      _paso  = _Paso.formulario;
    } else {
      _cargarCola();
    }
    _filtroCtrl.addListener(_onFiltroChanged);
  }

  @override
  void dispose() {
    _filtroCtrl.removeListener(_onFiltroChanged);
    _filtroCtrl.dispose();
    _debounce?.cancel();
    _motivoCtrl.dispose();
    _observacionesCtrl.dispose();
    _pesoCtrl.dispose();
    _tallaCtrl.dispose();
    _fcCtrl.dispose();
    _frCtrl.dispose();
    _pasCtrl.dispose();
    _padCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    _glucemiaCtrl.dispose();
    _dolorCtrl.dispose();
    _glasgowCtrl.dispose();
    _justificacionCtrl.dispose();
    super.dispose();
  }

  // ── Cola: carga y filtro ──────────────────────────────────────────────────

  Future<void> _cargarCola() async {
    setState(() => _cargandoCola = true);
    try {
      final fichas = await _triajeService.listarEnCola();
      if (!mounted) return;
      setState(() {
        _fichasEnCola = fichas;
        _aplicarFiltro();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoCola = false);
    }
  }

  void _onFiltroChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(_aplicarFiltro);
    });
  }

  void _aplicarFiltro() {
    final q = _filtroCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _fichasFiltradas = List.from(_fichasEnCola);
    } else {
      _fichasFiltradas = _fichasEnCola.where((f) =>
        f.paciente.nombreCompleto.toLowerCase().contains(q) ||
        f.paciente.ci.toLowerCase().contains(q) ||
        f.correlativo.toLowerCase().contains(q)
      ).toList();
    }
  }

  // ── Navegación ────────────────────────────────────────────────────────────

  void _irAFormulario(FichaModel f) {
    final controllers = [
      _motivoCtrl, _pesoCtrl, _tallaCtrl, _fcCtrl, _frCtrl,
      _pasCtrl, _padCtrl, _tempCtrl, _spo2Ctrl, _glucemiaCtrl,
      _dolorCtrl, _glasgowCtrl, _observacionesCtrl, _justificacionCtrl,
    ];
    setState(() {
      _ficha      = f;
      _paso       = _Paso.formulario;
      _resultado  = null;
      _nivelFinal = null;
      _override   = false;
      for (final c in controllers) c.clear();
    });
  }

  void _volverACola() {
    setState(() {
      _paso  = _Paso.cola;
      _ficha = null;
    });
    _cargarCola();
  }

  void _handleBack() {
    switch (_paso) {
      case _Paso.formulario:
        if (widget.fichaInicial != null) {
          Navigator.pop(context);
        } else {
          _volverACola();
        }
      case _Paso.guardadoOk:
        _volverACola();
      case _Paso.cola:
        Navigator.pop(context);
    }
  }

  String get _appBarTitle => switch (_paso) {
        _Paso.cola       => 'Urgencias',
        _Paso.formulario => 'Triaje',
        _Paso.guardadoOk => 'Triaje registrado',
      };

  bool get _canPopNormally => _paso == _Paso.cola;

  // ── Ver triaje existente ──────────────────────────────────────────────────

  void _verTriajeExistente(FichaModel f) {
    final nivel = f.nivelUrgencia ?? '';
    final color = nivel.isNotEmpty ? _nivelColor(nivel) : Colors.grey;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.assignment_turned_in_rounded, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text('Evaluación de triaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color))),
            ]),
            const SizedBox(height: 16),
            _InfoRow(label: 'Paciente', value: f.paciente.nombreCompleto),
            _InfoRow(label: 'CI',       value: f.paciente.ci),
            _InfoRow(label: 'Ficha',    value: f.correlativo),
            _InfoRow(label: 'Estado',   value: f.estadoLabel),
            if (nivel.isNotEmpty)
              _InfoRow(label: 'Nivel', value: _kLevelLabel[nivel] ?? nivel, valueColor: color),
            if (f.motivoConsulta != null && f.motivoConsulta!.isNotEmpty)
              _InfoRow(label: 'Motivo', value: f.motivoConsulta!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () { Navigator.pop(context); _irAFormulario(f); },
                style: FilledButton.styleFrom(backgroundColor: AppColors.azulElectrico),
                child: const Text('Registrar nuevo triaje'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Buscar paciente para crear ficha ──────────────────────────────────────

  void _abrirBuscarPaciente() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BuscarPacienteSheet(
        pacienteService: _pacienteService,
        triajeService:   _triajeService,
        onFichaCreada: (ficha) {
          Navigator.pop(ctx);
          _irAFormulario(ficha);
        },
      ),
    );
  }

  // ── Clasificar con IA ─────────────────────────────────────────────────────

  Future<void> _clasificar() async {
    FocusScope.of(context).unfocus();
    setState(() { _clasificando = true; _resultado = null; _nivelFinal = null; _override = false; });
    try {
      final r = await _triajeService.clasificar(
        motivoConsulta:    _motivoCtrl.text.trim(),
        saturacionOxigeno: int.tryParse(_spo2Ctrl.text.trim()),
        presionSistolica:  int.tryParse(_pasCtrl.text.trim()),
        frecuenciaCardiaca: int.tryParse(_fcCtrl.text.trim()),
        escalaDolor:       int.tryParse(_dolorCtrl.text.trim()),
        glasgow:           int.tryParse(_glasgowCtrl.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _resultado  = r;
        _nivelFinal = (r['nivel_sugerido'] as String?)?.toUpperCase() ?? 'AMARILLO';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _clasificando = false);
    }
  }

  // ── Guardar triaje ────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (_ficha == null || _nivelFinal == null) return;

    if (_override && _justificacionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la justificación para el cambio de nivel.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    try {
      final data = <String, dynamic>{
        'ficha':          _ficha!.id,
        'nivel_urgencia': _nivelFinal,
      };

      final sugerido = _resultado?['nivel_sugerido'];
      if (sugerido != null) {
        data['nivel_sugerido_ia'] = (sugerido as String).toUpperCase();
        data['fue_sobreescrito']  = _override;
        if (_override) data['justificacion_override'] = _justificacionCtrl.text.trim();
      }

      final motivo = _motivoCtrl.text.trim();
      if (motivo.isNotEmpty) data['motivo_consulta_triaje'] = motivo;

      final obs = _observacionesCtrl.text.trim();
      if (obs.isNotEmpty) data['observaciones'] = obs;

      void addInt(String key, String raw) {
        final v = int.tryParse(raw.trim());
        if (v != null) data[key] = v;
      }
      void addDbl(String key, String raw) {
        final v = double.tryParse(raw.trim());
        if (v != null) data[key] = v;
      }

      addDbl('peso_kg',               _pesoCtrl.text);
      addDbl('talla_cm',              _tallaCtrl.text);
      addInt('frecuencia_cardiaca',   _fcCtrl.text);
      addInt('frecuencia_respiratoria', _frCtrl.text);
      addInt('presion_sistolica',     _pasCtrl.text);
      addInt('presion_diastolica',    _padCtrl.text);
      addDbl('temperatura_celsius',   _tempCtrl.text);
      addInt('saturacion_oxigeno',    _spo2Ctrl.text);
      addDbl('glucemia',              _glucemiaCtrl.text);
      addInt('escala_dolor',          _dolorCtrl.text);
      addInt('glasgow',               _glasgowCtrl.text);

      final saved = await _triajeService.guardar(data);
      if (!mounted) return;
      setState(() { _triajeGuardado = saved; _paso = _Paso.guardadoOk; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPopNormally,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleBack(); },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        drawer: _paso == _Paso.cola
            ? AppDrawer(user: widget.user, activeLabel: 'Triaje')
            : null,
        appBar: AppBar(
          title: Text(_appBarTitle),
          backgroundColor: AppColors.azulElectrico,
          foregroundColor: Colors.white,
          leading: _paso == _Paso.cola
              ? null
              : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _handleBack),
          actions: [
            if (_paso == _Paso.cola)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: _cargandoCola ? null : _cargarCola,
              ),
          ],
        ),
        floatingActionButton: _paso == _Paso.cola
            ? FloatingActionButton.extended(
                onPressed: _abrirBuscarPaciente,
                backgroundColor: AppColors.mentaVibrante,
                icon: const Icon(Icons.person_search_rounded, color: Colors.white),
                label: const Text('Buscar paciente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )
            : null,
        body: switch (_paso) {
          _Paso.cola       => _buildCola(),
          _Paso.formulario => _buildFormulario(),
          _Paso.guardadoOk => _buildGuardadoOk(),
        },
      ),
    );
  }

  // ── Cola ─────────────────────────────────────────────────────────────────

  Widget _buildCola() {
    final pendientes  = _fichasEnCola.where((f) => f.estado == 'ABIERTA').length;
    final enEspera    = _fichasEnCola.where((f) => f.estado == 'EN_TRIAJE').length;

    return RefreshIndicator(
      onRefresh: _cargarCola,
      color: AppColors.azulElectrico,
      child: Column(
        children: [
          // Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _StatChip(label: 'Pendientes', count: pendientes, color: const Color(0xFF1D4ED8), bg: const Color(0xFFDBEAFE)),
                const SizedBox(width: 10),
                _StatChip(label: 'En espera médico', count: enEspera, color: const Color(0xFF15803D), bg: const Color(0xFFDCFCE7)),
                const SizedBox(width: 10),
                _StatChip(label: 'Total', count: _fichasEnCola.length, color: const Color(0xFF374151), bg: const Color(0xFFF1F5F9)),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _filtroCtrl,
              decoration: InputDecoration(
                hintText: 'Filtrar por paciente, CI o ficha…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                suffixIcon: _filtroCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () { _filtroCtrl.clear(); setState(_aplicarFiltro); },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Lista
          Expanded(
            child: _cargandoCola
                ? const Center(child: LoadingIndicator(message: 'Cargando urgencias…'))
                : _fichasEnCola.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.check_circle_outline_rounded, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No hay pacientes en cola', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Usa el botón "Buscar paciente" para crear\nuna ficha e iniciar el triaje.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                        ],
                      )
                    : _fichasFiltradas.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 60),
                              Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Sin resultados para "${_filtroCtrl.text}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _fichasFiltradas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _ColaFichaCard(
                              ficha: _fichasFiltradas[i],
                              onTriajear: () => _irAFormulario(_fichasFiltradas[i]),
                              onVerDetalle: () => _verTriajeExistente(_fichasFiltradas[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────

  Widget _buildFormulario() {
    final reglasActivas = _resultado?['reglas_duras_aplicadas'] == true;
    final nivelNum      = _nivelFinal != null ? (_kLevelNum[_nivelFinal] ?? 3) : 99;
    final aiSugerido    = (_resultado?['nivel_sugerido'] as String?)?.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info ficha
          if (_ficha != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.azulElectrico.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppColors.azulElectrico, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_ficha!.correlativo, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azulElectrico)),
                        Text('${_ficha!.estadoLabel} · ${_ficha!.paciente.nombreCompleto}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          _SectionHeader('Motivo de consulta'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _motivoCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(hintText: 'Describe los síntomas principales…', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Signos vitales'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _pesoCtrl,  label: 'Peso (kg)',  hint: '70.5', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _tallaCtrl, label: 'Talla (cm)', hint: '165',  decimal: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _fcCtrl, label: 'FC (lpm)',  hint: '80')),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _frCtrl, label: 'FR (rpm)',  hint: '16')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _pasCtrl, label: 'PAS (mmHg)', hint: '120')),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _padCtrl, label: 'PAD (mmHg)', hint: '80')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _tempCtrl,  label: 'Temp (°C)', hint: '36.5', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _spo2Ctrl,  label: 'SpO₂ (%)', hint: '98')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _glucemiaCtrl, label: 'Glucemia (mg/dL)', hint: '90', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _dolorCtrl, label: 'Dolor EVA 0–10', hint: '0')),
          ]),
          const SizedBox(height: 10),
          _VitalField(ctrl: _glasgowCtrl, label: 'Glasgow (3–15)', hint: '15'),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _clasificando ? null : _clasificar,
              icon: _clasificando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.psychology_outlined),
              label: Text(_clasificando ? 'Clasificando…' : 'Clasificar con IA',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_resultado != null) ...[
            const SizedBox(height: 20),
            _ResultadoCard(
              nivel: _nivelFinal!,
              confianza: _resultado?['confianza_pct']?.toString(),
              mlDegradado: _resultado?['ml_degradado'] == true,
              reglasActivas: reglasActivas,
            ),
            const SizedBox(height: 18),

            _SectionHeader('Nivel de urgencia final'),
            const SizedBox(height: 6),
            Text(
              'El nivel sugerido por la IA es el preseleccionado. Toca otro solo si necesitas modificarlo.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (reglasActivas) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reglas clínicas duras activas. No se puede asignar un nivel menos urgente al sugerido.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kLevels.map((nivel) {
                final num      = _kLevelNum[nivel] ?? 3;
                final disabled = reglasActivas && num > nivelNum;
                final selected = nivel == _nivelFinal;
                return _NivelChip(
                  nivel: nivel, selected: selected, disabled: disabled,
                  onTap: disabled ? null : () => setState(() {
                    _nivelFinal = nivel;
                    _override   = nivel != aiSugerido;
                    if (!_override) _justificacionCtrl.clear();
                  }),
                );
              }).toList(),
            ),

            if (_override) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _justificacionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificación del cambio *',
                  hintText: 'Explica por qué se modifica el nivel sugerido por la IA…',
                  alignLabelWithHint: true,
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextFormField(
              controller: _observacionesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                hintText: 'Información adicional relevante…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt_rounded),
                label: Text(_guardando ? 'Guardando…' : 'Guardar triaje',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mentaVibrante,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // ── Guardado OK ───────────────────────────────────────────────────────────

  Widget _buildGuardadoOk() {
    final nivel          = (_triajeGuardado?['nivel_urgencia'] as String?)?.toUpperCase() ?? _nivelFinal ?? 'AMARILLO';
    final color          = _nivelColor(nivel);
    final label          = _kLevelLabel[nivel] ?? nivel;
    final fueOverride    = _triajeGuardado?['fue_sobreescrito'] == true;
    final reglasActivas  = _triajeGuardado?['reglas_duras_aplicadas'] == true;
    final correlativo    = _ficha?.correlativo ?? '';
    final pacienteNombre = _ficha?.paciente.nombreCompleto ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(_nivelIcon(nivel), color: color, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Triaje registrado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (pacienteNombre.isNotEmpty) Text(pacienteNombre, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            if (correlativo.isNotEmpty) Text(correlativo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (fueOverride || reglasActivas) ...[
              const SizedBox(height: 12),
              if (fueOverride)
                _InfoTag(icon: Icons.edit_outlined, text: 'Nivel modificado por enfermería', color: Colors.orange.shade700),
              if (reglasActivas)
                _InfoTag(icon: Icons.warning_rounded, text: 'Reglas clínicas duras aplicadas', color: const Color(0xFFDC2626)),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _volverACola,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Volver a la cola', style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.azulElectrico,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet: buscar paciente y crear ficha ───────────────────────────────

class _BuscarPacienteSheet extends StatefulWidget {
  const _BuscarPacienteSheet({
    required this.pacienteService,
    required this.triajeService,
    required this.onFichaCreada,
  });

  final PacienteService pacienteService;
  final TriajeService   triajeService;
  final void Function(FichaModel) onFichaCreada;

  @override
  State<_BuscarPacienteSheet> createState() => _BuscarPacienteSheetState();
}

class _BuscarPacienteSheetState extends State<_BuscarPacienteSheet> {
  final _ctrl      = TextEditingController();
  Timer? _debounce;

  List<PacienteModel> _resultados = [];
  bool _buscando  = false;
  int? _creandoId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    if (_ctrl.text.trim().length < 2) {
      setState(() { _resultados = []; _error = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _buscar);
  }

  Future<void> _buscar() async {
    setState(() { _buscando = true; _error = null; });
    try {
      final list = await widget.pacienteService.listar(search: _ctrl.text.trim());
      if (!mounted) return;
      setState(() {
        _resultados = list;
        if (list.isEmpty) _error = 'Sin resultados';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _crearFichaEIrATriaje(PacienteModel p) async {
    setState(() => _creandoId = p.id);
    try {
      final ficha = await widget.triajeService.crearFicha(p.id);
      if (!mounted) return;
      widget.onFichaCreada(ficha);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _creandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, color: AppColors.azulElectrico, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buscar paciente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azulElectrico)),
                      Text('Escribe CI o nombre — se crea ficha y se inicia triaje', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'CI o nombre / apellido…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                suffixIcon: _buscando
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_error!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),

          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _resultados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = _resultados[i];
                final creando = _creandoId == p.id;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.azulCielo,
                      child: Text(
                        p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.azulElectrico, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(p.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('CI: ${p.ciCompleto}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    trailing: creando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : FilledButton(
                            onPressed: () => _crearFichaEIrATriaje(p),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.mentaVibrante,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Abrir →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de la cola ────────────────────────────────────────────────────────

class _ColaFichaCard extends StatelessWidget {
  const _ColaFichaCard({
    required this.ficha,
    required this.onTriajear,
    required this.onVerDetalle,
  });

  final FichaModel ficha;
  final VoidCallback onTriajear;
  final VoidCallback onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final esPendiente = ficha.estado == 'ABIERTA';
    final nivel  = ficha.nivelUrgencia ?? '';
    final color  = nivel.isNotEmpty ? _nivelColor(nivel) : const Color(0xFF1D4ED8);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: esPendiente ? const Color(0xFFBFDBFE) : Colors.grey.shade200),
      ),
      elevation: esPendiente ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Correlativo
                Text(ficha.correlativo,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.azulElectrico)),
                const Spacer(),
                // Badge estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: esPendiente ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ficha.estadoLabel,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: esPendiente ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                    ),
                  ),
                ),
                // Badge nivel urgencia (si tiene triaje)
                if (!esPendiente && nivel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                    child: Text(nivel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(ficha.paciente.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
            Text('CI: ${ficha.paciente.ci}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: esPendiente
                      ? FilledButton.icon(
                          onPressed: onTriajear,
                          icon: const Icon(Icons.monitor_heart_rounded, size: 18),
                          label: const Text('Realizar triaje →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.azulElectrico,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onVerDetalle,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Ver evaluación', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.azulElectrico),
                            foregroundColor: AppColors.azulElectrico,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.count, required this.color, required this.bg});
  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azulElectrico),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
            Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? Colors.grey.shade900)),
            ),
          ],
        ),
      );
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _VitalField extends StatelessWidget {
  const _VitalField({required this.ctrl, required this.label, required this.hint, this.decimal = false});
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool decimal;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          if (decimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}

class _NivelChip extends StatelessWidget {
  const _NivelChip({required this.nivel, required this.selected, required this.disabled, this.onTap});
  final String nivel;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = _nivelColor(nivel);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : (disabled ? Colors.grey.shade100 : color.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: disabled ? Colors.grey.shade300 : color, width: selected ? 0 : 1.5),
        ),
        child: Text(
          nivel,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : (disabled ? Colors.grey.shade400 : color),
          ),
        ),
      ),
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  const _ResultadoCard({required this.nivel, this.confianza, required this.mlDegradado, required this.reglasActivas});
  final String nivel;
  final String? confianza;
  final bool mlDegradado;
  final bool reglasActivas;

  @override
  Widget build(BuildContext context) {
    final color = _nivelColor(nivel);
    final label = _kLevelLabel[nivel] ?? nivel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(_nivelIcon(nivel), color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clasificación IA', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                if (confianza != null)
                  Text('Confianza: $confianza%', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
                if (mlDegradado)
                  Text('Modo degradado (sin modelo)', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                if (reglasActivas)
                  Text('⚠ Reglas clínicas aplicadas', style: TextStyle(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
