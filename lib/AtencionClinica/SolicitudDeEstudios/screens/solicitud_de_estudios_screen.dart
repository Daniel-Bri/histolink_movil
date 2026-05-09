import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:histolink/shared/services/api_service.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/AtencionClinica/SolicitudDeEstudios/models/orden_estudio_model.dart';
import 'package:histolink/AtencionClinica/SolicitudDeEstudios/services/estudios_service.dart';

// ── Paleta (misma que el resto de la app) ────────────────────────────────────
const _kPrimary = Color(0xFF0023B8);
const _kAccent = Color(0xFF00A896);
const _kFondo = Color(0xFFF0F6FF);
const _kUrgente = Color(0xFFDC2626);
const _kSuccess = Color(0xFF16A34A);
const _kWarning = Color(0xFFD97706);
const _kGrey = Color(0xFF6B7280);

// ── Tipos de estudio ──────────────────────────────────────────────────────────
const _kTipos = <(String, String, IconData)>[
  ('LAB', 'Laboratorio', Icons.biotech_outlined),
  ('RX', 'Rayos X', Icons.medical_services_outlined),
  ('ECO', 'Ecografía', Icons.waves_outlined),
  ('TC', 'TAC/TC', Icons.scanner_outlined),
  ('RMN', 'Resonancia', Icons.filter_none_outlined),
  ('ECG', 'ECG', Icons.monitor_heart_outlined),
  ('END', 'Endoscopía', Icons.linear_scale_outlined),
  ('OTRO', 'Otro', Icons.more_horiz),
];

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class SolicitudDeEstudiosScreen extends StatefulWidget {
  const SolicitudDeEstudiosScreen({super.key});

  @override
  State<SolicitudDeEstudiosScreen> createState() =>
      _SolicitudDeEstudiosScreenState();
}

