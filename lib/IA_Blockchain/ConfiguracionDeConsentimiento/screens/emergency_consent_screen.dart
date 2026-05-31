import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import '../services/emergency_consent_service.dart';

class EmergencyConsentScreen extends StatefulWidget {
  final int? pacienteId; // Ahora es opcional

  const EmergencyConsentScreen({super.key, this.pacienteId});

  @override
  State<EmergencyConsentScreen> createState() => _EmergencyConsentScreenState();
}

class _EmergencyConsentScreenState extends State<EmergencyConsentScreen> {
  final _service = EmergencyConsentService();
  final _formKey = GlobalKey<FormState>();
  
  List<PacienteModel> _pacientes = [];
  PacienteModel? _pacienteSeleccionado;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _alreadyExists = false;

  String? _procedimiento;
  final _justificacionController = TextEditingController();
  final _testigoController = TextEditingController();
  
  // Variables para Fecha y Hora (Bloqueada y Auto-actualizable)
  DateTime _fechaHoraActual = DateTime.now();
  Timer? _timer;

  final List<String> _procedimientos = [
    'Reanimación cardiopulmonar',
    'Intubación',
    'Cirugía de urgencia',
    'Transfusión sanguínea',
    'Administración de fármacos de alto riesgo',
    'Otro'
  ];

  final List<String> _sugerenciasJustificacion = [
    'Paciente inconsciente',
    'Riesgo vital inminente',
    'Menor de edad sin apoderado',
    'Paciente en estado crítico sin capacidad de decisión'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Iniciar temporizador para actualizar el minuto en tiempo real (Punto 4)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _fechaHoraActual = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Limpiar temporizador
    _justificacionController.dispose();
    _testigoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final lista = await _service.fetchAllPacientes();
      _pacientes = lista;

      if (widget.pacienteId != null) {
        _pacienteSeleccionado = _pacientes.firstWhere(
          (p) => p.id == widget.pacienteId,
          orElse: () => _pacientes.first,
        );
        await _checkDuplicate(_pacienteSeleccionado!.id);
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al cargar pacientes: $e', isError: true);
    }
  }

  Future<void> _checkDuplicate(int id) async {
    final exists = await _service.checkExistingConsent(id);
    setState(() => _alreadyExists = exists);
  }

  void _addSugerencia(String texto) {
    final current = _justificacionController.text;
    _justificacionController.text = current.isEmpty ? texto : '$current, $texto';
    HapticFeedback.selectionClick();
  }

