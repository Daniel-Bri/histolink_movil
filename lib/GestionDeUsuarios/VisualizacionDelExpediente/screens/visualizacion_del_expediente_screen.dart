import 'package:flutter/material.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/models/expediente_resumido_model.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/services/expediente_service.dart';
import 'package:histolink/shared/theme/app_colors.dart';

// ── Paleta neutral ────────────────────────────────────────────────────────────
const _card      = Colors.white;
const _border    = Color(0xFFE8ECF4);
const _labelText = Color(0xFF6B7280);
const _bodyText  = Color(0xFF1A1A2E);
const _emptyText = Color(0xFFAAAAAA);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fechaHora(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

int? _edad(String fechaNac) {
  final d = DateTime.tryParse(fechaNac);
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class VisualizacionDelExpedienteScreen extends StatefulWidget {
  const VisualizacionDelExpedienteScreen({super.key, this.pacienteId});
  final int? pacienteId;

  @override
  State<VisualizacionDelExpedienteScreen> createState() =>
      _VisualizacionDelExpedienteScreenState();
}

class _VisualizacionDelExpedienteScreenState
    extends State<VisualizacionDelExpedienteScreen> {
  late final TextEditingController _idCtrl;
  final _service = ExpedienteService();

  bool _loading = false;
  String? _error;
  ExpedienteResumido? _exp;

  bool get _modoDirecto => widget.pacienteId != null;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.pacienteId?.toString() ?? '');
    _cargar();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final id = int.tryParse(_idCtrl.text.trim());
    if (id == null || id <= 0) {
      setState(() { _error = 'Ingresa un ID válido.'; _exp = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final exp = await _service.obtenerExpedienteResumido(id);
      if (!mounted) return;
      setState(() => _exp = exp);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _exp = null; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: Text(_exp != null
            ? '${_exp!.nombres} ${_exp!.apellidoPaterno}'
            : 'Expediente'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.azulPuro,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!_modoDirecto) ...[
              _BuscadorCard(ctrl: _idCtrl, loading: _loading, onBuscar: _cargar),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const _MensajeCard(icon: Icons.hourglass_top_rounded, texto: 'Cargando expediente…'),
            if (!_loading && _error != null)
              _MensajeCard(icon: Icons.error_outline_rounded, texto: _error!, danger: true),
            if (!_loading && _error == null && _exp != null) ...[
              _CabeceraCard(exp: _exp!),
              const SizedBox(height: 12),
              _AntecedentesCard(ant: _exp!.antecedentes),
              const SizedBox(height: 12),
              _AtencionesSectionCard(exp: _exp!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Buscador ──────────────────────────────────────────────────────────────────
class _BuscadorCard extends StatelessWidget {
  const _BuscadorCard({required this.ctrl, required this.loading, required this.onBuscar});
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onBuscar(),
            decoration: const InputDecoration(labelText: 'ID del paciente', prefixIcon: Icon(Icons.person_search_outlined), border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: loading ? null : onBuscar,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.azulElectrico,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Buscar'),
        ),
      ]),
    );
  }
}

// ── Cabecera ──────────────────────────────────────────────────────────────────
class _CabeceraCard extends StatelessWidget {
  const _CabeceraCard({required this.exp});
  final ExpedienteResumido exp;

  @override
  Widget build(BuildContext context) {
    final edad = _edad(exp.fechaNacimiento);
    final ci   = exp.ci + (exp.ciComplemento.isNotEmpty ? '-${exp.ciComplemento}' : '');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppColors.azulCielo, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.person_outline_rounded, color: AppColors.azulElectrico, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${exp.nombres} ${exp.apellidoPaterno}${exp.apellidoMaterno.isNotEmpty ? ' ${exp.apellidoMaterno}' : ''}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _bodyText),
            ),
            const SizedBox(height: 10),
            _InfoFila(icon: Icons.badge_outlined,    label: 'CI',         value: ci),
            if (edad != null)
              _InfoFila(icon: Icons.cake_outlined,   label: 'Edad',       value: '$edad años · ${exp.fechaNacimiento}'),
            if (exp.sexoLabel.isNotEmpty)
              _InfoFila(icon: Icons.wc_outlined,     label: 'Sexo',       value: exp.sexoLabel),
            if (exp.telefono.isNotEmpty)
              _InfoFila(icon: Icons.phone_outlined,  label: 'Teléfono',   value: exp.telefono),
          ]),
        ),
      ]),
    );
  }
}

class _InfoFila extends StatelessWidget {
  const _InfoFila({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: _labelText),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12.5, color: _labelText, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, color: _bodyText))),
      ]),
    );
  }
}

// ── Antecedentes ──────────────────────────────────────────────────────────────
class _AntecedentesCard extends StatelessWidget {
  const _AntecedentesCard({required this.ant});
  final AntecedentesResumen? ant;

