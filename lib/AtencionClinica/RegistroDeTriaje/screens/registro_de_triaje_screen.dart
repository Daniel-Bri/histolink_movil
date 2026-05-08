import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/widgets/paciente_card.dart';
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

// ── Enum de pasos ─────────────────────────────────────────────────────────────

enum _Paso { buscarPaciente, seleccionarFicha, formulario, guardadoOk }

// ── Screen ────────────────────────────────────────────────────────────────────

class RegistroDeTriajeScreen extends StatefulWidget {
  const RegistroDeTriajeScreen({super.key, this.fichaInicial});

  /// Ficha preseleccionada (cuando se navega desde una lista de fichas).
  final FichaModel? fichaInicial;

  @override
  State<RegistroDeTriajeScreen> createState() => _RegistroDeTriajeScreenState();
}

class _RegistroDeTriajeScreenState extends State<RegistroDeTriajeScreen> {
  final _pacienteService = PacienteService();
  final _triajeService   = TriajeService();

  _Paso _paso = _Paso.buscarPaciente;

  // Paso 1 – buscar paciente
  final _searchCtrl = TextEditingController();
  List<PacienteModel> _pacientes  = [];
  bool _buscando      = false;
  bool _buscoPacientes = false;

  // Paso 2 – seleccionar ficha
  PacienteModel? _paciente;
  List<FichaModel> _fichas       = [];
  bool _cargandoFichas = false;

  // Paso 3 – formulario de triaje
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
  String? _nivelFinal;   // nivel confirmado por enfermería
  bool _override = false; // enfermera cambió el nivel sugerido por IA

  bool _guardando = false;
  Map<String, dynamic>? _triajeGuardado;

