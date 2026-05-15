import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/services/api_service.dart';

// ── Constantes de filtros ────────────────────────────────────────────────────
const _kAcciones = ['Todas', 'CREAR', 'ACTUALIZAR', 'ELIMINAR', 'LOGIN', 'LOGOUT'];

const _kModulos = [
  'Todos',
  'PACIENTES',
  'USUARIOS',
  'ATENCION_CLINICA',
  'APERTURA_FICHA',
  'REPORTES',
  'CONFIGURACION',
];

const _kModuloLabels = {
  'Todos': 'Todos',
  'PACIENTES': 'Pacientes',
  'USUARIOS': 'Usuarios',
  'ATENCION_CLINICA': 'Atención Clínica',
  'APERTURA_FICHA': 'Fichas',
  'REPORTES': 'Reportes',
  'CONFIGURACION': 'Configuración',
};

// ── Colores por acción ───────────────────────────────────────────────────────
Color _accionColor(String accion) => switch (accion.toUpperCase()) {
      'CREAR'     => const Color(0xFF16A34A),
      'ACTUALIZAR'=> const Color(0xFF2563EB),
      'ELIMINAR'  => const Color(0xFFDC2626),
      'LOGIN'     => const Color(0xFF7C3AED),
      'LOGOUT'    => const Color(0xFF9CA3AF),
      _           => const Color(0xFF6B7280),
    };

Color _accionBg(String accion) => switch (accion.toUpperCase()) {
      'CREAR'     => const Color(0xFFDCFCE7),
      'ACTUALIZAR'=> const Color(0xFFDBEAFE),
      'ELIMINAR'  => const Color(0xFFFEE2E2),
      'LOGIN'     => const Color(0xFFEDE9FE),
      'LOGOUT'    => const Color(0xFFF3F4F6),
      _           => const Color(0xFFF3F4F6),
    };

// ── Modelo de registro ───────────────────────────────────────────────────────
class _RegistroAuditoria {
  final int id;
  final DateTime timestamp;
  final String usuarioUsername;
  final String accion;
  final String modulo;
  final String? ipAddress;
  final String detalles;

  const _RegistroAuditoria({
    required this.id,
    required this.timestamp,
    required this.usuarioUsername,
    required this.accion,
    required this.modulo,
    this.ipAddress,
    required this.detalles,
  });

  factory _RegistroAuditoria.fromJson(Map<String, dynamic> j) {
    return _RegistroAuditoria(
      id:              j['id'] as int,
      timestamp:       DateTime.parse(j['timestamp'] as String),
      usuarioUsername: j['usuario_username'] as String? ?? '',
      accion:          j['accion'] as String? ?? '',
      modulo:          j['modulo'] as String? ?? '',
      ipAddress:       j['ip_address'] as String?,
      detalles:        j['detalles'] as String? ?? '',
    );
  }
}

// ── Pantalla principal ───────────────────────────────────────────────────────
class PanelDeAuditoriaYReportesSNISScreen extends StatefulWidget {
  final UserModel user;
  const PanelDeAuditoriaYReportesSNISScreen({super.key, required this.user});

  @override
  State<PanelDeAuditoriaYReportesSNISScreen> createState() =>
      _PanelDeAuditoriaYReportesSNISScreenState();
}

