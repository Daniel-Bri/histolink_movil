import 'package:flutter/material.dart';
import 'package:histolink/AtencionClinica/EmisionDeRecetaMedica/models/receta_model.dart';
import 'package:histolink/shared/theme/app_colors.dart';

import 'qr_autenticacion_screen.dart';

const _card = Colors.white;
const _border = Color(0xFFE8ECF4);
const _labelText = Color(0xFF6B7280);
const _bodyText = Color(0xFF1A1A2E);

String _fecha(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Sprint 5 — Vista legible de las recetas de una consulta, con su fecha de
/// vencimiento legal y el botón "Generar QR de Autenticación".
class RecetasDeConsultaScreen extends StatelessWidget {
  const RecetasDeConsultaScreen({
    super.key,
    required this.recetas,
    required this.tituloConsulta,
  });

  final List<RecetaModel> recetas;
  final String tituloConsulta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Receta Médica'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            tituloConsulta,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelText,
            ),
          ),
          const SizedBox(height: 12),
          ...recetas.map((r) => _RecetaCard(receta: r)),
        ],
      ),
    );
  }
}

class _RecetaCard extends StatelessWidget {
  const _RecetaCard({required this.receta});
  final RecetaModel receta;

  bool get _vencida {
    final v = receta.fechaVencimiento;
    if (v == null) return false;
    final d = DateTime.tryParse(v);
    return d != null && DateTime.now().isAfter(d);
  }

  @override
  Widget build(BuildContext context) {
    final anulada = receta.estado == 'ANULADA';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ─────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.azulElectrico, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  receta.numeroReceta,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _bodyText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: anulada
                      ? const Color(0xFFFDECEC)
                      : receta.estado == 'DISPENSADA'
                          ? AppColors.mentaSuave
                          : AppColors.azulCielo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  receta.estado,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: anulada
                        ? Colors.redAccent
                        : receta.estado == 'DISPENSADA'
                            ? AppColors.mentaVibrante
                            : AppColors.azulElectrico,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Fechas de emisión y vencimiento legal ────────────────────
          Row(
            children: [
              _FechaChip(
                icon: Icons.event_outlined,
                label: 'Emitida',
                valor: _fecha(receta.fechaEmision),
              ),
              const SizedBox(width: 10),
              _FechaChip(
                icon: Icons.event_busy_outlined,
                label: 'Vence',
                valor: _fecha(receta.fechaVencimiento),
                danger: _vencida,
              ),
            ],
          ),
          if (_vencida) ...[
            const SizedBox(height: 8),
            const Text(
              'Esta receta superó su vigencia legal.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 10),

          // ── Medicamentos ─────────────────────────────────────────────
          const Text('Medicamentos',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _labelText)),
          const SizedBox(height: 6),
          ...receta.detalles.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.medicamento}'
                    '${d.concentracion.isNotEmpty ? ' ${d.concentracion}' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _bodyText),
                  ),
                  Text(
                    '${d.dosis} · ${d.frecuencia} · ${d.duracion}'
                    '${d.cantidadTotal.isNotEmpty ? ' · Total: ${d.cantidadTotal}' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: _labelText),
                  ),
                  if (d.instrucciones.isNotEmpty)
                    Text(d.instrucciones,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: _labelText)),
                ],
              ),
            ),
          ),
          if (receta.observaciones.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Observaciones',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _labelText)),
            const SizedBox(height: 2),
            Text(receta.observaciones,
                style: const TextStyle(fontSize: 12.5, color: _bodyText)),
          ],
          const SizedBox(height: 14),

          // ── Botón Generar QR ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: anulada || receta.uuid.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => QrAutenticacionScreen(
                            recetaUuid: receta.uuid,
                            numeroReceta: receta.numeroReceta,
                          ),
                        ),
                      ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              label: Text(
                anulada
                    ? 'Receta anulada — sin QR'
                    : 'Generar QR de Autenticación (válido 5 min)',
                style: const TextStyle(fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulElectrico,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FechaChip extends StatelessWidget {
  const _FechaChip({
    required this.icon,
    required this.label,
    required this.valor,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String valor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : AppColors.azulElectrico;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFDECEC) : AppColors.fondo,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: _labelText)),
                Text(valor,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
