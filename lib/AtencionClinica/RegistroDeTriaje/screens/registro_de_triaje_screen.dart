import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import 'package:histolink/AtencionClinica/AperturaFichaYColaDeAtencion/services/ficha_service.dart';
import '../models/ficha_model.dart';
import '../services/triaje_service.dart';

// ── Constantes de nivel ───────────────────────────────────────────────────────

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

// ── Paso ──────────────────────────────────────────────────────────────────────

enum _Paso { cola, formulario, guardadoOk }

// ── Screen ────────────────────────────────────────────────────────────────────

class RegistroDeTriajeScreen extends StatefulWidget {
  const RegistroDeTriajeScreen({super.key, required this.user, this.fichaInicial});

  final UserModel user;
  final FichaModel? fichaInicial;

  @override
  State<RegistroDeTriajeScreen> createState() => _RegistroDeTriajeScreenState();
}

class _RegistroDeTriajeScreenState extends State<RegistroDeTriajeScreen> {
  final _fichaService  = FichaService();
  final _triajeService = TriajeService();

  _Paso _paso = _Paso.cola;

  // ── Cola ──────────────────────────────────────────────────────────────────
  List<FichaModel> _cola         = [];
  bool _cargandoCola             = false;
  final _filtroCtrl              = TextEditingController();
  Timer? _filtroTimer;
  String _filtroQuery            = '';

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
    _filtroCtrl.addListener(_onFiltroChangedListener);
  }

  @override
  void dispose() {
    _filtroCtrl.removeListener(_onFiltroChangedListener);
    _filtroCtrl.dispose();
    _filtroTimer?.cancel();
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

  // ── Cola ──────────────────────────────────────────────────────────────────

  Future<void> _cargarCola() async {
    setState(() => _cargandoCola = true);
    try {
      final today = DateTime.now();
      final fecha = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lista = await _fichaService.listarFichasDelDia(fecha);
      if (mounted) setState(() => _cola = lista);
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

  List<FichaModel> get _colaFiltrada {
    if (_filtroQuery.isEmpty) return _cola;
    final q = _filtroQuery.toLowerCase();
    return _cola.where((f) =>
      f.paciente.nombreCompleto.toLowerCase().contains(q) ||
      f.paciente.ci.toLowerCase().contains(q) ||
      f.correlativo.toLowerCase().contains(q)
    ).toList();
  }

  void _onFiltroChangedListener() => _onFiltroChanged(_filtroCtrl.text);

  void _onFiltroChanged(String val) {
    _filtroTimer?.cancel();
    _filtroTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _filtroQuery = val.trim());
    });
  }

  void _irAFormulario(FichaModel f) {
    final ctrls = [
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
      for (final c in ctrls) c.clear();
    });
  }

  void _volverACola() {
    setState(() {
      _paso           = _Paso.cola;
      _ficha          = null;
      _resultado      = null;
      _nivelFinal     = null;
      _triajeGuardado = null;
    });
    _cargarCola();
  }

  // ── Clasificar / Guardar ──────────────────────────────────────────────────

  Future<void> _clasificar() async {
    FocusScope.of(context).unfocus();
    setState(() { _clasificando = true; _resultado = null; _nivelFinal = null; _override = false; });
    try {
      final r = await _triajeService.clasificar(
        motivoConsulta:     _motivoCtrl.text.trim(),
        saturacionOxigeno:  int.tryParse(_spo2Ctrl.text.trim()),
        presionSistolica:   int.tryParse(_pasCtrl.text.trim()),
        frecuenciaCardiaca: int.tryParse(_fcCtrl.text.trim()),
        escalaDolor:        int.tryParse(_dolorCtrl.text.trim()),
        glasgow:            int.tryParse(_glasgowCtrl.text.trim()),
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

  Future<void> _guardar() async {
    if (_ficha == null || _nivelFinal == null) return;
    if (_override && _justificacionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la justificación para el cambio de nivel.'), backgroundColor: Color(0xFFD97706)),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final data = <String, dynamic>{'ficha': _ficha!.id, 'nivel_urgencia': _nivelFinal};
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

      void addInt(String k, String raw) { final v = int.tryParse(raw.trim()); if (v != null) data[k] = v; }
      void addDbl(String k, String raw) { final v = double.tryParse(raw.trim()); if (v != null) data[k] = v; }

      addDbl('peso_kg',                _pesoCtrl.text);
      addDbl('talla_cm',               _tallaCtrl.text);
      addInt('frecuencia_cardiaca',    _fcCtrl.text);
      addInt('frecuencia_respiratoria', _frCtrl.text);
      addInt('presion_sistolica',      _pasCtrl.text);
      addInt('presion_diastolica',     _padCtrl.text);
      addDbl('temperatura_celsius',    _tempCtrl.text);
      addInt('saturacion_oxigeno',     _spo2Ctrl.text);
      addDbl('glucemia',               _glucemiaCtrl.text);
      addInt('escala_dolor',           _dolorCtrl.text);
      addInt('glasgow',                _glasgowCtrl.text);

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
    final isFormulario = _paso == _Paso.formulario;
    final isGuardado   = _paso == _Paso.guardadoOk;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: _paso == _Paso.cola ? AppDrawer(user: widget.user, activeLabel: 'Triaje') : null,
      appBar: AppBar(
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        title: Text(switch (_paso) {
          _Paso.cola       => 'Cola de Triaje',
          _Paso.formulario => _ficha?.correlativo ?? 'Triaje',
          _Paso.guardadoOk => 'Triaje registrado',
        }),
        leading: isFormulario || isGuardado
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: isGuardado ? _volverACola : () {
                  setState(() {
                    _paso = _Paso.cola;
                    _resultado  = null;
                    _nivelFinal = null;
                  });
                },
              )
            : null,
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
              onPressed: () => _mostrarBuscarPaciente(context),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo paciente'),
              backgroundColor: AppColors.mentaVibrante,
              foregroundColor: Colors.white,
            )
          : null,
      body: switch (_paso) {
        _Paso.cola       => _buildCola(),
        _Paso.formulario => _buildFormulario(),
        _Paso.guardadoOk => _buildGuardadoOk(),
      },
    );
  }

  // ── Vista cola ────────────────────────────────────────────────────────────

  Widget _buildCola() {
    final filtradas  = _colaFiltrada;
    final pendientes = _cola.where((f) => !f.tieneTriage && f.estado == 'ABIERTA').length;
    final enTriaje   = _cola.where((f) => f.tieneTriage).length;

    return RefreshIndicator(
      onRefresh: _cargarCola,
      color: AppColors.azulElectrico,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _filtroCtrl,
              onChanged: _onFiltroChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, CI o ficha…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                suffixIcon: _filtroCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () { _filtroCtrl.clear(); setState(() => _filtroQuery = ''); },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          if (!_cargandoCola && _cola.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _StatChip('Pendientes', pendientes, Colors.orange.shade700),
                  const SizedBox(width: 8),
                  _StatChip('Triajados', enTriaje, Colors.green.shade700),
                  const SizedBox(width: 8),
                  _StatChip('Total', _cola.length, AppColors.azulElectrico),
                ],
              ),
            ),
          Expanded(
            child: _cargandoCola
                ? const LoadingIndicator(message: 'Cargando fichas del día…')
                : filtradas.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _cola.isEmpty ? 'Sin fichas hoy' : 'Sin resultados',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cola.isEmpty
                                ? 'Usa el botón + para buscar un paciente y crear una ficha.'
                                : 'Prueba con otro nombre o CI.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 88),
                        itemCount: filtradas.length,
                        itemBuilder: (_, i) => _ColaFichaCard(
                          ficha: filtradas[i],
                          onRealizarTriaje: () => _irAFormulario(filtradas[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Buscar paciente (bottom sheet) ────────────────────────────────────────

  Future<void> _mostrarBuscarPaciente(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscarPacienteSheet(
        triajeService: _triajeService,
        onFichaCreada: (ficha) {
          Navigator.pop(context);
          _irAFormulario(ficha);
        },
      ),
    );
  }

  // ── Formulario de triaje ──────────────────────────────────────────────────

  Widget _buildFormulario() {
    final reglasActivas = _resultado?['reglas_duras_aplicadas'] == true;
    final nivelNum      = _nivelFinal != null ? (_kLevelNum[_nivelFinal] ?? 3) : 99;
    final aiSugerido    = (_resultado?['nivel_sugerido'] as String?)?.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ficha != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.azulElectrico.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))],
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
                        Text('${_ficha!.estadoLabel} · ${_ficha!.paciente.nombreCompleto}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
            Expanded(child: _VitalField(ctrl: _fcCtrl, label: 'FC (lpm)', hint: '80')),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _frCtrl, label: 'FR (rpm)', hint: '16')),
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
              label: Text(_clasificando ? 'Clasificando…' : 'Clasificar con IA', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
            Text('El nivel sugerido por la IA está preseleccionado.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (reglasActivas) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Reglas clínicas duras activas. No se puede asignar un nivel menos urgente.', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
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
                  hintText: 'Explica por qué se modifica el nivel sugerido…',
                  alignLabelWithHint: true,
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextFormField(
              controller: _observacionesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observaciones (opcional)', hintText: 'Información adicional…', alignLabelWithHint: true),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt_rounded),
                label: Text(_guardando ? 'Guardando…' : 'Guardar triaje', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
    final nivel  = (_triajeGuardado?['nivel_urgencia'] as String?)?.toUpperCase() ?? _nivelFinal ?? 'AMARILLO';
    final color  = _nivelColor(nivel);
    final label  = _kLevelLabel[nivel] ?? nivel;
    final fueOverride   = _triajeGuardado?['fue_sobreescrito'] == true;
    final reglasActivas = _triajeGuardado?['reglas_duras_aplicadas'] == true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(_nivelIcon(nivel), color: color, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Triaje registrado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (_ficha?.paciente.nombreCompleto.isNotEmpty == true)
              Text(_ficha!.paciente.nombreCompleto, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            if (_ficha?.correlativo.isNotEmpty == true)
              Text(_ficha!.correlativo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (fueOverride || reglasActivas) ...[
              const SizedBox(height: 12),
              if (fueOverride) _InfoTag(icon: Icons.edit_outlined, text: 'Nivel modificado por enfermería', color: Colors.orange.shade700),
              if (reglasActivas) const _InfoTag(icon: Icons.warning_rounded, text: 'Reglas clínicas duras aplicadas', color: Color(0xFFDC2626)),
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

// ── Bottom sheet búsqueda de paciente ────────────────────────────────────────

class _BuscarPacienteSheet extends StatefulWidget {
  final TriajeService triajeService;
  final ValueChanged<FichaModel> onFichaCreada;

  const _BuscarPacienteSheet({required this.triajeService, required this.onFichaCreada});

  @override
  State<_BuscarPacienteSheet> createState() => _BuscarPacienteSheetState();
}

class _BuscarPacienteSheetState extends State<_BuscarPacienteSheet> {
  final _pacienteService = PacienteService();
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;

  List<PacienteModel> _resultados = [];
  bool _buscando        = false;
  bool _creanDo         = false;
  bool _buscoPrimeraVez = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _resultados = []; _buscoPrimeraVez = false; });
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 350), () => _buscar(q.trim()));
  }

  Future<void> _buscar(String q) async {
    setState(() { _buscando = true; _buscoPrimeraVez = true; });
    try {
      final list = await _pacienteService.listar(search: q);
      if (mounted) setState(() => _resultados = list);
    } catch (_) {
      if (mounted) setState(() => _resultados = []);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _seleccionarPaciente(PacienteModel p) async {
    setState(() => _creanDo = true);
    try {
      final ficha = await widget.triajeService.crearFicha(p.id);
      if (mounted) widget.onFichaCreada(ficha);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
        );
        setState(() => _creanDo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Buscar paciente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'CI o nombre / apellido…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_creanDo)
              const Expanded(child: LoadingIndicator(message: 'Creando ficha…'))
            else
              Expanded(
                child: _buscando
                    ? const Center(child: CircularProgressIndicator())
                    : _resultados.isEmpty
                        ? Center(
                            child: Text(
                              _buscoPrimeraVez ? 'Sin resultados' : 'Escribe para buscar',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: _resultados.length,
                            itemBuilder: (_, i) {
                              final p = _resultados[i];
                              return ListTile(
                                leading: const CircleAvatar(backgroundColor: AppColors.azulCielo, child: Icon(Icons.person_outline, color: AppColors.azulElectrico)),
                                title: Text(p.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('CI: ${p.ciCompleto}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                onTap: () => _seleccionarPaciente(p),
                              );
                            },
                          ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Card de ficha en la cola ──────────────────────────────────────────────────

class _ColaFichaCard extends StatelessWidget {
  final FichaModel ficha;
  final VoidCallback? onRealizarTriaje;

  const _ColaFichaCard({required this.ficha, this.onRealizarTriaje});

  @override
  Widget build(BuildContext context) {
    final yaTriajado = ficha.tieneTriage;
    final nivel      = ficha.nivelUrgencia;
    final nivelColor = nivel != null ? _nivelColor(nivel) : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 56,
              decoration: BoxDecoration(
                color: yaTriajado ? nivelColor : Colors.orange.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ficha.paciente.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${ficha.correlativo} · CI: ${ficha.paciente.ci}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: yaTriajado ? nivelColor.withOpacity(0.12) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: yaTriajado ? nivelColor.withOpacity(0.4) : Colors.orange.shade200),
                        ),
                        child: Text(
                          yaTriajado ? (nivel ?? 'Triajado') : ficha.estadoLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: yaTriajado ? nivelColor : Colors.orange.shade800),
                        ),
                      ),
                      if (yaTriajado && ficha.motivoConsulta != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(ficha.motivoConsulta!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!yaTriajado && ficha.estado == 'ABIERTA')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton(
                  onPressed: onRealizarTriaje,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mentaVibrante,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Triaje', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )
            else if (yaTriajado && nivel != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: nivelColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_nivelIcon(nivel), color: nivelColor, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          '$label: $count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
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

class _VitalField extends StatelessWidget {
  const _VitalField({required this.ctrl, required this.label, required this.hint, this.decimal = false});
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool decimal;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: [
          if (decimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(labelText: label, hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
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
    final label = _kLevelLabel[nivel] ?? nivel;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : (disabled ? Colors.grey.shade100 : color.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : (disabled ? Colors.grey.shade300 : color.withOpacity(0.4)), width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_nivelIcon(nivel), size: 16, color: selected ? Colors.white : (disabled ? Colors.grey : color)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : (disabled ? Colors.grey : color))),
          ],
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_nivelIcon(nivel), color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clasificación IA', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ),
              if (confianza != null && confianza != '—' && !mlDegradado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('$confianza%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
          if (mlDegradado) ...[
            const SizedBox(height: 8),
            Text('Clasificado por reglas clínicas (IA no disponible)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ],
          if (reglasActivas) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 6),
                  Expanded(child: Text('Reglas clínicas duras aplicadas', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      );
}
