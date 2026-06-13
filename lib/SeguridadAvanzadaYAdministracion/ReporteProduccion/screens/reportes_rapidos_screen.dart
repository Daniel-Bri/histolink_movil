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

// ══════════════════════════════════════════════════════════════════════════════
//  PARSER NLP LOCAL — interpreta texto en español sin tocar el backend
// ══════════════════════════════════════════════════════════════════════════════

class _ParsedQuery {
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String?   tipo;   // display key (ej. 'Triajes')
  final String?   nivel;  // 'ROJO' | 'NARANJA' | ...
  final String    resumen; // texto legible de lo detectado

  const _ParsedQuery({
    this.fechaDesde,
    this.fechaHasta,
    this.tipo,
    this.nivel,
    this.resumen = '',
  });

  bool get hasDates => fechaDesde != null && fechaHasta != null;
  bool get hasAny   => hasDates || tipo != null || nivel != null;
}

class _NlpLocal {
  static const _meses = {
    'enero': 1,    'febrero': 2,  'marzo': 3,     'abril': 4,
    'mayo': 5,     'junio': 6,    'julio': 7,     'agosto': 8,
    'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
  };

  static _ParsedQuery parse(String text) {
    final t   = text.toLowerCase().trim();
    final now = DateTime.now();

    DateTime? desde;
    DateTime? hasta;
    String?   tipo;
    String?   nivel;
    final tags = <String>[];

    // ── Tipo de reporte ──────────────────────────────────────────────────────
    if (t.contains('triaje'))   { tipo = 'Triajes';         tags.add('Triajes'); }
    else if (t.contains('consulta')) { tipo = 'Consultas';  tags.add('Consultas'); }
    else if (t.contains('receta'))   { tipo = 'Recetas';    tags.add('Recetas'); }
    else if (t.contains('resumen'))  { tipo = 'Resumen General'; tags.add('Resumen'); }

    // ── Nivel de urgencia ────────────────────────────────────────────────────
    if      (t.contains('rojo'))     { nivel = 'ROJO';     tags.add('ROJO'); }
    else if (t.contains('naranja'))  { nivel = 'NARANJA';  tags.add('NARANJA'); }
    else if (t.contains('amarillo')) { nivel = 'AMARILLO'; tags.add('AMARILLO'); }
    else if (t.contains('verde'))    { nivel = 'VERDE';    tags.add('VERDE'); }
    else if (t.contains('azul'))     { nivel = 'AZUL';     tags.add('AZUL'); }

    // ── Fechas: expresiones fijas ────────────────────────────────────────────
    if (RegExp(r'\bhoy\b').hasMatch(t)) {
      desde = DateTime(now.year, now.month, now.day);
      hasta = now;
      tags.add('Hoy');
    } else if (t.contains('ayer')) {
      final ayer = now.subtract(const Duration(days: 1));
      desde = DateTime(ayer.year, ayer.month, ayer.day);
      hasta = DateTime(ayer.year, ayer.month, ayer.day, 23, 59, 59);
      tags.add('Ayer');
    } else if (t.contains('esta semana')) {
      final ini = now.subtract(Duration(days: now.weekday - 1));
      desde = DateTime(ini.year, ini.month, ini.day);
      hasta = now;
      tags.add('Esta semana');
    } else if (t.contains('semana pasada') || t.contains('semana anterior')) {
      final ini  = now.subtract(Duration(days: now.weekday - 1));
      final iniP = ini.subtract(const Duration(days: 7));
      desde = DateTime(iniP.year, iniP.month, iniP.day);
      final finP = ini.subtract(const Duration(days: 1));
      hasta = DateTime(finP.year, finP.month, finP.day, 23, 59, 59);
      tags.add('Semana pasada');
    } else if (t.contains('este mes') || t.contains('mes actual')) {
      desde = DateTime(now.year, now.month, 1);
      hasta = now;
      tags.add('Este mes');
    } else if (t.contains('mes pasado') || t.contains('mes anterior')) {
      final m = now.month == 1 ? 12 : now.month - 1;
      final a = now.month == 1 ? now.year - 1 : now.year;
      desde = DateTime(a, m, 1);
      hasta = _ultimoDiaMes(a, m);
      tags.add('Mes pasado');
    } else if (RegExp(r'[úu]ltimos?\s+(\d+)\s+d[íi]as?').hasMatch(t)) {
      final m = RegExp(r'[úu]ltimos?\s+(\d+)\s+d[íi]as?').firstMatch(t)!;
      final n = int.tryParse(m.group(1)!) ?? 7;
      desde = DateTime(now.year, now.month, now.day).subtract(Duration(days: n - 1));
      hasta = now;
      tags.add('Últimos $n días');
    } else if (RegExp(r'\ba[ñn]o\s+(20\d{2})\b').hasMatch(t)) {
      // "año 2025" / "año 2026"
      final m = RegExp(r'\ba[ñn]o\s+(20\d{2})\b').firstMatch(t)!;
      final a = int.tryParse(m.group(1)!) ?? now.year;
      desde = DateTime(a, 1, 1);
      hasta = DateTime(a, 12, 31, 23, 59, 59);
      tags.add('Año $a');
    } else {
      // ── Nombres de mes (uno o rango: "mayo" / "de marzo a mayo") ──────────
      final encontrados = <MapEntry<String, int>>[];
      for (final e in _meses.entries) {
        if (t.contains(e.key)) encontrados.add(e);
      }

      if (encontrados.isNotEmpty) {
        // Año explícito en el texto
        final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(t);

        if (encontrados.length >= 2) {
          // Rango "de marzo a mayo"
          final m1 = encontrados.first.value;
          final m2 = encontrados.last.value;
          int a1 = yearMatch != null ? int.parse(yearMatch.group(1)!) : now.year;
          if (m1 > now.month && yearMatch == null) a1 = now.year - 1;
          int a2 = a1;
          if (m2 < m1) a2 = a1 + 1;
          desde = DateTime(a1, m1, 1);
          hasta = _ultimoDiaMes(a2, m2);
          tags.add('${_nombreMes(m1)}–${_nombreMes(m2)} $a1');
        } else {
          // Un solo mes
          final mes = encontrados.first.value;
          int anio = yearMatch != null
              ? int.parse(yearMatch.group(1)!)
              : (mes > now.month ? now.year - 1 : now.year);
          desde = DateTime(anio, mes, 1);
          hasta = _ultimoDiaMes(anio, mes);
          tags.add('${_nombreMes(mes)} $anio');
        }
      }
    }

    return _ParsedQuery(
      fechaDesde: desde,
      fechaHasta: hasta,
      tipo:       tipo,
      nivel:      nivel,
      resumen:    tags.join('  ·  '),
    );
  }