class _SolicitudDeEstudiosScreenState extends State<SolicitudDeEstudiosScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  late final EstudiosService _service;
  UserModel? _user;
  bool _loadingUser = true;
  TabController? _tabCtrl;

  bool get _isMedico => _user?.groups.contains('Médico') ?? false;
  bool get _isLaboratorio => _user?.groups.contains('Laboratorio') ?? false;

  @override
  void initState() {
    super.initState();
    _service = EstudiosService(_api);
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final resp = await _api.get('/api/auth/profile/');
      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        final tabCount = _isMedicoFor(user) ? 2 : 1;
        setState(() {
          _user = user;
          _loadingUser = false;
          _tabCtrl?.dispose();
          _tabCtrl = TabController(length: tabCount, vsync: this);
        });
        return;
      }
    } catch (_) {}
    setState(() {
      _loadingUser = false;
      _tabCtrl = TabController(length: 1, vsync: this);
    });
  }

  bool _isMedicoFor(UserModel u) => u.groups.contains('Médico');

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser || _tabCtrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final showTabs = _isMedico;

    return Scaffold(
      backgroundColor: _kFondo,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122268),
        foregroundColor: Colors.white,
        title: const Text(
          'Solicitud de Estudios',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: showTabs
            ? TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _kAccent,
                tabs: const [
                  Tab(icon: Icon(Icons.add_circle_outline, size: 18), text: 'Nueva Orden'),
                  Tab(icon: Icon(Icons.list_alt_outlined, size: 18), text: 'Cola / Órdenes'),
                ],
              )
            : null,
      ),
      body: showTabs
          ? TabBarView(
              controller: _tabCtrl,
              children: [
                _NuevaOrdenView(service: _service),
                _ColaOrdenesView(
                  service: _service,
                  isLaboratorio: _isLaboratorio,
                  isMedico: _isMedico,
                ),
              ],
            )
          : _ColaOrdenesView(
              service: _service,
              isLaboratorio: _isLaboratorio,
              isMedico: _isMedico,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: NUEVA ORDEN (Médico)
// ─────────────────────────────────────────────────────────────────────────────

class _NuevaOrdenView extends StatefulWidget {
  final EstudiosService service;
  const _NuevaOrdenView({required this.service});

  @override
  State<_NuevaOrdenView> createState() => _NuevaOrdenViewState();
}

class _NuevaOrdenViewState extends State<_NuevaOrdenView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<ConsultaParaOrden> _consultas = [];
  List<ConsultaParaOrden> _filtradas = [];
  ConsultaParaOrden? _consultaSeleccionada;
  String _tipo = '';
  bool _urgente = false;
  bool _loadingConsultas = false;
  bool _submitting = false;
  String? _error;
  String? _successCorrelativo;

  final _searchCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _indicacionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConsultas();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtradas = q.isEmpty
            ? _consultas
            : _consultas
                .where((c) => c.display.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _motivoCtrl.dispose();
    _descripcionCtrl.dispose();
    _indicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConsultas() async {
    setState(() {
      _loadingConsultas = true;
      _error = null;
    });
    try {
      final list = await widget.service.getConsultasCompletadas();
      setState(() {
        _consultas = list;
        _filtradas = list;
        _loadingConsultas = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingConsultas = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_consultaSeleccionada == null) {
      setState(() => _error = 'Selecciona una consulta base.');
      return;
    }
    if (_tipo.isEmpty) {
      setState(() => _error = 'Selecciona el tipo de estudio.');
      return;
    }
    if (_descripcionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa la descripción del estudio.');
      return;
    }
    if (_indicacionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa la indicación clínica.');
      return;
    }
    if (_urgente && _motivoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el motivo de urgencia.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'consulta': _consultaSeleccionada!.id,
        'tipo': _tipo,
        'descripcion': _descripcionCtrl.text.trim(),
        'indicacion_clinica': _indicacionCtrl.text.trim(),
        'urgente': _urgente,
        if (_urgente) 'motivo_urgencia': _motivoCtrl.text.trim(),
      };
      final orden = await widget.service.crearOrden(payload);
      setState(() {
        _submitting = false;
        _successCorrelativo = orden.correlativoOrden;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  void _reset() {
    setState(() {
      _consultaSeleccionada = null;
      _tipo = '';
      _urgente = false;
      _successCorrelativo = null;
      _error = null;
    });
    _searchCtrl.clear();
    _motivoCtrl.clear();
    _descripcionCtrl.clear();
    _indicacionCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_successCorrelativo != null) {
      return _SuccessView(correlativo: _successCorrelativo!, onNew: _reset);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _ErrorBanner(message: _error!),

          // Consulta base
          _SectionCard(
            title: 'Consulta Base',
            icon: Icons.assignment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por paciente o diagnóstico...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingConsultas)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No hay consultas completadas disponibles.',
                      style: TextStyle(color: _kGrey, fontSize: 13),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 210),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtradas.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (ctx, i) {
                        final c = _filtradas[i];
                        final sel = _consultaSeleccionada?.id == c.id;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor: _kAccent.withValues(alpha: 0.1),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                sel ? _kAccent : Colors.grey.shade200,
                            child: Icon(
                              Icons.person_outline,
                              size: 14,
                              color: sel
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                          title: Text(
                            c.pacienteNombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: c.display != c.pacienteNombre
                              ? Text(
                                  c.display.replaceFirst(
                                    '${c.pacienteNombre} — ',
                                    '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _kGrey,
                                  ),
                                )
                              : null,
                          trailing: sel
                              ? const Icon(
                                  Icons.check_circle,
                                  color: _kAccent,
                                  size: 18,
                                )
                              : null,
                          onTap: () =>
                              setState(() => _consultaSeleccionada = c),
                        );
                      },
                    ),
                  ),
                if (_consultaSeleccionada != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: _kAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _consultaSeleccionada!.pacienteNombre,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tipo de estudio
          _SectionCard(
            title: 'Tipo de Estudio',
            icon: Icons.science_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kTipos.map((t) {
                final (codigo, label, icon) = t;
                final sel = _tipo == codigo;
                return GestureDetector(
                  onTap: () => setState(() => _tipo = codigo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary : Colors.white,
                      border: Border.all(
                        color: sel ? _kPrimary : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: sel ? Colors.white : _kGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Prioridad
          _SectionCard(
            title: 'Prioridad',
            icon: Icons.priority_high,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PrioridadBtn(
                      label: 'Normal',
                      icon: Icons.remove_circle_outline,
                      selected: !_urgente,
                      color: _kSuccess,
                      onTap: () => setState(() {
                        _urgente = false;
                        _motivoCtrl.clear();
                      }),
                    ),
                    const SizedBox(width: 10),
                    _PrioridadBtn(
                      label: 'Urgente',
                      icon: Icons.emergency_outlined,
                      selected: _urgente,
                      color: _kUrgente,
                      onTap: () => setState(() => _urgente = true),
                    ),
                  ],
                ),
                if (_urgente) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _motivoCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Motivo de urgencia...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Información clínica
          _SectionCard(
            title: 'Información Clínica',
            icon: Icons.description_outlined,
            child: Column(
              children: [
                TextField(
                  controller: _descripcionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del estudio *',
                    hintText: 'Descripción detallada del estudio solicitado',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _indicacionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Indicación clínica *',
                    hintText: 'Justificación médica del estudio',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_submitting ? 'Enviando...' : 'Solicitar Estudio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: COLA / ÓRDENES
// ─────────────────────────────────────────────────────────────────────────────

class _ColaOrdenesView extends StatefulWidget {
  final EstudiosService service;
  final bool isLaboratorio;
  final bool isMedico;

  const _ColaOrdenesView({
    required this.service,
    required this.isLaboratorio,
    required this.isMedico,
  });

  @override
  State<_ColaOrdenesView> createState() => _ColaOrdenesViewState();
}

class _ColaOrdenesViewState extends State<_ColaOrdenesView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<OrdenEstudioModel> _ordenes = [];
  bool _loading = false;
  String? _error;
  String _filtro = 'TODAS';

  static const _filtros = [
    'TODAS',
    'SOLICITADA',
    'EN_PROCESO',
    'COMPLETADA',
    'ANULADA',
  ];

  List<OrdenEstudioModel> get _filtradas {
    var list = [..._ordenes];
    if (_filtro != 'TODAS') {
      list = list.where((o) => o.estado == _filtro).toList();
    }
    list.sort((a, b) {
      if (a.urgente && !b.urgente) return -1;
      if (!a.urgente && b.urgente) return 1;
      final da = a.fechaSolicitud ?? DateTime(1970);
      final db = b.fechaSolicitud ?? DateTime(1970);
      return db.compareTo(da);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Intenta primero el endpoint general; si falla o devuelve vacío
      // y es Laboratorio, usa cola-laboratorio como fallback.
      List<OrdenEstudioModel> ordenes = await widget.service.getOrdenes();
      if (ordenes.isEmpty && widget.isLaboratorio) {
        ordenes = await widget.service.getColaLaboratorio();
      }
      setState(() {
        _ordenes = ordenes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _colorFiltro(String f) {
    return switch (f) {
      'SOLICITADA' => _kWarning,
      'EN_PROCESO' => _kPrimary,
      'COMPLETADA' => _kSuccess,
      'ANULADA' => Colors.grey,
      _ => _kAccent,
    };
  }

  String _labelFiltro(String f) {
    return switch (f) {
      'TODAS' => 'Todas',
      'SOLICITADA' => 'Solicitadas',
      'EN_PROCESO' => 'En Proceso',
      'COMPLETADA' => 'Completadas',
      'ANULADA' => 'Anuladas',
      _ => f,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filtros.map((f) {
                final sel = _filtro == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      _labelFiltro(f),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => _filtro = f),
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: _colorFiltro(f),
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    side: BorderSide(
                      color: sel
                          ? _colorFiltro(f)
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _filtradas.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 52,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No hay órdenes',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Desliza hacia abajo para refrescar',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filtradas.length,
                              itemBuilder: (ctx, i) {
                                return _OrdenCard(
                                  orden: _filtradas[i],
                                  onTap: () =>
                                      _verDetalle(ctx, _filtradas[i]),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  void _verDetalle(BuildContext context, OrdenEstudioModel orden) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrdenDetalleSheet(
        orden: orden,
        service: widget.service,
        isLaboratorio: widget.isLaboratorio,
        isMedico: widget.isMedico,
        onRefresh: _load,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE ORDEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrdenCard extends StatelessWidget {
  final OrdenEstudioModel orden;
  final VoidCallback onTap;
  const _OrdenCard({required this.orden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: orden.urgente ? _kUrgente : Colors.transparent,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        orden.correlativoOrden,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (orden.urgente) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kUrgente.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'URGENTE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kUrgente,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _EstadoChip(estado: orden.estado),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              orden.tipoLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (orden.pacienteNombre != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: _kGrey),
                  const SizedBox(width: 4),
                  Text(
                    orden.pacienteNombre!,
                    style: const TextStyle(fontSize: 12, color: _kGrey),
                  ),
                ],
              ),
            ],
            if (orden.descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                orden.descripcion.length > 75
                    ? '${orden.descripcion.substring(0, 75)}...'
                    : orden.descripcion,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: _kGrey),
                const SizedBox(width: 4),
                Text(
                  orden.fechaSolicitud != null
                      ? _fmt(orden.fechaSolicitud!)
                      : '-',
                  style: const TextStyle(fontSize: 11, color: _kGrey),
                ),
                if (orden.estaCompletada && orden.resultado != null) ...[
                  const Spacer(),
                  const Icon(
                    Icons.attach_file,
                    size: 13,
                    color: _kSuccess,
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'Resultado',
                    style: TextStyle(fontSize: 11, color: _kSuccess),
                  ),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: _kGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${_p(dt.day)}/${_p(dt.month)}/${dt.year}  ${_p(dt.hour)}:${_p(dt.minute)}';

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: DETALLE DE ORDEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrdenDetalleSheet extends StatefulWidget {
  final OrdenEstudioModel orden;
  final EstudiosService service;
  final bool isLaboratorio;
  final bool isMedico;
  final VoidCallback onRefresh;

  const _OrdenDetalleSheet({
    required this.orden,
    required this.service,
    required this.isLaboratorio,
    required this.isMedico,
    required this.onRefresh,
  });

  @override
  State<_OrdenDetalleSheet> createState() => _OrdenDetalleSheetState();
}

class _OrdenDetalleSheetState extends State<_OrdenDetalleSheet> {
  bool _cambiandoEstado = false;

  Future<void> _iniciarProceso() async {
    setState(() => _cambiandoEstado = true);
    try {
      await widget.service.cambiarEstado(widget.orden.id, 'EN_PROCESO');
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kUrgente),
        );
      }
    }
    if (mounted) setState(() => _cambiandoEstado = false);
  }

  void _abrirSubirResultado(BuildContext ctx) {
    Navigator.pop(ctx);
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubirResultadoSheet(
        ordenId: widget.orden.id,
        service: widget.service,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  void _verResultado(BuildContext ctx) {
    final resultado = widget.orden.resultado;
    if (resultado == null) return;

    if (resultado.tieneArchivo) {
      showDialog<void>(
        context: ctx,
        builder: (_) => _VisorArchivo(
          resultado: resultado,
          baseUrl: widget.service.baseUrl,
        ),
      );
    } else {
      showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Resultado del Estudio'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (resultado.valoresResultado != null) ...[
                  const Text(
                    'Valores:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(resultado.valoresResultado!),
                  const SizedBox(height: 12),
                ],
                if (resultado.interpretacionMedica != null) ...[
                  const Text(
                    'Interpretación:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(resultado.interpretacionMedica!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orden = widget.orden;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (orden.urgente) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kUrgente,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'URGENTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      orden.correlativoOrden,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  _EstadoChip(estado: orden.estado),
                ],
              ),
            ),

            const Divider(height: 16),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _InfoRow('Tipo', orden.tipoLabel),
                  if (orden.medicoNombre != null)
                    _InfoRow('Médico', orden.medicoNombre!),
                  if (orden.pacienteNombre != null)
                    _InfoRow('Paciente', orden.pacienteNombre!),
                  if (orden.fechaSolicitud != null)
                    _InfoRow('Fecha', _fmt(orden.fechaSolicitud!)),
                  const SizedBox(height: 12),
                  _Subtitulo('Descripción'),
                  const SizedBox(height: 4),
                  Text(
                    orden.descripcion,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  _Subtitulo('Indicación Clínica'),
                  const SizedBox(height: 4),
                  Text(
                    orden.indicacionClinica,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (orden.motivoUrgencia != null && orden.urgente) ...[
                    const SizedBox(height: 10),
                    _Subtitulo('Motivo de Urgencia', color: _kUrgente),
                    const SizedBox(height: 4),
                    Text(
                      orden.motivoUrgencia!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],

                  // Resultado disponible
                  if (orden.resultado != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kSuccess.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kSuccess.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: _kSuccess,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resultado disponible',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _kSuccess,
                                  ),
                                ),
                                if (orden.resultado!.nombreArchivo != null)
                                  Text(
                                    orden.resultado!.nombreArchivo!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _kGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Acciones
                  if (widget.isLaboratorio && orden.puedeIniciar)
                    _ActionBtn(
                      label: 'Iniciar procesamiento',
                      icon: Icons.play_circle_outline,
                      color: _kPrimary,
                      loading: _cambiandoEstado,
                      onTap: _iniciarProceso,
                    ),

                  if (widget.isLaboratorio && orden.puedeSubirResultado) ...[
                    const SizedBox(height: 10),
                    _ActionBtn(
                      label: 'Subir resultado',
                      icon: Icons.upload_file_outlined,
                      color: _kAccent,
                      onTap: () => _abrirSubirResultado(context),
                    ),
                  ],

                  if (orden.resultado != null) ...[
                    const SizedBox(height: 10),
                    _ActionBtn(
                      label: 'Ver resultado',
                      icon: Icons.visibility_outlined,
                      color: _kSuccess,
                      onTap: () => _verResultado(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${_p(dt.day)}/${_p(dt.month)}/${dt.year}';
  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: SUBIR RESULTADO
// ─────────────────────────────────────────────────────────────────────────────

class _SubirResultadoSheet extends StatefulWidget {
  final int ordenId;
  final EstudiosService service;
  final VoidCallback onSuccess;

  const _SubirResultadoSheet({
    required this.ordenId,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_SubirResultadoSheet> createState() => _SubirResultadoSheetState();
}

class _SubirResultadoSheetState extends State<_SubirResultadoSheet> {
  final _valoresCtrl = TextEditingController();
  final _interpCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  Uint8List? _archivoBytes;
  String? _archivoNombre;
  String? _archivoMime;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _valoresCtrl.dispose();
    _interpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final f = result.files.single;
      setState(() {
        _archivoBytes = f.bytes;
        _archivoNombre = f.name;
        _archivoMime = _mime(f.extension ?? '');
      });
    }
  }

  String _mime(String ext) => switch (ext.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'application/octet-stream',
      };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.service.subirResultado(
        ordenId: widget.ordenId,
        fechaResultado: _fecha.toIso8601String(),
        archivoBytes: _archivoBytes,
        archivoNombre: _archivoNombre,
        archivoMime: _archivoMime,
        valoresResultado:
            _valoresCtrl.text.trim().isEmpty ? null : _valoresCtrl.text.trim(),
        interpretacionMedica:
            _interpCtrl.text.trim().isEmpty ? null : _interpCtrl.text.trim(),
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Subir Resultado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_error != null) _ErrorBanner(message: _error!),

            // Fecha
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _kGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year}',
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 16, color: _kGrey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Archivo
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _archivoBytes != null
                      ? _kAccent.withValues(alpha: 0.05)
                      : null,
                  border: Border.all(
                    color: _archivoBytes != null
                        ? _kAccent
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _archivoBytes != null
                          ? Icons.attach_file
                          : Icons.upload_file_outlined,
                      size: 18,
                      color: _archivoBytes != null ? _kAccent : _kGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _archivoNombre ??
                            'Adjuntar archivo (PDF, JPG, PNG)',
                        style: TextStyle(
                          fontSize: 13,
                          color: _archivoBytes != null ? _kAccent : _kGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_archivoBytes != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _archivoBytes = null;
                          _archivoNombre = null;
                          _archivoMime = null;
                        }),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: _kGrey,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _valoresCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Valores del resultado',
                hintText: 'Ej: Hemoglobina 14.2 g/dL, Glucosa 95 mg/dL...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _interpCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Interpretación médica',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_submitting ? 'Guardando...' : 'Guardar Resultado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISOR DE ARCHIVO (imagen o PDF)
// ─────────────────────────────────────────────────────────────────────────────

class _VisorArchivo extends StatelessWidget {
  final ResultadoEstudioModel resultado;
  final String baseUrl;
  const _VisorArchivo({required this.resultado, required this.baseUrl});

  String get _url {
    final a = resultado.archivoAdjunto ?? '';
    return a.startsWith('http') ? a : '$baseUrl$a';
  }

  Future<void> _abrirEnNavegador() async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esImagen = resultado.esImagen;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra superior
            Container(
              color: const Color(0xFF122268),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      resultado.nombreArchivo ?? 'Resultado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_browser,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: _abrirEnNavegador,
                    tooltip: 'Abrir en navegador',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (esImagen)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: InteractiveViewer(
                  child: Image.network(
                    _url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: _kGrey,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _abrirEnNavegador,
                            icon: const Icon(Icons.open_in_browser, size: 16),
                            label: const Text('Abrir en navegador'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 64,
                      color: _kUrgente,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      resultado.nombreArchivo ?? 'Documento PDF',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'El visor PDF integrado no está disponible.\nAbre el archivo en tu navegador.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _kGrey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _abrirEnNavegador,
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('Abrir PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kUrgente,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA DE ÉXITO
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String correlativo;
  final VoidCallback onNew;
  const _SuccessView({required this.correlativo, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kSuccess.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: _kSuccess,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Orden creada!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'La orden fue registrada exitosamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
              ),
              child: Text(
                correlativo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Nueva Orden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _kPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  (Color, String) get _info => switch (estado) {
        'SOLICITADA' => (_kWarning, 'SOLICITADA'),
        'EN_PROCESO' => (_kPrimary, 'EN PROCESO'),
        'COMPLETADA' => (_kSuccess, 'COMPLETADA'),
        'ANULADA' => (Colors.grey, 'ANULADA'),
        _ => (_kGrey, estado),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _kGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final String text;
  final Color color;
  const _Subtitulo(this.text, {this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: color,
      ),
    );
  }
}

class _PrioridadBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PrioridadBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool loading;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kUrgente.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kUrgente, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _kUrgente, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: _kGrey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
