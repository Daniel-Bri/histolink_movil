import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import '../services/reporte_service.dart';

class ReportesRapidosScreen extends StatefulWidget {
  final UserModel user;
  const ReportesRapidosScreen({super.key, required this.user});

  @override
  State<ReportesRapidosScreen> createState() => _ReportesRapidosScreenState();
}

class _ReportesRapidosScreenState extends State<ReportesRapidosScreen> {
  final _service = ReporteService();
  final _stt = stt.SpeechToText();
  final _textoLibreCtrl = TextEditingController();

  // Estados de filtros
  String _rangoSeleccionado = 'Hoy';
  DateTime _fechaDesde = DateTime.now();
  DateTime _fechaHasta = DateTime.now();
  String _tipoReporte = 'Atenciones';
  String _estado = 'Todos';

  bool _isListening = false;
  bool _loadingPreview = false;
  bool _exporting = false;
  List<Map<String, dynamic>> _previewData = [];

  final List<String> _tipos = ['Atenciones', 'Fichas', 'Usuarios', 'Inventario'];
  final List<String> _estados = ['Todos', 'Pendientes', 'Finalizados', 'Cancelados'];

  @override
  void initState() {
    super.initState();
    _setRango('Hoy');
    _loadFilters();
    _checkPermissions();
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rangoSeleccionado = prefs.getString('report_rango') ?? 'Hoy';
      _tipoReporte = prefs.getString('report_tipo') ?? 'Atenciones';
      _estado = prefs.getString('report_estado') ?? 'Todos';
      _textoLibreCtrl.text = prefs.getString('report_texto') ?? '';
      
      if (_rangoSeleccionado != 'Personalizado') {
        _setRango(_rangoSeleccionado);
      } else {
        final desde = prefs.getString('report_fecha_desde');
        final hasta = prefs.getString('report_fecha_hasta');
        if (desde != null) _fechaDesde = DateTime.parse(desde);
        if (hasta != null) _fechaHasta = DateTime.parse(hasta);
      }
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('report_rango', _rangoSeleccionado);
    await prefs.setString('report_tipo', _tipoReporte);
    await prefs.setString('report_estado', _estado);
    await prefs.setString('report_texto', _textoLibreCtrl.text);
    if (_rangoSeleccionado == 'Personalizado') {
      await prefs.setString('report_fecha_desde', _fechaDesde.toIso8601String());
      await prefs.setString('report_fecha_hasta', _fechaHasta.toIso8601String());
    }
  }

