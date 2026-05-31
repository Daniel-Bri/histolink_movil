import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consulta_model.dart';
import '../services/consulta_service.dart';
import '../widgets/soap_section.dart';
import '../widgets/cie10_search_field.dart';
import '../../../shared/theme/app_colors.dart';

// Estado visual del autoguardado en el AppBar
enum _AutosaveState { idle, saving, saved, error }

class ConsultaSoapScreen extends StatefulWidget {
  final int? consultaId;
  final int? fichaId;
  final Map<String, dynamic> initialData;

  const ConsultaSoapScreen({
    super.key,
    this.consultaId,
    this.fichaId,
    required this.initialData,
  });

  @override
  State<ConsultaSoapScreen> createState() => _ConsultaSoapScreenState();
}

class _ConsultaSoapScreenState extends State<ConsultaSoapScreen>
    with TickerProviderStateMixin {
  // ── Servicios y claves ──────────────────────────────────────────────────
  final ConsultaService _service = ConsultaService();
  final _formKey = GlobalKey<FormState>();

  // ── Tab controller ──────────────────────────────────────────────────────
  late TabController _tabController;
  static const _tabs = [
    _SoapTab('S', 'Subjetivo', Icons.person_outline),
    _SoapTab('O', 'Objetivo', Icons.monitor_heart_outlined),
    _SoapTab('A', 'Análisis', Icons.analytics_outlined),
    _SoapTab('P', 'Plan', Icons.assignment_outlined),
  ];

  // ── Controllers SOAP ────────────────────────────────────────────────────
  final TextEditingController _subjetivoCtrl = TextEditingController();
  final TextEditingController _examenFisicoCtrl = TextEditingController();
  final TextEditingController _analisisCtrl = TextEditingController();
  final TextEditingController _planCtrl = TextEditingController();

  // ── Controllers Signos Vitales (pestaña O) ──────────────────────────────
  final TextEditingController _fcCtrl = TextEditingController();
  final TextEditingController _pasSCtrl = TextEditingController(); // sistólica
  final TextEditingController _padCtrl = TextEditingController(); // diastólica
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _spo2Ctrl = TextEditingController();

  // ── Estado general ──────────────────────────────────────────────────────
  ConsultaMedica? _consulta;
  bool _isLoading = true;
  bool _isCompleting = false;
  Map<String, dynamic>? _selectedCie10;
  String? _cie10Error;

  // ── Autoguardado ────────────────────────────────────────────────────────
  _AutosaveState _autosaveState = _AutosaveState.idle;
  DateTime? _lastSavedAt;
  Timer? _autosaveTimer;
  // Detectamos cambios para activar el timer
  bool _isDirty = false;

  // ────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autosaveTimer?.cancel();
    for (final c in [
      _subjetivoCtrl, _examenFisicoCtrl, _analisisCtrl, _planCtrl,
      _fcCtrl, _pasSCtrl, _padCtrl, _tempCtrl, _spo2Ctrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Carga inicial
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.consultaId != null) {
        _consulta = await _service.getById(widget.consultaId!);
      } else if (widget.fichaId != null) {
        try {
          _consulta = await _service.create(widget.fichaId!);
        } catch (e) {
          _consulta = ConsultaMedica(
            id: -1,
            pacienteId: widget.initialData['paciente_id'] ?? 0,
            pacienteNombre:
                widget.initialData['paciente_nombre'] ?? 'Paciente de Prueba',
            subjetivo: '',
            objetivo: '',
            analisis: '',
            plan: '',
            estado: EstadoConsulta.borrador,
            fechaCreacion: DateTime.now(),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Servidor no disponible. Entrando en MODO DEMO para previsualización.'),
              backgroundColor: Colors.orange,
            ));
          }
        }
      }

      if (_consulta != null) {
        _subjetivoCtrl.text = _consulta!.subjetivo;
        _analisisCtrl.text = _consulta!.analisis;
        _planCtrl.text = _consulta!.plan;
        _selectedCie10 = _consulta!.diagnosticoPrincipal;

        // Intentar cargar signos vitales del triaje más reciente
        if (_consulta!.pacienteId != 0) {
          try {
            final triaje =
                await _service.getUltimoTriaje(_consulta!.pacienteId);
            if (triaje != null) {
              _fcCtrl.text =
                  triaje['frecuencia_cardiaca']?.toString() ?? '';
              _pasSCtrl.text =
                  triaje['presion_arterial_sistolica']?.toString() ?? '';
              _padCtrl.text =
                  triaje['presion_arterial_diastolica']?.toString() ?? '';
              _tempCtrl.text =
                  triaje['temperatura']?.toString() ?? '';
              _spo2Ctrl.text =
                  triaje['saturacion_oxigeno']?.toString() ?? '';
            }
          } catch (_) {}
        }

        // Si ya había texto libre de examen físico guardado, restaurarlo
        // El objetivo se almacena como texto libre; los signos vitales son separados
        _examenFisicoCtrl.text = _consulta!.objetivo;

        // Escuchar cambios para autoguardado solo si editable
        if (_consulta!.isEditable) {
          _attachDirtyListeners();
        }
      }
    } catch (e) {
      debugPrint('ERROR _loadData: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _attachDirtyListeners() {
    for (final c in [
      _subjetivoCtrl, _examenFisicoCtrl, _analisisCtrl, _planCtrl,
      _fcCtrl, _pasSCtrl, _padCtrl, _tempCtrl, _spo2Ctrl,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    // Reiniciar el timer cada vez que el usuario escribe
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 5), _autoSave);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Autoguardado silencioso
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _autoSave() async {
    if (_consulta == null || !_consulta!.isEditable || !_isDirty) return;
    setState(() => _autosaveState = _AutosaveState.saving);
    try {
      await _doSave();
      if (mounted) {
        setState(() {
          _autosaveState = _AutosaveState.saved;
          _lastSavedAt = DateTime.now();
          _isDirty = false;
        });
        // Volver a idle después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _autosaveState = _AutosaveState.idle);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _autosaveState = _AutosaveState.error);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Guardado real (borrador manual o autoguardado)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _doSave() async {
    final data = _buildPayload();
    if (_consulta!.id < 0) {
      // MODO DEMO
      await Future.delayed(const Duration(milliseconds: 400));
      _consulta = _consulta!.copyWith(
        subjetivo: data['motivo_consulta'] as String,
        objetivo: data['examen_fisico'] as String,
        analisis: data['impresion_diagnostica'] as String,
        plan: data['plan_tratamiento'] as String,
        diagnosticoPrincipal: _selectedCie10,
      );
    } else {
      _consulta = await _service.update(_consulta!.id, data);
    }
  }

  Future<void> _saveBorrador() async {
    if (_consulta == null || !_consulta!.isEditable) return;
    setState(() => _autosaveState = _AutosaveState.saving);
    try {
      await _doSave();
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _autosaveState = _AutosaveState.saved;
          _lastSavedAt = DateTime.now();
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borrador guardado')),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _autosaveState = _AutosaveState.idle);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _autosaveState = _AutosaveState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    // Construir texto de objetivo: signos vitales estructurados + examen físico
    final vitalLines = <String>[];
    if (_fcCtrl.text.isNotEmpty) vitalLines.add('FC: ${_fcCtrl.text} lpm');
    if (_pasSCtrl.text.isNotEmpty && _padCtrl.text.isNotEmpty) {
      vitalLines.add('PA: ${_pasSCtrl.text}/${_padCtrl.text} mmHg');
    }
    if (_tempCtrl.text.isNotEmpty) vitalLines.add('T°: ${_tempCtrl.text} °C');
    if (_spo2Ctrl.text.isNotEmpty) {
      vitalLines.add('SpO₂: ${_spo2Ctrl.text}%');
    }

    final objetivoTexto = vitalLines.isNotEmpty
        ? '[Signos Vitales] ${vitalLines.join(' | ')}\n\n${_examenFisicoCtrl.text}'
        : _examenFisicoCtrl.text;

    return {
      'motivo_consulta': _subjetivoCtrl.text,
      'examen_fisico': objetivoTexto,
      'impresion_diagnostica': _analisisCtrl.text,
      'plan_tratamiento': _planCtrl.text,
      'codigo_cie10_principal': _selectedCie10?['codigo'],
      'descripcion_cie10': _selectedCie10?['descripcion'],
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Completar consulta
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _completarConsulta() async {
    if (_consulta == null || !_consulta!.isEditable) return;

    setState(() =>
        _cie10Error = _selectedCie10 == null ? 'Seleccione un diagnóstico CIE-10' : null);

    if (!_formKey.currentState!.validate() || _selectedCie10 == null) {
      // Navegar a la pestaña A si falta el CIE-10
      if (_selectedCie10 == null) _tabController.animateTo(2);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar finalización'),
        content: const Text(
            '¿Desea marcar esta consulta como COMPLETADA?\n\nUna vez completada no podrá editar los campos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mentaVibrante,
                foregroundColor: Colors.white),
            child: const Text('COMPLETAR'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCompleting = true);
    try {
      final data = _buildPayload();
      if (_consulta!.id < 0) {
        await Future.delayed(const Duration(milliseconds: 600));
        _consulta = _consulta!.copyWith(
          subjetivo: data['motivo_consulta'] as String,
          objetivo: data['examen_fisico'] as String,
          analisis: data['impresion_diagnostica'] as String,
          plan: data['plan_tratamiento'] as String,
          diagnosticoPrincipal: _selectedCie10,
          estado: EstadoConsulta.completada,
        );
      } else {
        await _service.update(_consulta!.id, data);
        _consulta = await _service.completar(_consulta!.id);
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Consulta completada con éxito'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al completar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading || _consulta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEditable = _consulta!.isEditable;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: _buildAppBar(isEditable),
      body: Column(
        children: [
          _buildPatientInfo(),
          _buildTabBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabS(isEditable),
                  _buildTabO(isEditable),
                  _buildTabA(isEditable),
                  _buildTabP(isEditable),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isEditable),
    );
  }

  // ── AppBar con indicador de autoguardado ─────────────────────────────────
  AppBar _buildAppBar(bool isEditable) {
    return AppBar(
      backgroundColor: AppColors.azulElectrico,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Consulta Médica SOAP',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      actions: [
        if (isEditable) _buildAutosaveIndicator(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAutosaveIndicator() {
    switch (_autosaveState) {
      case _AutosaveState.saving:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70)),
              SizedBox(width: 6),
              Text('Guardando…', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        );
      case _AutosaveState.saved:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.cloud_done_outlined, size: 16, color: Colors.greenAccent),
              SizedBox(width: 4),
              Text('Borrador guardado',
                  style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
            ],
          ),
        );
      case _AutosaveState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _saveBorrador,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      case _AutosaveState.idle:
        if (_isDirty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: Colors.white60),
                SizedBox(width: 4),
                Text('Sin guardar', style: TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          );
        }
        if (_lastSavedAt != null) {
          final h = _lastSavedAt!.hour.toString().padLeft(2, '0');
          final m = _lastSavedAt!.minute.toString().padLeft(2, '0');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Guardado $h:$m',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          );
        }
        return const SizedBox.shrink();
    }
  }

  // ── Info de paciente ─────────────────────────────────────────────────────
  Widget _buildPatientInfo() {
    final estado = _consulta!.estado;
    final statusColor = {
      EstadoConsulta.borrador: Colors.amber[700]!,
      EstadoConsulta.completada: Colors.green[700]!,
      EstadoConsulta.firmada: AppColors.azulElectrico,
    }[estado]!;
    final statusBg = {
      EstadoConsulta.borrador: Colors.amber[50]!,
      EstadoConsulta.completada: Colors.green[50]!,
      EstadoConsulta.firmada: Colors.blue[50]!,
    }[estado]!;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.azulElectrico.withValues(alpha: 0.12),
            radius: 20,
            child: Icon(Icons.person, color: AppColors.azulElectrico, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _consulta!.pacienteNombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID ${_consulta!.pacienteId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              estado.name.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── TabBar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.azulElectrico,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: AppColors.azulElectrico,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: _tabs.map((t) => Tab(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.letter,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              Text(t.label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ── Pestaña S – Subjetivo ────────────────────────────────────────────────
  Widget _buildTabS(bool isEditable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionHeader(Icons.person_outline, 'Subjetivo (S)',
              'Motivo de consulta y anamnesis del paciente'),
          const SizedBox(height: 12),
          SoapSection(
            title: 'Motivo de consulta / Síntomas',
            icon: Icons.chat_bubble_outline,
            controller: _subjetivoCtrl,
            placeholder:
                'Describa el motivo de consulta, síntomas referidos, historia de la enfermedad actual, antecedentes relevantes...',
            isReadOnly: !isEditable,
            minLines: 6,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'El campo Subjetivo es obligatorio' : null,
          ),
        ],
      ),
    );
  }

  // ── Pestaña O – Objetivo ─────────────────────────────────────────────────
  Widget _buildTabO(bool isEditable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.monitor_heart_outlined, 'Objetivo (O)',
              'Signos vitales y examen físico'),
          const SizedBox(height: 12),

          // ── Bloque de signos vitales ────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_outline,
                          color: Colors.red[400], size: 18),
                      const SizedBox(width: 8),
                      const Text('Signos Vitales',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      if (!isEditable)
                        const Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Fila 1: FC y SpO2
                  Row(
                    children: [
                      Expanded(
                        child: _vitalField(
                          controller: _fcCtrl,
                          label: 'FC',
                          unit: 'lpm',
                          icon: Icons.favorite,
                          iconColor: Colors.red,
                          isReadOnly: !isEditable,
                          isInt: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _vitalField(
                          controller: _spo2Ctrl,
                          label: 'SpO₂',
                          unit: '%',
                          icon: Icons.air,
                          iconColor: Colors.blue,
                          isReadOnly: !isEditable,
                          isInt: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Fila 2: PA sistólica y diastólica
                  Row(
                    children: [
                      Expanded(
                        child: _vitalField(
                          controller: _pasSCtrl,
                          label: 'PAS',
                          unit: 'mmHg',
                          icon: Icons.speed,
                          iconColor: Colors.purple,
                          isReadOnly: !isEditable,
                          isInt: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(' / ',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600])),
                      ),
                      Expanded(
                        child: _vitalField(
                          controller: _padCtrl,
                          label: 'PAD',
                          unit: 'mmHg',
                          icon: Icons.speed_outlined,
                          iconColor: Colors.deepPurple,
                          isReadOnly: !isEditable,
                          isInt: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Fila 3: Temperatura
                  _vitalField(
                    controller: _tempCtrl,
                    label: 'Temperatura',
                    unit: '°C',
                    icon: Icons.thermostat,
                    iconColor: Colors.orange,
                    isReadOnly: !isEditable,
                    isInt: false,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Examen físico libre ─────────────────────────────────────────
          SoapSection(
            title: 'Examen Físico',
            icon: Icons.medical_information_outlined,
            controller: _examenFisicoCtrl,
            placeholder:
                'Hallazgos del examen físico: aspecto general, auscultación, palpación, neurológico...',
            isReadOnly: !isEditable,
            minLines: 5,
          ),
        ],
      ),
    );
  }

  // ── Pestaña A – Análisis/Evaluación ─────────────────────────────────────
  Widget _buildTabA(bool isEditable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionHeader(Icons.analytics_outlined, 'Análisis / Evaluación (A)',
              'Diagnóstico diferencial y código CIE-10'),
          const SizedBox(height: 12),

          SoapSection(
            title: 'Análisis Clínico',
            icon: Icons.text_snippet_outlined,
            controller: _analisisCtrl,
            placeholder:
                'Diagnóstico diferencial, interpretación de hallazgos, razonamiento clínico...',
            isReadOnly: !isEditable,
            minLines: 4,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'La evaluación clínica es obligatoria' : null,
          ),

          // ── Búsqueda CIE-10 ─────────────────────────────────────────────
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: AppColors.azulElectrico, size: 18),
                      const SizedBox(width: 8),
                      const Text('Diagnóstico Principal (CIE-10)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busque por código o nombre de la enfermedad',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),
                  Cie10SearchField(
                    initialValue: _selectedCie10,
                    isReadOnly: !isEditable,
                    errorText: _cie10Error,
                    onSelected: (val) => setState(() {
                      _selectedCie10 = val;
                      _cie10Error = null;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pestaña P – Plan ─────────────────────────────────────────────────────
  Widget _buildTabP(bool isEditable) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionHeader(Icons.assignment_outlined, 'Plan (P)',
              'Tratamiento, indicaciones y seguimiento'),
          const SizedBox(height: 12),
          SoapSection(
            title: 'Plan de Tratamiento',
            icon: Icons.medication_outlined,
            controller: _planCtrl,
            placeholder:
                'Medicamentos, dosis, indicaciones, interconsultas, estudios complementarios, seguimiento...',
            isReadOnly: !isEditable,
            minLines: 7,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'El plan de tratamiento es obligatorio' : null,
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────
  Widget? _buildBottomBar(bool isEditable) {
    if (!isEditable) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Text(
              'Consulta en modo lectura · ${_consulta!.estado.name.toUpperCase()}',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          // Botón guardar borrador manual
          OutlinedButton.icon(
            onPressed: _isCompleting ? null : _saveBorrador,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Borrador'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),
          // Botón completar consulta
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isCompleting ? null : _completarConsulta,
              icon: _isCompleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(_isCompleting ? 'Procesando…' : 'Completar Consulta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mentaVibrante,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.azulElectrico.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.azulElectrico, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _vitalField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required bool isReadOnly,
    required bool isInt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType:
              isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: isInt
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AppColors.azulElectrico, width: 1.5)),
            filled: isReadOnly,
            fillColor: isReadOnly ? Colors.grey[50] : Colors.white,
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Modelo auxiliar de pestaña ───────────────────────────────────────────────
class _SoapTab {
  final String letter;
  final String label;
  final IconData icon;
  const _SoapTab(this.letter, this.label, this.icon);
}
