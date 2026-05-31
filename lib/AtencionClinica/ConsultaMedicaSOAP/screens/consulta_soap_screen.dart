import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consulta_model.dart';
import '../services/consulta_service.dart';
import '../widgets/soap_section.dart';
import '../widgets/cie10_search_field.dart';

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

class _ConsultaSoapScreenState extends State<ConsultaSoapScreen> {
  final ConsultaService _service = ConsultaService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _subjetivoController = TextEditingController();
  final TextEditingController _objetivoController = TextEditingController();
  final TextEditingController _analisisController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  
  ConsultaMedica? _consulta;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _selectedCie10;
  String? _cie10Error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print("DEBUG: _loadData iniciado. fichaId: ${widget.fichaId}, consultaId: ${widget.consultaId}");
    setState(() => _isLoading = true);
    try {
      if (widget.consultaId != null) {
        print("DEBUG: Obteniendo consulta por ID: ${widget.consultaId}");
        _consulta = await _service.getById(widget.consultaId!);
      } else if (widget.fichaId != null) {
        print("DEBUG: Creando nueva consulta para ficha: ${widget.fichaId}");
        try {
          _consulta = await _service.create(widget.fichaId!);
        } catch (e) {
          print("DEBUG: Error al crear en servidor, activando MODO DEMO: $e");
          // Si falla el servidor (por permisos 403 o red), creamos un objeto local para la demo
          _consulta = ConsultaMedica(
            id: -1, // ID negativo indica modo demo
            pacienteId: widget.initialData['paciente_id'] ?? 0,
            pacienteNombre: widget.initialData['paciente_nombre'] ?? 'Paciente de Prueba',
            subjetivo: '',
            objetivo: '',
            analisis: '',
            plan: '',
            estado: EstadoConsulta.borrador,
            fechaCreacion: DateTime.now(),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servidor no disponible o sin permisos. Entrando en MODO DEMO para previsualización.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (_consulta != null) {
        print("DEBUG: Consulta cargada exitosamente: ${_consulta!.id}");
        _subjetivoController.text = _consulta!.subjetivo;
        _objetivoController.text = _consulta!.objetivo;
        _analisisController.text = _consulta!.analisis;
        _planController.text = _consulta!.plan;
        _selectedCie10 = _consulta!.diagnosticoPrincipal;

        // Si el objetivo está vacío, intentar cargar signos vitales
        if (_objetivoController.text.isEmpty && _consulta!.pacienteId != 0) {
          try {
            final triaje = await _service.getUltimoTriaje(_consulta!.pacienteId);
            if (triaje != null) {
              final sv = "Signos Vitales: FC: ${triaje['frecuencia_cardiaca']} lpm, PA: ${triaje['presion_arterial_sistolica']}/${triaje['presion_arterial_diastolica']} mmHg, T°: ${triaje['temperatura']} °C, SpO2: ${triaje['saturacion_oxigeno']}%\n\n";
              _objetivoController.text = sv;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print("DEBUG: EXCEPCIÓN crítica en _loadData: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBorrador() async {
    if (_consulta == null || !_consulta!.isEditable) return;
    
    setState(() => _isSaving = true);
    try {
      final data = {
        'motivo_consulta': _subjetivoController.text,
        'examen_fisico': _objetivoController.text,
        'impresion_diagnostica': _analisisController.text,
        'plan_tratamiento': _planController.text,
        'codigo_cie10_principal': _selectedCie10?['codigo'],
        'descripcion_cie10': _selectedCie10?['descripcion'],
      };
      
      if (_consulta!.id < 0) {
        // MODO DEMO: Simular guardado local
        await Future.delayed(const Duration(milliseconds: 600));
        _consulta = ConsultaMedica(
          id: _consulta!.id,
          pacienteId: _consulta!.pacienteId,
          pacienteNombre: _consulta!.pacienteNombre,
          subjetivo: data['motivo_consulta'] as String,
          objetivo: data['examen_fisico'] as String,
          analisis: data['impresion_diagnostica'] as String,
          plan: data['plan_tratamiento'] as String,
          diagnosticoPrincipal: _selectedCie10,
          estado: _consulta!.estado,
          fechaCreacion: _consulta!.fechaCreacion,
        );
      } else {
        _consulta = await _service.update(_consulta!.id, data);
      }

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado con éxito')),
      );
    } catch (e) {
      print("DEBUG: Error al guardar borrador: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _completarConsulta() async {
    if (_consulta == null || !_consulta!.isEditable) return;

    setState(() => _cie10Error = _selectedCie10 == null ? "Debe seleccionar un diagnóstico CIE-10" : null);

    if (!_formKey.currentState!.validate() || _selectedCie10 == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar"),
        content: const Text("¿Desea marcar esta consulta como COMPLETADA? Una vez completada, no podrá editar los campos."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("COMPLETAR"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'motivo_consulta': _subjetivoController.text,
        'examen_fisico': _objetivoController.text,
        'impresion_diagnostica': _analisisController.text,
        'plan_tratamiento': _planController.text,
        'codigo_cie10_principal': _selectedCie10?['codigo'],
        'descripcion_cie10': _selectedCie10?['descripcion'],
      };

      if (_consulta!.id < 0) {
        // MODO DEMO: Simular completar local
        await Future.delayed(const Duration(milliseconds: 800));
        _consulta = ConsultaMedica(
          id: _consulta!.id,
          pacienteId: _consulta!.pacienteId,
          pacienteNombre: _consulta!.pacienteNombre,
          subjetivo: data['motivo_consulta'] as String,
          objetivo: data['examen_fisico'] as String,
          analisis: data['impresion_diagnostica'] as String,
          plan: data['plan_tratamiento'] as String,
          diagnosticoPrincipal: _selectedCie10,
          estado: EstadoConsulta.completada,
          fechaCreacion: _consulta!.fechaCreacion,
        );
      } else {
        // Primero guardar cambios actuales
        await _service.update(_consulta!.id, data);
        _consulta = await _service.completar(_consulta!.id);
      }

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta completada con éxito'), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("DEBUG: Error al completar consulta: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al completar consulta: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _getStatusColor(EstadoConsulta estado) {
    switch (estado) {
      case EstadoConsulta.borrador: return Colors.amber[100]!;
      case EstadoConsulta.completada: return Colors.green[100]!;
      case EstadoConsulta.firmada: return Colors.blue[100]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _consulta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro de Consulta SOAP", style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                _buildPatientInfo(),
                const SizedBox(height: 20),
                
                // SOAP Sections
                SoapSection(
                  title: "Subjetivo (S)",
                  icon: Icons.person_outline,
                  controller: _subjetivoController,
                  placeholder: "Motivo de consulta, síntomas, historia actual...",
                  isReadOnly: !_consulta!.isEditable,
                ),
                SoapSection(
                  title: "Objetivo (O)",
                  icon: Icons.visibility_outlined,
                  controller: _objetivoController,
                  placeholder: "Signos vitales, hallazgos del examen físico...",
                  isReadOnly: !_consulta!.isEditable,
                ),
                SoapSection(
                  title: "Evaluación (A)",
                  icon: Icons.analytics_outlined,
                  controller: _analisisController,
                  placeholder: "Diagnóstico diferencial, análisis clínico...",
                  isReadOnly: !_consulta!.isEditable,
                  validator: (v) => v == null || v.isEmpty ? "La evaluación es obligatoria" : null,
                ),
                
                // CIE-10 Search
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Cie10SearchField(
                      initialValue: _selectedCie10,
                      isReadOnly: !_consulta!.isEditable,
                      errorText: _cie10Error,
                      onSelected: (val) => setState(() {
                        _selectedCie10 = val;
                        _cie10Error = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                SoapSection(
                  title: "Plan (P)",
                  icon: Icons.assignment_outlined,
                  controller: _planController,
                  placeholder: "Tratamiento, indicaciones, seguimiento...",
                  isReadOnly: !_consulta!.isEditable,
                ),

                const SizedBox(height: 24),
                
                // Main Actions
                if (_consulta!.isEditable) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _saveBorrador,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Guardar Borrador"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _completarConsulta,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Completar Consulta"),
                        ),
                      ),
                    ],
                  ),
                ] else 
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Consulta en modo lectura", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                
                // Navigation Actions
                const Text("Navegación Rápida", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _navButton("Receta", Icons.medication_outlined, () {}),
                    _navButton("Órdenes", Icons.file_copy_outlined, () {}),
                    _navButton("Triaje Previo", Icons.monitor_heart_outlined, () {}),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfo() {
    if (_consulta == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[600],
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _consulta?.pacienteNombre ?? widget.initialData['paciente_nombre'] ?? 'Paciente',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text("ID: ${_consulta?.pacienteId ?? widget.initialData['paciente_id'] ?? 'N/A'}", style: TextStyle(color: Colors.blue[800], fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(_consulta!.estado),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              _consulta!.estado.name.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
    );
  }
}