  @override
  void initState() {
    super.initState();
    if (widget.fichaInicial != null) {
      _ficha = widget.fichaInicial;
      _paso  = _Paso.formulario;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  // ── Navegación interna ────────────────────────────────────────────────────

  void _handleBack() {
    switch (_paso) {
      case _Paso.seleccionarFicha:
        setState(() {
          _paso  = _Paso.buscarPaciente;
          _fichas = [];
          _ficha  = null;
        });
      case _Paso.formulario:
        if (widget.fichaInicial != null) {
          Navigator.pop(context);
        } else {
          setState(() {
            _paso      = _Paso.seleccionarFicha;
            _resultado = null;
            _nivelFinal = null;
            _override   = false;
          });
        }
      case _Paso.guardadoOk:
        Navigator.pop(context, true);
      case _Paso.buscarPaciente:
        Navigator.pop(context);
    }
  }

  String get _appBarTitle => switch (_paso) {
        _Paso.buscarPaciente   => 'Nuevo triaje',
        _Paso.seleccionarFicha => 'Seleccionar ficha',
        _Paso.formulario       => 'Triaje',
        _Paso.guardadoOk       => 'Triaje registrado',
      };

  bool get _canPopNormally =>
      (_paso == _Paso.buscarPaciente && widget.fichaInicial == null) ||
      _paso == _Paso.guardadoOk;

  // ── Paso 1: buscar paciente ───────────────────────────────────────────────

  Future<void> _buscarPacientes() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando      = true;
      _buscoPacientes = true;
    });
    try {
      final q    = _searchCtrl.text.trim();
      final list = await _pacienteService.listar(search: q.isEmpty ? null : q);
      if (!mounted) return;
      setState(() => _pacientes = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _seleccionarPaciente(PacienteModel p) async {
    setState(() {
      _paciente      = p;
      _fichas        = [];
      _cargandoFichas = true;
      _paso          = _Paso.seleccionarFicha;
    });
    try {
      final fichas = await _triajeService.listarFichasAbiertas(p.id);
      if (!mounted) return;
      setState(() => _fichas = fichas);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _cargandoFichas = false);
    }
  }

  // ── Paso 2: seleccionar ficha ─────────────────────────────────────────────

  void _seleccionarFicha(FichaModel f) {
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
      for (final c in controllers) {
        c.clear();
      }
    });
  }

  // ── Paso 3a: clasificar con IA ────────────────────────────────────────────

  Future<void> _clasificar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _clasificando = true;
      _resultado    = null;
      _nivelFinal   = null;
      _override     = false;
    });
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

  // ── Paso 3b: guardar triaje ───────────────────────────────────────────────

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
        data['nivel_sugerido_ia']  = (sugerido as String).toUpperCase();
        data['fue_sobreescrito']   = _override;
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

      addDbl('peso_kg',              _pesoCtrl.text);
      addDbl('talla_cm',             _tallaCtrl.text);
      addInt('frecuencia_cardiaca',  _fcCtrl.text);
      addInt('frecuencia_respiratoria', _frCtrl.text);
      addInt('presion_sistolica',    _pasCtrl.text);
      addInt('presion_diastolica',   _padCtrl.text);
      addDbl('temperatura_celsius',  _tempCtrl.text);
      addInt('saturacion_oxigeno',   _spo2Ctrl.text);
      addDbl('glucemia',             _glucemiaCtrl.text);
      addInt('escala_dolor',         _dolorCtrl.text);
      addInt('glasgow',              _glasgowCtrl.text);

      final saved = await _triajeService.guardar(data);
      if (!mounted) return;
      setState(() {
        _triajeGuardado = saved;
        _paso           = _Paso.guardadoOk;
      });
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          title: Text(_appBarTitle),
          backgroundColor: AppColors.azulElectrico,
          foregroundColor: Colors.white,
          leading: _canPopNormally
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _handleBack,
                ),
        ),
        body: switch (_paso) {
          _Paso.buscarPaciente   => _buildBuscarPaciente(),
          _Paso.seleccionarFicha => _buildSeleccionarFicha(),
          _Paso.formulario       => _buildFormulario(),
          _Paso.guardadoOk       => _buildGuardadoOk(),
        },
      ),
    );
  }

  // ── Paso 1 ────────────────────────────────────────────────────────────────

  Widget _buildBuscarPaciente() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarPacientes(),
                  decoration: const InputDecoration(
                    hintText: 'CI o nombre / apellido',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                width: 52,
                child: FilledButton(
                  onPressed: _buscando ? null : _buscarPacientes,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.azulElectrico,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  child: _buscando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded, size: 26),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pacientes.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                    Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      _buscoPacientes ? 'Sin resultados' : 'Busca el paciente a triajear',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Escribe el CI o nombre y pulsa la lupa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemCount: _pacientes.length,
                  itemBuilder: (_, i) => PacienteCard(
                    paciente: _pacientes[i],
                    onTap: () => _seleccionarPaciente(_pacientes[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Paso 2 ────────────────────────────────────────────────────────────────

  Widget _buildSeleccionarFicha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_paciente != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.azulCielo.withOpacity(0.4),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: AppColors.azulElectrico),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _paciente!.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azulElectrico),
                      ),
                      Text(
                        'CI: ${_paciente!.ciCompleto}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_cargandoFichas)
          const Expanded(child: LoadingIndicator(message: 'Cargando fichas…'))
        else if (_fichas.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Sin fichas abiertas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este paciente no tiene fichas en curso.\nAbre una ficha desde recepción antes de realizar el triaje.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Selecciona la ficha a triajear',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ),
                ..._fichas.map(
                  (f) => _FichaCard(
                    ficha: f,
                    onTap: f.tieneTriage ? null : () => _seleccionarFicha(f),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Paso 3 ────────────────────────────────────────────────────────────────

  Widget _buildFormulario() {
    final reglasActivas = _resultado?['reglas_duras_aplicadas'] == true;
    final nivelNum = _nivelFinal != null ? (_kLevelNum[_nivelFinal] ?? 3) : 99;
    final aiSugerido = (_resultado?['nivel_sugerido'] as String?)?.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info de la ficha
          if (_ficha != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppColors.azulElectrico.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppColors.azulElectrico, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ficha!.correlativo,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azulElectrico),
                        ),
                        Text(
                          '${_ficha!.estadoLabel} · ${_ficha!.paciente.nombreCompleto}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Motivo de consulta
          _SectionHeader('Motivo de consulta'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _motivoCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Describe los síntomas principales…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // Signos vitales
          _SectionHeader('Signos vitales'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _pesoCtrl,   label: 'Peso (kg)',   hint: '70.5', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _tallaCtrl,  label: 'Talla (cm)',  hint: '165',  decimal: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _fcCtrl,  label: 'FC (lpm)',  hint: '80')),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _frCtrl,  label: 'FR (rpm)',  hint: '16')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _pasCtrl, label: 'PAS (mmHg)', hint: '120')),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _padCtrl, label: 'PAD (mmHg)', hint: '80')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _tempCtrl,   label: 'Temp (°C)',   hint: '36.5', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _spo2Ctrl,   label: 'SpO₂ (%)',    hint: '98')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalField(ctrl: _glucemiaCtrl, label: 'Glucemia (mg/dL)', hint: '90', decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _VitalField(ctrl: _dolorCtrl,    label: 'Dolor EVA 0–10',  hint: '0')),
          ]),
          const SizedBox(height: 10),
          _VitalField(ctrl: _glasgowCtrl, label: 'Glasgow (3–15)', hint: '15'),
          const SizedBox(height: 20),

          // Botón clasificar
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _clasificando ? null : _clasificar,
              icon: _clasificando
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology_outlined),
              label: Text(
                _clasificando ? 'Clasificando…' : 'Clasificar con IA',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Resultado de clasificación
          if (_resultado != null) ...[
            const SizedBox(height: 20),
            _ResultadoCard(
              nivel:        _nivelFinal!,
              confianza:    _resultado?['confianza_pct']?.toString(),
              mlDegradado:  _resultado?['ml_degradado'] == true,
              reglasActivas: reglasActivas,
            ),
            const SizedBox(height: 18),

            // Selector de nivel
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
                  nivel:    nivel,
                  selected: selected,
                  disabled: disabled,
                  onTap: disabled
                      ? null
                      : () => setState(() {
                            _nivelFinal = nivel;
                            _override   = nivel != aiSugerido;
                            if (!_override) _justificacionCtrl.clear();
                          }),
                );
              }).toList(),
            ),

            // Justificación (requerida si override)
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

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: Text(
                  _guardando ? 'Guardando…' : 'Guardar triaje',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
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

  // ── Paso 4: éxito ─────────────────────────────────────────────────────────

  Widget _buildGuardadoOk() {
    final nivel = (_triajeGuardado?['nivel_urgencia'] as String?)?.toUpperCase()
        ?? _nivelFinal
        ?? 'AMARILLO';
    final color = _nivelColor(nivel);
    final label = _kLevelLabel[nivel] ?? nivel;
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
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(_nivelIcon(nivel), color: color, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Triaje registrado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (pacienteNombre.isNotEmpty)
              Text(pacienteNombre, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            if (correlativo.isNotEmpty)
              Text(correlativo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (fueOverride || reglasActivas) ...[
              const SizedBox(height: 12),
              if (fueOverride)
                _InfoTag(icon: Icons.edit_outlined, text: 'Nivel modificado por enfermería', color: Colors.orange.shade700),
              if (reglasActivas)
                _InfoTag(icon: Icons.warning_rounded, text: 'Reglas clínicas duras aplicadas', color: const Color(0xFFDC2626)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w600)),
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

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
  const _VitalField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.decimal = false,
  });

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
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}

class _FichaCard extends StatelessWidget {
  const _FichaCard({required this.ficha, this.onTap});

  final FichaModel ficha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: disabled ? Colors.grey.shade400 : AppColors.azulElectrico,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ficha.correlativo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: disabled ? Colors.grey.shade500 : AppColors.azulElectrico,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ficha.estadoLabel + (ficha.tieneTriage ? ' · Ya tiene triaje' : ''),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (ficha.tieneTriage)
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20)
              else
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  const _ResultadoCard({
    required this.nivel,
    this.confianza,
    required this.mlDegradado,
    required this.reglasActivas,
  });

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
                    const Text(
                      'Clasificación IA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                    Text(
                      label,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                    ),
                  ],
                ),
              ),
              if (confianza != null && confianza != '—' && !mlDegradado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confianza%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
            ],
          ),
          if (mlDegradado) ...[
            const SizedBox(height: 8),
            Text(
              'Clasificado por reglas clínicas (IA no disponible)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (reglasActivas) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reglas clínicas duras aplicadas',
                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NivelChip extends StatelessWidget {
  const _NivelChip({
    required this.nivel,
    required this.selected,
    required this.disabled,
    this.onTap,
  });

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
          border: Border.all(
            color: selected ? color : (disabled ? Colors.grey.shade300 : color.withOpacity(0.4)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _nivelIcon(nivel),
              size: 16,
              color: selected ? Colors.white : (disabled ? Colors.grey : color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : (disabled ? Colors.grey : color),
              ),
            ),
          ],
        ),
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
