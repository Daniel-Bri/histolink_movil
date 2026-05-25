import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/IA_Blockchain/PrediccionDeRiesgosClinicos/services/riesgo_service.dart';
import 'package:histolink/IA_Blockchain/PrediccionDeRiesgosClinicos/widgets/riesgo_clinico_widget.dart';

class PrediccionDeRiesgosClinicosScreen extends StatefulWidget {
  const PrediccionDeRiesgosClinicosScreen({super.key, this.pacienteId});

  /// ID del paciente a analizar. Si es null, la pantalla muestra un campo de
  /// búsqueda manual para ingresar el ID.
  final int? pacienteId;

  @override
  State<PrediccionDeRiesgosClinicosScreen> createState() =>
      _PrediccionDeRiesgosClinicosScreenState();
}

class _PrediccionDeRiesgosClinicosScreenState
    extends State<PrediccionDeRiesgosClinicosScreen> {
  final _service = RiesgoService();
  final _idController = TextEditingController();

  int? _pacienteId;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _pacienteId = widget.pacienteId;
    if (_pacienteId != null) {
      _idController.text = _pacienteId.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = _pacienteId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await _service.obtenerRiesgo(id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on RiesgoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onAnalizar() {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un ID de paciente válido (número entero).'),
        ),
      );
      return;
    }
    setState(() => _pacienteId = id);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Alertas de Riesgo Clínico'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Calculando riesgo con IA…')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Banner IA ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.azulElectrico, Color(0xFF5C35CC)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.psychology_rounded,
                          color: Colors.white, size: 30),
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
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Campo de búsqueda de paciente ────────────────────────
                Container(
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
                        'Paciente a analizar',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _idController,
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _onAnalizar(),
                              decoration: InputDecoration(
                                hintText: 'ID del paciente (ej: 42)',
                                prefixIcon: const Icon(
                                    Icons.person_search_outlined,
                                    size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: _onAnalizar,
                            icon: const Icon(Icons.biotech_rounded, size: 18),
                            label: const Text('Analizar'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.azulElectrico,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Error ────────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.azulElectrico,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],

                // ── Resultados ───────────────────────────────────────────
                if (_data != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Resultados del análisis',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      Text(
                        'Paciente #$_pacienteId',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Widget principal de riesgo
                  RiesgoClinicoWidget(data: _data!),

                  const SizedBox(height: 20),

                  // Leyenda de colores
                  const _LeyendaColores(),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leyenda de colores semánticos

class _LeyendaItem {
  const _LeyendaItem({required this.color, required this.label});
  final Color color;
  final String label;
}

class _LeyendaColores extends StatelessWidget {
  const _LeyendaColores();

  static const _items = [
    _LeyendaItem(color: Colors.purple, label: 'Crítico'),
    _LeyendaItem(color: Colors.red, label: 'Alto'),
    _LeyendaItem(color: Colors.orange, label: 'Moderado'),
    _LeyendaItem(color: Colors.green, label: 'Bajo'),
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
