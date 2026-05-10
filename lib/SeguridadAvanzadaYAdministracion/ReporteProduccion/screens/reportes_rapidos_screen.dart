import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import '../services/reporte_service.dart';

// ── Opciones de tipo de reporte ──────────────────────────────────────────────

const _kTipos = <_Opcion>[
  _Opcion('Resumen General', 'resumen_general'),
  _Opcion('Consultas',       'consultas'),
  _Opcion('Triajes',         'triajes'),
  _Opcion('Recetas',         'recetas'),
];

const _kNiveles = <_Opcion>[
  _Opcion('Todos',    'Todos'),
  _Opcion('🔴 Rojo',     'ROJO'),
  _Opcion('🟠 Naranja',  'NARANJA'),
  _Opcion('🟡 Amarillo', 'AMARILLO'),
  _Opcion('🟢 Verde',    'VERDE'),
  _Opcion('🔵 Azul',     'AZUL'),
];

class _Opcion {
  const _Opcion(this.label, this.value);
  final String label;
  final String value;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportesRapidosScreen extends StatefulWidget {
  final UserModel user;
  const ReportesRapidosScreen({super.key, required this.user});

  @override
  State<ReportesRapidosScreen> createState() => _ReportesRapidosScreenState();
}

class _ReportesRapidosScreenState extends State<ReportesRapidosScreen> {
  final _service      = ReporteService();
  final _stt          = stt.SpeechToText();
  final _qCtrl        = TextEditingController();

  String _rango         = 'Hoy';
  DateTime _fechaDesde  = DateTime.now();
  DateTime _fechaHasta  = DateTime.now();
  String _tipoReporte   = 'resumen_general';
  String _nivelUrgencia = 'Todos';

  bool _isListening    = false;
  bool _loadingPreview = false;
  bool _exporting      = false;

  Map<String, dynamic>? _resultado;