  @override
  Widget build(BuildContext context) {
    return _SeccionCard(
      titulo: 'Antecedentes Médicos',
      icon: Icons.history_edu_outlined,
      child: ant == null
          ? const _Vacio(texto: 'Sin antecedentes registrados')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Grupo sanguíneo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _labelText)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.fondo,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    ant!.grupoSanguineo == '?' ? 'Desconocido' : ant!.grupoSanguineo,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _bodyText),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _AntRow(label: 'Alergias',                value: ant!.alergias),
              _AntRow(label: 'Antecedentes patológicos', value: ant!.antecedentesPatologicos),
              _AntRow(label: 'Medicación actual',        value: ant!.medicacionActual),
            ]),
    );
  }
}

class _AntRow extends StatelessWidget {
  const _AntRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _labelText, letterSpacing: 0.2)),
        const SizedBox(height: 3),
        Text(
          empty ? 'No registrado' : value,
          style: TextStyle(fontSize: 13, color: empty ? _emptyText : _bodyText, height: 1.45, fontStyle: empty ? FontStyle.italic : FontStyle.normal),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, color: _border),
      ]),
    );
  }
}

// ── Atenciones ────────────────────────────────────────────────────────────────
class _AtencionesSectionCard extends StatelessWidget {
  const _AtencionesSectionCard({required this.exp});
  final ExpedienteResumido exp;

  @override
  Widget build(BuildContext context) {
    return _SeccionCard(
      titulo: 'Historial de Atenciones',
      icon: Icons.medical_information_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SubTitulo(label: 'Triajes', count: exp.triajes.length),
        const SizedBox(height: 8),
        if (exp.triajes.isEmpty)
          const _Vacio(texto: 'Sin triajes registrados')
        else
          ...exp.triajes.map((t) => _TriajeItem(t: t)),
        const SizedBox(height: 14),
        _SubTitulo(label: 'Consultas', count: exp.consultas.length),
        const SizedBox(height: 8),
        if (exp.consultas.isEmpty)
          const _Vacio(texto: 'Sin consultas registradas')
        else
          ...exp.consultas.map((c) => _ConsultaItem(c: c)),
      ]),
    );
  }
}

class _SubTitulo extends StatelessWidget {
  const _SubTitulo({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _labelText, letterSpacing: 0.6)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: AppColors.fondo, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _labelText)),
      ),
    ]);
  }
}

class _TriajeItem extends StatelessWidget {
  const _TriajeItem({required this.t});
  final TriajeResumen t;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (t.nivelUrgenciaLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.fondo, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
              child: Text(t.nivelUrgenciaLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _bodyText)),
            ),
          const Spacer(),
          Text(_fechaHora(t.horaTriaje), style: const TextStyle(fontSize: 11, color: _labelText)),
        ]),
        if (t.motivoConsultaTriaje.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(t.motivoConsultaTriaje, style: const TextStyle(fontSize: 13, color: _bodyText, height: 1.4)),
        ],
      ]),
    );
  }
}

class _ConsultaItem extends StatelessWidget {
  const _ConsultaItem({required this.c});
  final ConsultaResumen c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (c.estadoLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.fondo, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
              child: Text(c.estadoLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _bodyText)),
            ),
          const Spacer(),
          Text(_fechaHora(c.creadoEn), style: const TextStyle(fontSize: 11, color: _labelText)),
        ]),
        if (c.motivoConsulta.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Motivo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _labelText)),
          const SizedBox(height: 2),
          Text(c.motivoConsulta, style: const TextStyle(fontSize: 13, color: _bodyText, height: 1.4)),
        ],
        if (c.impresionDiagnostica.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Diagnóstico', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _labelText)),
          const SizedBox(height: 2),
          Text(c.impresionDiagnostica, style: const TextStyle(fontSize: 13, color: _bodyText, height: 1.4)),
        ],
      ]),
    );
  }
}

// ── Componentes base ──────────────────────────────────────────────────────────
class _SeccionCard extends StatelessWidget {
  const _SeccionCard({required this.titulo, required this.icon, required this.child});
  final String titulo;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.azulElectrico),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _bodyText)),
        ]),
        const SizedBox(height: 4),
        const Divider(height: 18, color: _border),
        child,
      ]),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(texto, style: const TextStyle(fontSize: 13, color: _emptyText, fontStyle: FontStyle.italic)),
    );
  }
}

class _MensajeCard extends StatelessWidget {
  const _MensajeCard({required this.icon, required this.texto, this.danger = false});
  final IconData icon;
  final String texto;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF0F0) : _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? const Color(0xFFFFCDD2) : _border),
      ),
      child: Row(children: [
        Icon(icon, color: danger ? const Color(0xFFDC2626) : _labelText, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: danger ? const Color(0xFFDC2626) : _labelText))),
      ]),
    );
  }
}
