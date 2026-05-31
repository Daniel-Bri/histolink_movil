import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import '../services/reporte_service.dart';

// Tipos de reporte: display → valor API
const _kTipos = {
  'Resumen General': 'resumen_general',
  'Consultas': 'consultas',
  'Triajes': 'triajes',
  'Recetas': 'recetas',
};

const _kNiveles = ['Todos', 'ROJO', 'NARANJA', 'AMARILLO', 'VERDE', 'AZUL'];

Color _nivelColor(String n) => switch (n.toUpperCase()) {
      'ROJO'     => const Color(0xFFDC2626),
      'NARANJA'  => const Color(0xFFEA580C),
      'AMARILLO' => const Color(0xFFD97706),
      'VERDE'    => const Color(0xFF16A34A),
      'AZUL'     => const Color(0xFF2563EB),
      _          => Colors.grey,
    };

class ReportesRapidosScreen extends StatefulWidget {
  final UserModel user;
  const ReportesRapidosScreen({super.key, required this.user});

  @override
  State<ReportesRapidosScreen> createState() => _ReportesRapidosScreenState();
}

class _ReportesRapidosScreenState extends State<ReportesRapidosScreen> {
  final _service = ReporteService();
  final _stt = stt.SpeechToText();
  final _qCtrl = TextEditingController();

  String _rangoSeleccionado = 'Hoy';
  DateTime _fechaDesde = DateTime.now();
  DateTime _fechaHasta = DateTime.now();
  String _tipoDisplaySelected = 'Resumen General';
  String _nivelUrgencia = 'Todos';

  bool _isListening    = false;
  bool _loadingPreview = false;
  bool _exporting      = false;
  Map<String, dynamic>? _reporteData;

  @override
  void initState() {
    super.initState();
    _setRango('Hoy');
    _loadFilters();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rangoSeleccionado   = prefs.getString('rpt_rango') ?? 'Hoy';
      _tipoDisplaySelected = prefs.getString('rpt_tipo')  ?? 'Resumen General';
      _nivelUrgencia       = prefs.getString('rpt_nivel') ?? 'Todos';
      _qCtrl.text          = prefs.getString('rpt_q')     ?? '';
      if (_rangoSeleccionado == 'Personalizado') {
        final d = prefs.getString('rpt_desde');
        final h = prefs.getString('rpt_hasta');
        if (d != null) _fechaDesde = DateTime.parse(d);
        if (h != null) _fechaHasta = DateTime.parse(h);
      } else {
        _setRango(_rangoSeleccionado);
      }
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rpt_rango', _rangoSeleccionado);
    await prefs.setString('rpt_tipo',  _tipoDisplaySelected);
    await prefs.setString('rpt_nivel', _nivelUrgencia);
    await prefs.setString('rpt_q',     _qCtrl.text);
    if (_rangoSeleccionado == 'Personalizado') {
      await prefs.setString('rpt_desde', _fechaDesde.toIso8601String());
      await prefs.setString('rpt_hasta', _fechaHasta.toIso8601String());
    }
  }