  Future<void> _registrar() async {
    if (_pacienteSeleccionado == null) {
      _showSnackBar('Debe seleccionar un paciente', isError: true);
      return;
    }

    if (_alreadyExists) {
      _showSnackBar('Ya existe un consentimiento registrado hoy para este paciente.', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    // Cálculo de vigencia: 1 año después del registro (365 días)
    final fechaVigencia = _fechaHoraActual.add(const Duration(days: 365));

    final data = {
      'paciente_id': _pacienteSeleccionado!.id,
      'paciente_nombre': _pacienteSeleccionado!.nombreCompleto,
      'procedimiento': _procedimiento,
      'justificacion': _justificacionController.text,
      'testigos': _testigoController.text, 
      'fecha_hora': _fechaHoraActual.toIso8601String(), // fecha_registro
      'fecha_vigencia': fechaVigencia.toIso8601String(), // Nueva fecha de vigencia
    };

    final result = await _service.saveConsentimiento(data);

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success']) {
        HapticFeedback.vibrate();
        _showSnackBar(result['message'], isError: false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? const Color(0xFFE63946) : const Color(0xFF2A9D8F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Consentimiento de Emergencia', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: AppColors.azulElectrico,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Selector de Paciente
                _buildSectionTitle('Selección de Paciente'),
                const SizedBox(height: 8),
                _buildPacienteSelector(),
                const SizedBox(height: 16),

                if (_pacienteSeleccionado != null) ...[
                  _buildPacienteInfoCard(),
                  const SizedBox(height: 24),
                  
                  if (_alreadyExists) 
                    _buildDuplicateWarning()
                  else
                    _buildForm(),
                ],
              ],
            ),
          ),
      bottomNavigationBar: (_pacienteSeleccionado != null && !_alreadyExists) 
        ? _buildBottomButton() 
        : null,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.bold, 
        color: AppColors.azulElectrico,
        letterSpacing: 0.5
      ),
    );
  }

  Widget _buildPacienteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.azulCielo.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PacienteModel>(
          isExpanded: true,
          hint: const Text('Seleccione un paciente...', style: TextStyle(fontSize: 16)),
          value: _pacienteSeleccionado,
          items: _pacientes.map((p) => DropdownMenuItem(
            value: p,
            child: Text('${p.nombreCompleto} (${p.ciCompleto})', style: const TextStyle(fontSize: 16)),
          )).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _pacienteSeleccionado = val;
                _alreadyExists = false;
              });
              _checkDuplicate(val.id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPacienteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulElectrico.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.azulElectrico.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: AppColors.azulElectrico, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pacienteSeleccionado!.nombreCompleto,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.azulElectrico),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile('RUT / CI', _pacienteSeleccionado!.ciCompleto),
              _infoTile('Edad', '${_pacienteSeleccionado!.edadCalculada ?? "--"} años'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDuplicateWarning() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE63946), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Ya existe un consentimiento registrado hoy para este paciente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'No se puede registrar otro en el mismo día.',
            style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Detalles del Procedimiento'),
          const SizedBox(height: 12),

          // Procedimiento
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Procedimiento Urgente *',
              prefixIcon: Icon(Icons.medical_information_rounded),
            ),
            style: const TextStyle(fontSize: 16, color: Colors.black),
            value: _procedimiento,
            items: _procedimientos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (val) => setState(() => _procedimiento = val),
            validator: (val) => val == null ? 'Seleccione un procedimiento' : null,
          ),
          const SizedBox(height: 16),

          // Justificación
          TextFormField(
            controller: _justificacionController,
            maxLines: 4,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Justificación de Incapacidad *',
              hintText: 'Describa por qué el paciente no puede firmar...',
              alignLabelWithHint: true,
            ),
            validator: (val) => (val == null || val.isEmpty) ? 'La justificación es obligatoria' : null,
          ),
          const SizedBox(height: 12),

          // Burbujas rápidas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sugerenciasJustificacion.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                onPressed: () => _addSugerencia(s),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.azulCielo.withOpacity(0.6)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Testigo (Obligatorio)
          TextFormField(
            controller: _testigoController,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Nombre del Testigo *',
              prefixIcon: Icon(Icons.person_add_alt_1_rounded),
              hintText: 'Nombre completo del testigo',
            ),
            validator: (val) => (val == null || val.isEmpty) 
                ? 'El testigo es obligatorio en procedimientos de emergencia' 
                : null,
          ),
          const SizedBox(height: 24),

          // Fecha y Hora (Solo Lectura - Punto 2 y 3)
          TextFormField(
            key: ValueKey(_fechaHoraActual), // Forzar actualización visual si cambia el minuto
            initialValue: DateFormat('dd/MM/yyyy HH:mm').format(_fechaHoraActual),
            readOnly: true,
            enabled: false,
            style: const TextStyle(fontSize: 16, color: Colors.black), // Color sólido para lectura
            decoration: const InputDecoration(
              labelText: 'Fecha y Hora (Solo Lectura)',
              prefixIcon: Icon(Icons.lock_clock_rounded),
              fillColor: Color(0xFFE2E8F0), // Fondo ligeramente gris para denotar bloqueo
              filled: true,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _registrar,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE63946),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56), // > 48px
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: _isSaving
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('REGISTRAR CONSENTIMIENTO', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
      ),
    );
  }
}
