import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import '../models/receta_model.dart';
import '../services/receta_service.dart';

class EmisionDeRecetaMedicaScreen extends StatefulWidget {
  const EmisionDeRecetaMedicaScreen({super.key});

  @override
  State<EmisionDeRecetaMedicaScreen> createState() => _EmisionDeRecetaMedicaScreenState();
}

class _EmisionDeRecetaMedicaScreenState extends State<EmisionDeRecetaMedicaScreen> {
  final _service = RecetaService();
  List<RecetaModel> _recetas = [];
  bool _loading = true;
  String? _error;

  final _obsCtrl = TextEditingController();
  List<Map<String, TextEditingController>> _medicamentos = [];
  bool _guardando = false;
  int? _consultaIdSeleccionada;

  @override
  void initState() {
    super.initState();
    _agregarMedicamento();
    _cargar();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    for (final m in _medicamentos) {
      for (final c in m.values) { c.dispose(); }
    }
    super.dispose();
  }

  void _agregarMedicamento() {
    setState(() {
      _medicamentos.add({
        'medicamento': TextEditingController(),
        'dosis': TextEditingController(),
        'frecuencia': TextEditingController(),
        'duracion': TextEditingController(),
        'via': TextEditingController(text: 'VO'),
      });
    });
  }

  void _eliminarMedicamento(int index) {
    setState(() {
      final m = _medicamentos.removeAt(index);
      for (final c in m.values) { c.dispose(); }
    });
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.listar();
      if (!mounted) return;
      setState(() => _recetas = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardarReceta() async {
    if (_consultaIdSeleccionada == null) {
      _showSnack('Selecciona una consulta', error: true);
      return;
    }
    final detalles = _medicamentos.map((m) {
      if ((m['medicamento']?.text ?? '').isEmpty ||
          (m['dosis']?.text ?? '').isEmpty ||
          (m['frecuencia']?.text ?? '').isEmpty ||
          (m['duracion']?.text ?? '').isEmpty) {
        return null;
      }
      return DetalleRecetaModel(
        medicamento: m['medicamento']!.text,
        dosis: m['dosis']!.text,
        frecuencia: m['frecuencia']!.text,
        duracion: m['duracion']!.text,
        viaAdministracion: m['via']!.text.isEmpty ? 'VO' : m['via']!.text,
      );
    }).toList();

    if (detalles.any((d) => d == null)) {
      _showSnack('Completa todos los campos de cada medicamento', error: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      await _service.crear(
        consultaId: _consultaIdSeleccionada!,
        detalles: detalles.cast<DetalleRecetaModel>(),
        observaciones: _obsCtrl.text,
      );
      _obsCtrl.clear();
      for (final m in _medicamentos) { for (final c in m.values) { c.clear(); } }
      setState(() { _medicamentos = []; });
      _agregarMedicamento();
      _showSnack('Receta emitida correctamente');
      await _cargar();
    } catch (e) {
      _showSnack('Error al guardar receta', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _dispensar(RecetaModel r) async {
    try {
      await _service.dispensar(r.id);
      _showSnack('Receta dispensada correctamente');
      await _cargar();
    } catch (e) {
      _showSnack('Error al dispensar', error: true);
    }
  }

  Future<void> _anular(RecetaModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular receta'),
        content: Text('¿Anular ${r.numeroReceta}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Anular', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.anular(r.id);
      _showSnack('Receta anulada');
      await _cargar();
    } catch (e) {
      _showSnack('Error al anular', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : AppColors.mentaVibrante,
      ),
    );
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'EMITIDA': return AppColors.azulPuro;
      case 'DISPENSADA': return AppColors.mentaVibrante;
      case 'ANULADA': return const Color(0xFFDC2626);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Recetas Médicas'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.azulPuro,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // Panel emisión
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Panel de Emisión de Receta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azulElectrico)),
                    const SizedBox(height: 16),

                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID de Consulta *',
                        hintText: 'Ej: 1',
                        prefixIcon: Icon(Icons.assignment_rounded, color: AppColors.azulElectrico),
                      ),
                      onChanged: (v) => setState(() => _consultaIdSeleccionada = int.tryParse(v)),
                    ),
                    const SizedBox(height: 16),

                    const Text('Medicamentos',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azulElectrico)),
                    const SizedBox(height: 8),

                    ..._medicamentos.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.azulElectrico.withOpacity(0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Medicamento ${i + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const Spacer(),
                                  if (_medicamentos.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                                      onPressed: () => _eliminarMedicamento(i),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(controller: m['medicamento'],
                                decoration: const InputDecoration(labelText: 'Medicamento *', hintText: 'Ej: Amoxicilina')),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: TextField(controller: m['dosis'],
                                  decoration: const InputDecoration(labelText: 'Dosis *', hintText: '1 tableta'))),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: m['via'],
                                  decoration: const InputDecoration(labelText: 'Vía', hintText: 'VO'))),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: TextField(controller: m['frecuencia'],
                                  decoration: const InputDecoration(labelText: 'Frecuencia *', hintText: 'cada 8 horas'))),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: m['duracion'],
                                  decoration: const InputDecoration(labelText: 'Duración *', hintText: '7 días'))),
                              ]),
                            ],
                          ),
                        ),
                      );
                    }),

                    TextButton.icon(
                      onPressed: _agregarMedicamento,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Añadir otro medicamento'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.azulElectrico),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        hintText: 'Indicaciones adicionales...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : _guardarReceta,
                        icon: _guardando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_guardando ? 'Guardando...' : 'Guardar Receta como Emitida'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.azulElectrico,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text('Recetas Emitidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azulElectrico)),
            const SizedBox(height: 12),

            if (_loading)
              const LoadingIndicator(message: 'Cargando recetas...')
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_recetas.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No hay recetas disponibles',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ],
                ),
              )
            else
              ..._recetas.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.numeroReceta,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                color: AppColors.azulElectrico)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _estadoColor(r.estado).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(r.estado,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: _estadoColor(r.estado))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${r.detalles.length} medicamento${r.detalles.length != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      if (r.fechaDispensacion != null)
                        Text('Dispensada: ${r.fechaDispensacion}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mentaVibrante)),
                      const SizedBox(height: 12),

                      ...r.detalles.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: AppColors.azulElectrico, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${d.medicamento} ${d.concentracion}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Dosis: ${d.dosis} | Vía: ${d.viaAdministracion} | ${d.frecuencia} | ${d.duracion}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      )),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (r.estado == 'EMITIDA') ...[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _dispensar(r),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: const Text('Registrar dispensación'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.mentaVibrante,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (r.estado != 'DISPENSADA')
                            OutlinedButton.icon(
                              onPressed: () => _anular(r),
                              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                              label: const Text('Anular', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}