  void _setRango(String rango) {
    final now = DateTime.now();
    setState(() {
      _rangoSeleccionado = rango;
      switch (rango) {
        case 'Hoy':
          _fechaDesde = DateTime(now.year, now.month, now.day);
          _fechaHasta = now;
        case 'Esta semana':
          _fechaDesde = now.subtract(Duration(days: now.weekday - 1));
          _fechaHasta = now;
        case 'Este mes':
          _fechaDesde = DateTime(now.year, now.month, 1);
          _fechaHasta = now;
        default:
          break;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaDesde, end: _fechaHasta),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.azulElectrico),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _rangoSeleccionado = 'Personalizado';
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final available = await _stt.initialize(
        onStatus: (_) {},
        onError:  (_) {},
      );
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() {
                _qCtrl.text = (_qCtrl.text + ' ${val.recognizedWords}').trim();
                _isListening = false;
              });
              _saveFilters();
            }
          },
          localeId: 'es_BO',
        );
      } else {
        final status = await Permission.microphone.request();
        if (mounted && status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de micrófono denegado')),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _stt.stop();
    }
  }

  Future<void> _aplicarFiltros() async {
    setState(() {
      _loadingPreview = true;
      _reporteData    = null;
    });
    _saveFilters();
    try {
      final tipoApi = _kTipos[_tipoDisplaySelected] ?? 'resumen_general';
      final data = await _service.previsualizar(
        fechaDesde:    DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:    DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:   tipoApi,
        nivelUrgencia: _nivelUrgencia == 'Todos' ? null : _nivelUrgencia,
        q:             _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      );
      if (mounted) setState(() => _reporteData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _exportar(String formato) async {
    setState(() => _exporting = true);
    try {
      final tipoApi = _kTipos[_tipoDisplaySelected] ?? 'resumen_general';
      final file = await _service.exportar(
        formato:       formato,
        fechaDesde:    DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:    DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:   tipoApi,
        nivelUrgencia: _nivelUrgencia == 'Todos' ? null : _nivelUrgencia,
        q:             _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      );
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Reporte de $_tipoDisplaySelected',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: widget.user, activeLabel: 'Reportes'),
      appBar: AppBar(
        title: const Text('Reportes de Producción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Limpiar',
            onPressed: () {
              setState(() {
                _qCtrl.clear();
                _tipoDisplaySelected = 'Resumen General';
                _nivelUrgencia       = 'Todos';
                _reporteData         = null;
                _setRango('Hoy');
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Rango de fechas'),
            const SizedBox(height: 8),
            _buildDateChips(),
            if (_rangoSeleccionado == 'Personalizado') ...[
              const SizedBox(height: 8),
              _buildDateDisplay(),
            ],
            const SizedBox(height: 16),
            _sectionTitle('Tipo de reporte'),
            const SizedBox(height: 8),
            _buildTipoChips(),
            const SizedBox(height: 16),
            _sectionTitle('Nivel de urgencia'),
            const SizedBox(height: 8),
            _buildNivelDropdown(),
            const SizedBox(height: 16),
            _sectionTitle('Búsqueda por texto / voz'),
            const SizedBox(height: 8),
            _buildSpeechField(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadingPreview ? null : _aplicarFiltros,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Aplicar filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulElectrico,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Resultados'),
            const SizedBox(height: 8),
            _buildPreviewArea(),
            const SizedBox(height: 20),
            _sectionTitle('Exportar'),
            const SizedBox(height: 8),
            _buildExportButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.azulElectrico,
          letterSpacing: 0.4,
        ),
      );

  Widget _buildDateChips() {
    const ranges = ['Hoy', 'Esta semana', 'Este mes', 'Personalizado'];
    return Wrap(
      spacing: 8,
      children: ranges.map((r) {
        final sel = _rangoSeleccionado == r;
        return ChoiceChip(
          label: Text(r, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
          selected: sel,
          selectedColor: AppColors.azulElectrico,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          onSelected: (_) => r == 'Personalizado' ? _pickDateRange() : _setRango(r),
        );
      }).toList(),
    );
  }

  Widget _buildDateDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.azulCielo),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 18, color: AppColors.azulElectrico),
          const SizedBox(width: 10),
          Text(
            '${DateFormat('dd/MM/yyyy').format(_fechaDesde)} — ${DateFormat('dd/MM/yyyy').format(_fechaHasta)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _kTipos.keys.map((display) {
        final sel = _tipoDisplaySelected == display;
        return ChoiceChip(
          label: Text(display, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
          selected: sel,
          selectedColor: AppColors.mentaVibrante,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          onSelected: (_) => setState(() {
            _tipoDisplaySelected = display;
            _saveFilters();
          }),
        );
      }).toList(),
    );
  }

  Widget _buildNivelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _nivelUrgencia,
          isExpanded: true,
          items: _kNiveles.map((n) {
            final isColor = n != 'Todos';
            return DropdownMenuItem(
              value: n,
              child: Row(
                children: [
                  if (isColor) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: _nivelColor(n), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(n, style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() {
            _nivelUrgencia = v!;
            _saveFilters();
          }),
        ),
      ),
    );
  }

  Widget _buildSpeechField() {
    return Column(
      children: [
        TextField(
          controller: _qCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Escribe o usa el micrófono…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            suffixIcon: GestureDetector(
              onTap: _listen,
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : AppColors.mentaVibrante,
                  shape: BoxShape.circle,
                ),
                child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
        if (_isListening)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Escuchando...', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    if (_loadingPreview) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: LoadingIndicator(message: 'Cargando reporte...')));
    }

    if (_reporteData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Aplica filtros para ver el reporte', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    final resumen      = _reporteData!['resumen']          as Map<String, dynamic>? ?? {};
    final advertencias = (_reporteData!['advertencias']    as List?)?.cast<String>() ?? [];
    final triajes      = (_reporteData!['triajes_por_nivel'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final detalle      = (_reporteData!['detalle']         as List?)?.cast<Map<String, dynamic>>() ?? [];
    final periodo      = _reporteData!['periodo']          as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...advertencias.map(
          (a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(a, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
              ],
            ),
          ),
        ),

        if (periodo['desde'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Período: ${periodo['desde']} → ${periodo['hasta']}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _ResumenCard('Consultas', resumen['total_consultas'] ?? 0, Icons.assignment_outlined, AppColors.azulElectrico),
            _ResumenCard('Triajes', resumen['total_triajes'] ?? 0, Icons.monitor_heart_outlined, const Color(0xFF7C3AED)),
            _ResumenCard('Recetas emitidas', resumen['total_recetas_emitidas'] ?? 0, Icons.medication_outlined, Colors.green.shade700),
            _ResumenCard('Derivaciones', '${resumen['tasa_derivacion_pct'] ?? 0}%', Icons.call_missed_outgoing_rounded, Colors.orange.shade700),
          ],
        ),

        if (triajes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Triajes por nivel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          ...triajes.where((t) => (t['total'] as int? ?? 0) > 0).map(
            (t) {
              final nivel = t['nivel_urgencia'] as String? ?? '';
              final total = t['total'] as int? ?? 0;
              final pct   = (t['porcentaje'] as num?)?.toDouble() ?? 0.0;
              final color = _nivelColor(nivel);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(nivel, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('$total ($pct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
        ],

        if (detalle.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Detalle (${detalle.length} registros)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: detalle.take(8).map((row) {
                final paciente = row['paciente'] as String? ?? '';
                final fecha    = row['fecha_consulta'] ?? row['fecha'] ?? row['fecha_emision'] ?? '';
                final subtexto = row['medico'] as String? ?? row['nivel_urgencia'] as String? ?? row['estado'] as String? ?? '';
                return ListTile(
                  dense: true,
                  title: Text(paciente.isNotEmpty ? paciente : (row.values.firstOrNull?.toString() ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  subtitle: Text(subtexto.isNotEmpty ? subtexto : fecha.toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  trailing: fecha.isNotEmpty && subtexto.isNotEmpty
                      ? Text(fecha.toString().substring(0, fecha.toString().length.clamp(0, 10)), style: TextStyle(fontSize: 10, color: Colors.grey.shade500))
                      : null,
                );
              }).toList(),
            ),
          ),
          if (detalle.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Exporta para ver todos los ${detalle.length} registros', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ),
        ],
      ],
    );
  }

  Widget _buildExportButtons() {
    if (_exporting) {
      return const Center(child: LoadingIndicator(message: 'Generando archivo...'));
    }
    return Row(
      children: [
        Expanded(child: _ExportButton(label: 'CSV',   color: Colors.green.shade700,  icon: Icons.description_outlined,    onTap: () => _exportar('csv'))),
        const SizedBox(width: 8),
        Expanded(child: _ExportButton(label: 'Excel', color: Colors.blue.shade700,   icon: Icons.table_view_outlined,     onTap: () => _exportar('excel'))),
        const SizedBox(width: 8),
        Expanded(child: _ExportButton(label: 'PDF',   color: Colors.red.shade700,    icon: Icons.picture_as_pdf_outlined, onTap: () => _exportar('pdf'))),
      ],
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final String label;
  final Object value;
  final IconData icon;
  final Color color;

  const _ResumenCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.color, required this.icon, required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