class _PanelDeAuditoriaYReportesSNISScreenState
    extends State<PanelDeAuditoriaYReportesSNISScreen> {
  final _api = ApiService();
  final _usuarioCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _accionFiltro = 'Todas';
  String _moduloFiltro = 'Todos';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  List<_RegistroAuditoria> _registros = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchPage(1);
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _fetchPage(_page + 1, append: true);
    }
  }

  Map<String, String> _buildParams(int page) {
    final params = <String, String>{'page': '$page', 'page_size': '20'};
    if (_usuarioCtrl.text.trim().isNotEmpty) {
      params['usuario'] = _usuarioCtrl.text.trim();
    }
    if (_accionFiltro != 'Todas') params['accion'] = _accionFiltro;
    if (_moduloFiltro != 'Todos') params['modulo'] = _moduloFiltro;
    if (_fechaDesde != null) {
      params['fecha_desde'] = DateFormat('yyyy-MM-dd').format(_fechaDesde!);
    }
    if (_fechaHasta != null) {
      params['fecha_hasta'] =
          DateFormat('yyyy-MM-dd').format(_fechaHasta!.add(const Duration(days: 1)));
    }
    return params;
  }

  Future<void> _fetchPage(int page, {bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _registros = [];
        _hasMore = true;
      });
    }

    try {
      final resp = await _api.get('/api/auditoria/', queryParameters: _buildParams(page));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final results = (body['results'] as List? ?? [])
            .map((e) => _RegistroAuditoria.fromJson(e as Map<String, dynamic>))
            .toList();
        final count = body['count'] as int? ?? 0;

        setState(() {
          _totalCount = count;
          if (append) {
            _registros.addAll(results);
          } else {
            _registros = results;
          }
          _page = page;
          _hasMore = body['next'] != null;
        });
      } else if (resp.statusCode == 403) {
        setState(() => _error = 'No tiene permiso para ver el registro de auditoría.');
      } else {
        setState(() => _error = 'Error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _aplicarFiltros() {
    _fetchPage(1);
  }

  void _limpiarFiltros() {
    setState(() {
      _usuarioCtrl.clear();
      _accionFiltro = 'Todas';
      _moduloFiltro = 'Todos';
      _fechaDesde = null;
      _fechaHasta = null;
    });
    _fetchPage(1);
  }

  Future<void> _pickFechaDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaDesde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.azulElectrico),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaDesde = picked);
  }

  Future<void> _pickFechaHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaHasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.azulElectrico),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaHasta = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: widget.user, activeLabel: 'Auditoría'),
      appBar: AppBar(
        title: const Text(
          'Registro de Auditoría',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => _fetchPage(1),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          if (_totalCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFE8F0FE),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.azulElectrico),
                  const SizedBox(width: 6),
                  Text(
                    '$_totalCount registros encontrados',
                    style: const TextStyle(fontSize: 12, color: AppColors.azulElectrico, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usuario
          TextField(
            controller: _usuarioCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por usuario…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: AppColors.fondo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (_) => _aplicarFiltros(),
          ),
          const SizedBox(height: 10),
          // Acción y módulo en fila
          Row(
            children: [
              Expanded(child: _buildDropdown('Acción', _kAcciones, _accionFiltro, (v) => setState(() => _accionFiltro = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdown('Módulo', _kModulos, _moduloFiltro, (v) => setState(() => _moduloFiltro = v!), labels: _kModuloLabels)),
            ],
          ),
          const SizedBox(height: 10),
          // Fechas en fila
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: _fechaDesde != null ? fmt.format(_fechaDesde!) : 'Desde',
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickFechaDesde,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: _fechaHasta != null ? fmt.format(_fechaHasta!) : 'Hasta',
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickFechaHasta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Botones
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _aplicarFiltros,
                  icon: const Icon(Icons.filter_list_rounded, size: 16),
                  label: const Text('Filtrar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulElectrico,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Limpiar', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged, {
    Map<String, String>? labels,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(labels?[i] ?? i, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.azulElectrico),
            SizedBox(height: 12),
            Text('Cargando registros…', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchPage(1),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulElectrico, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Sin registros', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('No hay eventos de auditoría con los filtros aplicados.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _registros.length + (_loadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _registros.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.azulElectrico, strokeWidth: 2)),
          );
        }
        return _RegistroCard(registro: _registros[i]);
      },
    );
  }
}

// ── Tarjeta de un registro de auditoría ─────────────────────────────────────
class _RegistroCard extends StatelessWidget {
  final _RegistroAuditoria registro;
  const _RegistroCard({required this.registro});

  @override
  Widget build(BuildContext context) {
    final color = _accionColor(registro.accion);
    final bgColor = _accionBg(registro.accion);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: acción + timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    registro.accion,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                _ModuloBadge(modulo: registro.modulo),
                const Spacer(),
                Text(
                  fmt.format(registro.timestamp.toLocal()),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Usuario
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  registro.usuarioUsername,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (registro.ipAddress != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.router_outlined, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(registro.ipAddress!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Detalles
            Text(
              registro.detalles,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuloBadge extends StatelessWidget {
  final String modulo;
  const _ModuloBadge({required this.modulo});

  Color get _color => switch (modulo) {
        'PACIENTES'       => const Color(0xFF0369A1),
        'USUARIOS'        => const Color(0xFF7C3AED),
        'ATENCION_CLINICA'=> const Color(0xFF059669),
        'APERTURA_FICHA'  => const Color(0xFFD97706),
        'REPORTES'        => const Color(0xFF0891B2),
        'CONFIGURACION'   => const Color(0xFF9CA3AF),
        _                 => const Color(0xFF6B7280),
      };

  String get _label => switch (modulo) {
        'PACIENTES'       => 'Pacientes',
        'USUARIOS'        => 'Usuarios',
        'ATENCION_CLINICA'=> 'Atención',
        'APERTURA_FICHA'  => 'Fichas',
        'REPORTES'        => 'Reportes',
        'CONFIGURACION'   => 'Config',
        _                 => modulo,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(_label, style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.azulElectrico),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