  void _clearAll() async {
    setState(() {
      _textoLibreCtrl.clear();
      _tipoReporte = 'Atenciones';
      _estado = 'Todos';
      _previewData = [];
      _setRango('Hoy');
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _checkPermissions() {
    final allowedRoles = ['Administrador', 'Médico', 'Jefe de enfermería', 'Director'];
    if (!allowedRoles.contains(widget.user.role)) {
      // En un caso real, esto se manejaría antes de navegar, 
      // pero aquí mostramos un mensaje por seguridad.
    }
  }

  void _setRango(String rango) {
    final now = DateTime.now();
    setState(() {
      _rangoSeleccionado = rango;
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
    if (rango != 'Personalizado') _saveFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaDesde, end: _fechaHasta),
    );
    if (picked != null) {
      setState(() {
        _rangoSeleccionado = 'Personalizado';
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
      _saveFilters();
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _stt.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(
          onResult: (val) => setState(() {
            if (val.finalResult) {
              _textoLibreCtrl.text += ' ${val.recognizedWords}';
              _isListening = false;
              _saveFilters();
            }
          }),
          localeId: 'es_BO',
        );
      } else {
        var status = await Permission.microphone.request();
        if (status.isDenied) {
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
    setState(() => _loadingPreview = true);
    _saveFilters();
    try {
      final data = await _service.previsualizar(
        fechaDesde: DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta: DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipo: _tipoReporte,
        estado: _estado,
        textoLibre: _textoLibreCtrl.text,
      );
      setState(() {
        _previewData = data;
        _loadingPreview = false;
      });
    } catch (e) {
      setState(() => _loadingPreview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportar(String formato) async {
    setState(() => _exporting = true);
    _saveFilters();
    try {
      final file = await _service.exportar(
        formato: formato,
        fechaDesde: DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta: DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipo: _tipoReporte,
        estado: _estado,
        textoLibre: _textoLibreCtrl.text,
      );
      setState(() => _exporting = false);
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        // Si no se puede abrir, intentar compartir
        await Share.shareXFiles([XFile(file.path)], text: 'Reporte de $_tipoReporte');
      }
    } catch (e) {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowedRoles = ['Administrador', 'Médico', 'Jefe de enfermería', 'Director'];
    if (!allowedRoles.contains(widget.user.role)) {
      return Scaffold(
        drawer: AppDrawer(user: widget.user, activeLabel: 'Reportes Rápidos'),
        appBar: AppBar(title: const Text('Reportes Rápidos'), backgroundColor: AppColors.azulElectrico, foregroundColor: Colors.white),
        body: const Center(child: Text('Acceso denegado. No tienes permisos para ver reportes.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: widget.user, activeLabel: 'Reportes Rápidos'),
      appBar: AppBar(
        title: const Text('Reportes Rápidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar todo',
            onPressed: _clearAll,
          ),
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Filtros de Tiempo'),
            const SizedBox(height: 10),
            _buildDateChips(),
            const SizedBox(height: 10),
            if (_rangoSeleccionado == 'Personalizado')
              _buildDateDisplay(),
            
            const SizedBox(height: 20),
            _buildSectionTitle('Configuración'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDropdown('Tipo', _tipoReporte, _tipos, (val) {
                  setState(() => _tipoReporte = val!);
                  _saveFilters();
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown('Estado', _estado, _estados, (val) {
                  setState(() => _estado = val!);
                  _saveFilters();
                })),
              ],
            ),
            
            const SizedBox(height: 20),
            _buildSectionTitle('Texto Libre / Búsqueda por Voz'),
            const SizedBox(height: 10),
            _buildSpeechField(),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loadingPreview ? null : _aplicarFiltros,
                icon: const Icon(Icons.search),
                label: const Text('Aplicar Filtros y Previsualizar', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulElectrico,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Previsualización'),
            const SizedBox(height: 10),
            _buildPreviewArea(),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Exportar Reporte'),
            const SizedBox(height: 12),
            _buildExportButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.azulElectrico, letterSpacing: 0.5),
    );
  }

  Widget _buildDateChips() {
    final ranges = ['Hoy', 'Esta semana', 'Este mes', 'Personalizado'];
    return Wrap(
      spacing: 8,
      children: ranges.map((r) {
        final selected = _rangoSeleccionado == r;
        return ChoiceChip(
          label: Text(r, style: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 12)),
          selected: selected,
          onSelected: (val) {
            if (r == 'Personalizado') {
              _pickDateRange();
            } else {
              _setRango(r);
            }
          },
          selectedColor: AppColors.azulElectrico,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
        );
      }).toList(),
    );
  }

  Widget _buildDateDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.azulCielo)),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 18, color: AppColors.azulElectrico),
          const SizedBox(width: 10),
          Text(
            '${DateFormat('dd/MM/yyyy').format(_fechaDesde)} — ${DateFormat('dd/MM/yyyy').format(_fechaHasta)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeechField() {
    return Column(
      children: [
        TextField(
          controller: _textoLibreCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Escribe o usa el micrófono para describir lo que necesitas...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isListening)
              const Expanded(child: Text('Escuchando...', style: TextStyle(color: AppColors.mentaVibrante, fontWeight: FontWeight.bold))),
            GestureDetector(
              onTap: _listen,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : AppColors.mentaVibrante,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (_isListening ? Colors.red : AppColors.mentaVibrante).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    if (_loadingPreview) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: LoadingIndicator(message: 'Cargando datos...')));
    }
    if (_previewData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(Icons.table_chart_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No hay datos para mostrar', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          ..._previewData.take(5).map((row) => ListTile(
            dense: true,
            title: Text(row.values.first.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(row.values.skip(1).take(2).join(' — '), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          )),
          if (_previewData.length > 5)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Mostrando 5 de ${_previewData.length} registros', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButtons() {
    if (_exporting) {
      return const Center(child: LoadingIndicator(message: 'Generando archivo...'));
    }
    return Row(
      children: [
        Expanded(child: _ExportButton(label: 'CSV', color: Colors.green.shade700, icon: Icons.description_outlined, onTap: () => _exportar('csv'))),
        const SizedBox(width: 8),
        Expanded(child: _ExportButton(label: 'Excel', color: Colors.blue.shade700, icon: Icons.table_view_outlined, onTap: () => _exportar('excel'))),
        const SizedBox(width: 8),
        Expanded(child: _ExportButton(label: 'PDF', color: Colors.red.shade700, icon: Icons.picture_as_pdf_outlined, onTap: () => _exportar('pdf'))),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ExportButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
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
}