  static DateTime _ultimoDiaMes(int anio, int mes) =>
      DateTime(mes < 12 ? anio : anio + 1, mes < 12 ? mes + 1 : 1, 1)
          .subtract(const Duration(seconds: 1));

  static String _nombreMes(int m) => _meses.keys.elementAt(m - 1);
}

// ── Constantes ────────────────────────────────────────────────────────────────

const _kTipos = {
  'Resumen General': 'resumen_general',
  'Consultas':       'consultas',
  'Triajes':         'triajes',
  'Recetas':         'recetas',
};

const _kNiveles = ['Todos', 'ROJO', 'NARANJA', 'AMARILLO', 'VERDE', 'AZUL'];
const _kRangos  = ['Hoy', 'Esta semana', 'Este mes', 'Personalizado'];

Color _nivelColor(String n) => switch (n.toUpperCase()) {
  'ROJO'     => const Color(0xFFDC2626),
  'NARANJA'  => const Color(0xFFEA580C),
  'AMARILLO' => const Color(0xFFD97706),
  'VERDE'    => const Color(0xFF16A34A),
  'AZUL'     => const Color(0xFF2563EB),
  _          => Colors.grey,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportesRapidosScreen extends StatefulWidget {
  final UserModel user;
  const ReportesRapidosScreen({super.key, required this.user});

  @override
  State<ReportesRapidosScreen> createState() => _ReportesRapidosScreenState();
}

class _ReportesRapidosScreenState extends State<ReportesRapidosScreen> {
  final _service = ReporteService();
  final _stt     = stt.SpeechToText();
  final _qCtrl   = TextEditingController();

  // Filtros
  String   _rango       = 'Este mes';
  DateTime _fechaDesde  = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fechaHasta  = DateTime.now();
  String   _tipoDisplay = 'Resumen General';
  String   _nivel       = 'Todos';

  // Estado
  bool                    _isListening     = false;
  bool                    _loading         = false;
  bool                    _exporting       = false;
  bool                    _filtersExpanded = true;
  Map<String, dynamic>?   _data;
  String                  _nlpDetectado    = '';

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // ── Persistencia de filtros ────────────────────────────────────────────────

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _tipoDisplay = prefs.getString('rpt_tipo')  ?? 'Resumen General';
      _nivel       = prefs.getString('rpt_nivel') ?? 'Todos';
      _qCtrl.text  = prefs.getString('rpt_q')     ?? '';
      final savedRango = prefs.getString('rpt_rango') ?? 'Este mes';
      if (savedRango == 'Personalizado') {
        final d = prefs.getString('rpt_desde');
        final h = prefs.getString('rpt_hasta');
        if (d != null) _fechaDesde = DateTime.parse(d);
        if (h != null) _fechaHasta = DateTime.parse(h);
        _rango = 'Personalizado';
      } else {
        _setRango(savedRango, save: false);
      }
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rpt_rango', _rango);
    await prefs.setString('rpt_tipo',  _tipoDisplay);
    await prefs.setString('rpt_nivel', _nivel);
    await prefs.setString('rpt_q',     _qCtrl.text);
    if (_rango == 'Personalizado') {
      await prefs.setString('rpt_desde', _fechaDesde.toIso8601String());
      await prefs.setString('rpt_hasta', _fechaHasta.toIso8601String());
    }
  }

  // ── Fecha ──────────────────────────────────────────────────────────────────

  void _setRango(String rango, {bool save = true}) {
    final now = DateTime.now();
    setState(() {
      _rango = rango;
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
    if (save) _saveFilters();
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
      _saveFilters();
    }
  }

  // ── Voz ───────────────────────────────────────────────────────────────────

  Future<void> _listen() async {
    if (_isListening) {
      setState(() => _isListening = false);
      _stt.stop();
      return;
    }
    final available = await _stt.initialize(onStatus: (_) {}, onError: (_) {});
    if (available) {
      setState(() => _isListening = true);
      _stt.listen(
        onResult: (val) {
          if (val.finalResult) {
            setState(() {
              _qCtrl.text  = '${_qCtrl.text} ${val.recognizedWords}'.trim();
              _isListening = false;
            });
            _applyNlp();
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
  }

  // ── NLP local ─────────────────────────────────────────────────────────────

  /// Parsea el campo de texto y actualiza los filtros de fecha/tipo/nivel.
  /// Retorna true si detectó algo.
  bool _applyNlp() {
    final texto = _qCtrl.text.trim();
    if (texto.isEmpty) return false;

    final parsed = _NlpLocal.parse(texto);
    if (!parsed.hasAny) return false;

    setState(() {
      if (parsed.hasDates) {
        _rango      = 'Personalizado';
        _fechaDesde = parsed.fechaDesde!;
        _fechaHasta = parsed.fechaHasta!;
      }
      if (parsed.tipo  != null) _tipoDisplay = parsed.tipo!;
      if (parsed.nivel != null) _nivel       = parsed.nivel!;
      _nlpDetectado = parsed.resumen;
    });
    return true;
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _aplicar() async {
    _applyNlp();
    setState(() { _loading = true; _data = null; _filtersExpanded = false; });
    await _saveFilters();
    try {
      final data = await _service.previsualizar(
        fechaDesde:    DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:    DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:   _kTipos[_tipoDisplay] ?? 'resumen_general',
        nivelUrgencia: _nivel == 'Todos' ? null : _nivel,
        q:             _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportar(String formato) async {
    setState(() => _exporting = true);
    try {
      final file = await _service.exportar(
        formato:       formato,
        fechaDesde:    DateFormat('yyyy-MM-dd').format(_fechaDesde),
        fechaHasta:    DateFormat('yyyy-MM-dd').format(_fechaHasta),
        tipoReporte:   _kTipos[_tipoDisplay] ?? 'resumen_general',
        nivelUrgencia: _nivel == 'Todos' ? null : _nivel,
        q:             _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      );
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Reporte de $_tipoDisplay',
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

  void _reset() {
    setState(() {
      _qCtrl.clear();
      _tipoDisplay     = 'Resumen General';
      _nivel           = 'Todos';
      _data            = null;
      _filtersExpanded = true;
      _nlpDetectado    = '';
    });
    _setRango('Este mes');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: AppDrawer(user: widget.user, activeLabel: 'Reportes'),
      appBar: AppBar(
        title: const Text(
          'Reportes de Producción',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_data != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Mostrar/ocultar filtros',
              onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Limpiar todo',
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersCard(),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingIndicator(message: 'Cargando reporte...'),
                ),
              )
            else if (_data != null)
              _buildResultados()
            else
              _buildEmptyState(),
            const SizedBox(height: 14),
            _buildExportSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTROS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFiltersCard() {
    return _Card(
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        crossFadeState:
            _filtersExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild:  _buildFiltersExpanded(),
        secondChild: _buildFiltersCollapsed(),
      ),
    );
  }

  Widget _buildFiltersCollapsed() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _filtersExpanded = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 18, color: AppColors.azulElectrico),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_tipoDisplay  ·  '
                '${DateFormat('dd/MM').format(_fechaDesde)} – ${DateFormat('dd/MM/yy').format(_fechaHasta)}'
                '${_nivel != 'Todos' ? '  ·  $_nivel' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.azulElectrico),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersExpanded() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rango de fechas ──
          _sectionLabel('Rango de fechas'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _kRangos.map((r) {
              final sel = _rango == r;
              return ChoiceChip(
                label: Text(r,
                    style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : Colors.black87)),
                selected: sel,
                selectedColor: AppColors.azulElectrico,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onSelected: (_) =>
                    r == 'Personalizado' ? _pickDateRange() : _setRango(r),
              );
            }).toList(),
          ),
          if (_rango == 'Personalizado') ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.azulElectrico),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded,
                        size: 16, color: AppColors.azulElectrico),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(_fechaDesde)}   –   ${DateFormat('dd/MM/yyyy').format(_fechaHasta)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.azulElectrico),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Tipo de reporte ──
          _sectionLabel('Tipo de reporte'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _kTipos.keys.map((d) {
              final sel = _tipoDisplay == d;
              return ChoiceChip(
                label: Text(d,
                    style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : Colors.black87)),
                selected: sel,
                selectedColor: AppColors.mentaVibrante,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onSelected: (_) => setState(() {
                  _tipoDisplay = d;
                  _saveFilters();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Nivel de urgencia ──
          _sectionLabel('Nivel de urgencia'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _nivel,
                isExpanded: true,
                items: _kNiveles
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Row(children: [
                            if (n != 'Todos') ...[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: _nivelColor(n),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(n, style: const TextStyle(fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _nivel = v!;
                  _saveFilters();
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Búsqueda NLP ──
          _sectionLabel('Búsqueda por texto / voz (NLP)'),
          const SizedBox(height: 8),
          TextField(
            controller: _qCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ej: "triajes rojos esta semana"…',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              suffixIcon: GestureDetector(
                onTap: _listen,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red
                        : AppColors.mentaVibrante,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          if (_isListening) ...[
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Escuchando...',
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
          // ── Indicador NLP ────────────────────────────────────────────────
          if (_nlpDetectado.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detectado: $_nlpDetectado',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _nlpDetectado = ''),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFF059669)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 18),

          // ── Botón aplicar ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _aplicar,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Generar reporte',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulElectrico,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RESULTADOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildResultados() {
    final resumen   = _data!['resumen']               as Map<String, dynamic>? ?? {};
    final warns     = (_data!['advertencias']         as List?)?.cast<String>() ?? [];
    final triajes   = (_data!['triajes_por_nivel']    as List?)?.cast<Map<String, dynamic>>() ?? [];
    final porMedico = (_data!['produccion_por_medico'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topDx     = (_data!['top_diagnosticos']     as List?)?.cast<Map<String, dynamic>>() ?? [];
    final detalle   = (_data!['detalle']              as List?)?.cast<Map<String, dynamic>>() ?? [];
    final periodo   = _data!['periodo']               as Map<String, dynamic>? ?? {};
    final tipo      = _kTipos[_tipoDisplay] ?? 'resumen_general';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Advertencias
        ...warns.map(_buildWarning),

        // Encabezado de período
        _buildPeriodoHeader(periodo),
        const SizedBox(height: 12),

        // Tarjetas resumen (6 métricas)
        _buildResumenGrid(resumen),
        const SizedBox(height: 14),

        // Triajes por nivel con barras de progreso
        if (triajes.isNotEmpty &&
            (tipo == 'resumen_general' || tipo == 'triajes')) ...[
          _buildTriajesSection(triajes),
          const SizedBox(height: 14),
        ],

        // Producción por médico
        if (porMedico.isNotEmpty) ...[
          _buildMedicosSection(porMedico),
          const SizedBox(height: 14),
        ],

        // Top diagnósticos CIE-10
        if (topDx.isNotEmpty) ...[
          _buildDiagnosticosSection(topDx),
          const SizedBox(height: 14),
        ],

        // Detalle (tipo-aware)
        if (detalle.isNotEmpty)
          _buildDetalleSection(detalle, tipo),
      ],
    );
  }

  Widget _buildWarning(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFD97706), size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF92400E)))),
        ]),
      );

  Widget _buildPeriodoHeader(Map<String, dynamic> periodo) {
    final desde = periodo['desde']?.toString() ?? '';
    final hasta = periodo['hasta']?.toString() ?? '';
    return Row(children: [
      const Icon(Icons.calendar_today_outlined,
          size: 14, color: AppColors.azulElectrico),
      const SizedBox(width: 6),
      Text(
        desde.isNotEmpty ? 'Período: $desde → $hasta' : 'Resultados',
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.azulElectrico),
      ),
    ]);
  }

  Widget _buildResumenGrid(Map<String, dynamic> r) {
    final items = [
      _ResumenData('Consultas',     r['total_consultas']           ?? 0,   Icons.assignment_outlined,           const Color(0xFF1D4ED8)),
      _ResumenData('Triajes',       r['total_triajes']             ?? 0,   Icons.monitor_heart_outlined,        const Color(0xFF7C3AED)),
      _ResumenData('Recetas emit.', r['total_recetas_emitidas']    ?? 0,   Icons.medication_liquid_outlined,    const Color(0xFF059669)),
      _ResumenData('Dispensadas',   r['total_recetas_dispensadas'] ?? 0,   Icons.check_circle_outline_rounded,  const Color(0xFF0891B2)),
      _ResumenData('Anuladas',      r['total_recetas_anuladas']    ?? 0,   Icons.cancel_outlined,               const Color(0xFFDC2626)),
      _ResumenData('Derivaciones',  '${r['tasa_derivacion_pct']   ?? 0}%', Icons.call_missed_outgoing_rounded,  const Color(0xFFD97706)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      children: items.map((i) => _ResumenCard(i)).toList(),
    );
  }

  Widget _buildTriajesSection(List<Map<String, dynamic>> triajes) {
    final totalGlobal =
        triajes.fold<int>(0, (s, t) => s + (t['total'] as int? ?? 0));
    final activos = triajes.where((t) => (t['total'] as int? ?? 0) > 0).toList();

    return _SectionCard(
      title: 'Triajes por nivel de urgencia',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children: activos.map((t) {
          final nivel = t['nivel_urgencia'] as String? ?? '';
          final cnt   = t['total'] as int? ?? 0;
          final pct   = totalGlobal > 0 ? cnt / totalGlobal : 0.0;
          final color = _nivelColor(nivel);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(nivel,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '$cnt  (${(pct * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMedicosSection(List<Map<String, dynamic>> list) {
    return _SectionCard(
      title: 'Producción por médico',
      icon: Icons.people_outline_rounded,
      child: Column(
        children: list.take(5).map((m) {
          final nombre = m['medico']       as String? ?? 'Sin nombre';
          final cons   = m['consultas']    as int?    ?? 0;
          final rec    = m['recetas']      as int?    ?? 0;
          final der    = m['derivaciones'] as int?    ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    size: 17, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    _MiniChip('$cons consultas', const Color(0xFF1D4ED8)),
                    _MiniChip('$rec recetas',    const Color(0xFF059669)),
                    if (der > 0)
                      _MiniChip('$der deriv.', const Color(0xFFD97706)),
                  ]),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiagnosticosSection(List<Map<String, dynamic>> list) {
    return _SectionCard(
      title: 'Top diagnósticos CIE-10',
      icon: Icons.medical_information_outlined,
      child: Column(
        children: list.take(5).map((d) {
          final codigo = d['codigo']      as String? ?? '';
          final desc   = d['descripcion'] as String? ?? '';
          final total  = d['total']       as int?    ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(codigo,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8))),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(desc,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
              Text('$total',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8))),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetalleSection(List<Map<String, dynamic>> list, String tipo) {
    final shown = list.take(10).toList();
    return _SectionCard(
      title: 'Detalle — ${list.length} registros',
      icon: Icons.list_alt_rounded,
      child: Column(children: [
        ...shown.map((row) => _buildDetalleRow(row, tipo)),
        if (list.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Exporta el reporte para ver los ${list.length - 10} registros restantes',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
      ]),
    );
  }

  Widget _buildDetalleRow(Map<String, dynamic> row, String tipo) {
    final String titulo;
    final String subtitulo;
    final String badge;
    final Color  badgeColor;

    switch (tipo) {
      case 'triajes':
        titulo     = row['paciente'] as String? ?? '—';
        final niv  = row['nivel_urgencia'] as String? ?? '';
        badge      = niv;
        badgeColor = _nivelColor(niv);
        final fc   = row['fc']          ?? '—';
        final sat  = row['saturacion']  ?? '—';
        final temp = row['temperatura'] ?? '—';
        subtitulo  = 'FC: $fc  ·  SpO₂: $sat%  ·  T°: $temp°C';

      case 'recetas':
      case 'recetas_emitidas':
      case 'recetas_dispensadas':
      case 'recetas_anuladas':
        titulo    = row['paciente'] as String? ?? '—';
        final est = row['estado'] as String? ?? '';
        badge      = est;
        badgeColor = est == 'DISPENSADA'
            ? const Color(0xFF059669)
            : est == 'ANULADA'
                ? const Color(0xFFDC2626)
                : const Color(0xFF1D4ED8);
        subtitulo = '${row['medico'] ?? ''}  ·  Nro: ${row['numero_receta'] ?? '—'}';

      default: // resumen_general y consultas
        titulo    = row['paciente'] as String? ?? '—';
        final est = row['estado'] as String? ?? '';
        badge      = est;
        badgeColor = est == 'FIRMADA'
            ? const Color(0xFF059669)
            : est == 'COMPLETADA'
                ? AppColors.azulElectrico
                : Colors.grey;
        final cie  = row['codigo_cie10'] as String? ?? '';
        final diag = row['diagnostico']  as String? ?? '';
        subtitulo  = [
          if ((row['medico'] as String? ?? '').isNotEmpty) row['medico'] as String,
          if (cie.isNotEmpty) cie,
          if (diag.isNotEmpty) diag,
        ].join('  ·  ');
    }

    final fechaRaw = (row['fecha_consulta'] ??
            row['fecha'] ??
            row['fecha_emision'] ??
            '')
        .toString();
    final fechaCorta =
        fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : fechaRaw;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            if (subtitulo.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitulo.trim(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (badge.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: badgeColor)),
            ),
          if (fechaCorta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(fechaCorta,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ESTADO VACÍO Y EXPORTAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() => _Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Icon(Icons.analytics_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text('Configura los filtros y presiona',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            const Text('"Generar reporte"',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.azulElectrico)),
          ]),
        ),
      );

  Widget _buildExportSection() => _Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Exportar reporte'),
            const SizedBox(height: 12),
            if (_exporting)
              const Center(
                  child: LoadingIndicator(message: 'Generando archivo...'))
            else
              Row(children: [
                Expanded(
                    child: _ExportButton(
                        label: 'CSV',
                        color: const Color(0xFF16A34A),
                        icon: Icons.description_outlined,
                        onTap: () => _exportar('csv'))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ExportButton(
                        label: 'Excel',
                        color: const Color(0xFF1D4ED8),
                        icon: Icons.table_chart_outlined,
                        onTap: () => _exportar('excel'))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ExportButton(
                        label: 'PDF',
                        color: const Color(0xFFDC2626),
                        icon: Icons.picture_as_pdf_outlined,
                        onTap: () => _exportar('pdf'))),
              ]),
          ]),
        ),
      );

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.azulElectrico,
          letterSpacing: 0.3,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _SectionCard extends StatelessWidget {
  final String  title;
  final IconData icon;
  final Widget  child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => _Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: AppColors.azulElectrico),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.azulElectrico)),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}

class _ResumenData {
  final String label;
  final Object value;
  final IconData icon;
  final Color color;
  const _ResumenData(this.label, this.value, this.icon, this.color);
}

class _ResumenCard extends StatelessWidget {
  final _ResumenData d;
  const _ResumenCard(this.d);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: d.color.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(d.icon, color: d.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.value.toString(),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: d.color,
                        height: 1.1)),
                Text(d.label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        height: 1.2),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _ExportButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final IconData   icon;
  final VoidCallback onTap;
  const _ExportButton(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      );
}