  @override
  void initState() {
    super.initState();
    _setRango('Hoy');
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  void _setRango(String rango) {
    final now = DateTime.now();
    setState(() {
      _rango = rango;
      if (rango == 'Hoy') {
        _fechaDesde = DateTime(now.year, now.month, now.day);
        _fechaHasta = now;
      } else if (rango == 'Esta semana') {
        _fechaDesde = now.subtract(Duration(days: now.weekday - 1));
        _fechaHasta = now;
      } else if (rango == 'Este mes') {
        _fechaDesde = DateTime(now.year, now.month, 1);
        _fechaHasta = now;
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
        _rango      = 'Personalizado';
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final available = await _stt.initialize(
        onError: (e) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() {
                _qCtrl.text = val.recognizedWords;
                _isListening = false;
              });
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
    setState(() { _loadingPreview = true; _resultado = null; });
    try {
      final data = await _service.previsualizar(
        fechaDesde:   DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:   DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:  _tipoReporte,
        nivelUrgencia: _nivelUrgencia,
        q:            _qCtrl.text,
      );
      setState(() { _resultado = data; _loadingPreview = false; });
    } catch (e) {
      setState(() => _loadingPreview = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportar(String formato) async {
    setState(() => _exporting = true);
    try {
      final file = await _service.exportar(
        formato:       formato,
        fechaDesde:    DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:    DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:   _tipoReporte,
        nivelUrgencia: _nivelUrgencia,
        q:             _qCtrl.text,
      );
      setState(() => _exporting = false);
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de producción');
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
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
            onPressed: () => setState(() {
              _qCtrl.clear();
              _tipoReporte   = 'resumen_general';
              _nivelUrgencia = 'Todos';
              _resultado     = null;
              _setRango('Hoy');
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Período'),
            const SizedBox(height: 10),
            _buildRangoChips(),
            const SizedBox(height: 8),
            _buildDateDisplay(),

            const SizedBox(height: 20),
            _SectionTitle('Tipo de reporte'),
            const SizedBox(height: 10),
            _buildTipoChips(),

            const SizedBox(height: 20),
            _SectionTitle('Filtrar por nivel de urgencia'),
            const SizedBox(height: 10),
            _buildNivelDropdown(),

            const SizedBox(height: 20),
            _SectionTitle('Búsqueda por texto / voz'),
            const SizedBox(height: 10),
            _buildQField(),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _loadingPreview ? null : _aplicarFiltros,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Aplicar filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azulElectrico,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 28),
            _SectionTitle('Resultados'),
            const SizedBox(height: 10),
            _buildResultado(),

            const SizedBox(height: 28),
            _SectionTitle('Exportar'),
            const SizedBox(height: 12),
            _buildExportButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Rango ─────────────────────────────────────────────────────────────────

  Widget _buildRangoChips() {
    final opciones = ['Hoy', 'Esta semana', 'Este mes', 'Personalizado'];
    return Wrap(
      spacing: 8,
      children: opciones.map((r) {
        final sel = _rango == r;
        return ChoiceChip(
          label: Text(r, style: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 12)),
          selected: sel,
          selectedColor: AppColors.azulElectrico,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          onSelected: (_) {
            if (r == 'Personalizado') {
              _pickDateRange();
            } else {
              _setRango(r);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateDisplay() {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.azulCielo),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, size: 18, color: AppColors.azulElectrico),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${fmt.format(_fechaDesde)} — ${fmt.format(_fechaHasta)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── Tipo de reporte ────────────────────────────────────────────────────────

  Widget _buildTipoChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kTipos.map((op) {
        final sel = _tipoReporte == op.value;
        return ChoiceChip(
          label: Text(op.label, style: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 12)),
          selected: sel,
          selectedColor: AppColors.azulElectrico,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          onSelected: (_) => setState(() { _tipoReporte = op.value; _resultado = null; }),
        );
      }).toList(),
    );
  }

  // ── Nivel de urgencia ─────────────────────────────────────────────────────

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
          items: _kNiveles.map((op) => DropdownMenuItem(
            value: op.value,
            child: Text(op.label, style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (v) => setState(() { _nivelUrgencia = v!; _resultado = null; }),
        ),
      ),
    );
  }

  // ── Campo Q (texto + voz) ─────────────────────────────────────────────────

  Widget _buildQField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _qCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ej: triajes de esta semana, recetas de Juan…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              suffixIcon: _qCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _qCtrl.clear()))
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _listen,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : AppColors.mentaVibrante,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ── Resultado ─────────────────────────────────────────────────────────────

  Widget _buildResultado() {
    if (_loadingPreview) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: LoadingIndicator(message: 'Cargando...')));
    }
    if (_resultado == null) {
      return _EmptyState(message: 'Aplica filtros para ver resultados');
    }

    final resumen   = _resultado!['resumen']      as Map<String, dynamic>?;
    final detalle   = (_resultado!['detalle']     as List?)?.cast<Map<String, dynamic>>() ?? [];
    final advertencias = (_resultado!['advertencias'] as List?)?.cast<String>() ?? [];
    final triajePorNivel = (_resultado!['triajes_por_nivel'] as List?)?.cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (advertencias.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: advertencias.map((a) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a, style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                ],
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (resumen != null) _buildResumenCards(resumen),

        if (triajePorNivel != null && triajePorNivel.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Triajes por nivel'),
          const SizedBox(height: 8),
          _buildTriajeNiveles(triajePorNivel),
        ],

        if (detalle.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _SectionTitle('Detalle'),
              const Spacer(),
              Text('${detalle.length} registros', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetalleList(detalle),
        ] else if (resumen != null) ...[
          const SizedBox(height: 16),
          _EmptyState(message: 'Sin registros para los filtros aplicados'),
        ],
      ],
    );
  }

  Widget _buildResumenCards(Map<String, dynamic> resumen) {
    final items = <_ResumenItem>[
      _ResumenItem('Consultas',  '${resumen['total_consultas'] ?? 0}',   Icons.medical_services_outlined, AppColors.azulElectrico),
      _ResumenItem('Triajes',    '${resumen['total_triajes'] ?? 0}',     Icons.monitor_heart_outlined,    Colors.orange),
      _ResumenItem('Recetas',    '${resumen['total_recetas_emitidas'] ?? 0}', Icons.receipt_long_outlined, Colors.green.shade700),
      _ResumenItem('Derivados',  '${resumen['total_recetas_dispensadas'] ?? 0}', Icons.local_pharmacy_outlined, Colors.purple),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: item.color)),
                  Text(item.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTriajeNiveles(List<Map<String, dynamic>> niveles) {
    final colores = const {
      'ROJO':     Color(0xFFDC2626),
      'NARANJA':  Color(0xFFEA580C),
      'AMARILLO': Color(0xFFD97706),
      'VERDE':    Color(0xFF16A34A),
      'AZUL':     Color(0xFF2563EB),
    };
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: niveles.where((n) => (n['total'] as int? ?? 0) > 0).map((n) {
          final nivel = n['nivel_urgencia'] as String? ?? '';
          final total = n['total'] as int? ?? 0;
          final pct   = n['porcentaje'] as double? ?? 0.0;
          final color = colores[nivel] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(nivel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text('$total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 6),
                Text('($pct%)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetalleList(List<Map<String, dynamic>> detalle) {
    final visible = detalle.take(10).toList();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          ...visible.asMap().entries.map((e) {
            final i   = e.key;
            final row = e.value;
            final titulo   = row['paciente'] as String? ?? row['numero_receta'] as String? ?? '—';
            final subtitulo = [
              row['fecha_consulta'] ?? row['fecha'] ?? row['fecha_emision'],
              row['nivel_urgencia'],
              row['estado'],
              row['medico'],
            ].whereType<String>().where((s) => s.isNotEmpty).take(3).join(' · ');
            return Column(
              children: [
                if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.azulCielo,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.azulElectrico)),
                  ),
                  title: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: subtitulo.isNotEmpty ? Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                ),
              ],
            );
          }),
          if (detalle.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Mostrando 10 de ${detalle.length} registros · Exporta para ver todos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Exportar ─────────────────────────────────────────────────────────────

  Widget _buildExportButtons() {
    if (_exporting) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: LoadingIndicator(message: 'Generando archivo...')));
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ResumenItem {
  const _ResumenItem(this.label, this.valor, this.icon, this.color);
  final String label;
  final String valor;
  final IconData icon;
  final Color color;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.azulElectrico, letterSpacing: 0.3),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.color, required this.icon, required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
