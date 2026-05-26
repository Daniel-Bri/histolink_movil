import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:histolink/IA_Blockchain/PrediccionDeRiesgosClinicos/models/riesgo_model.dart';

/// Widget de estado que muestra la lista de riesgos clínicos del paciente.
///
/// ISO 25010 – Usabilidad:
///   1. Feedback háptico: vibra al detectar al menos un nivel CRÍTICO o ALTO.
///   2. Accesibilidad táctil: tarjetas grandes que se expanden suavemente con
///      AnimatedSize al presionarlas, revelando la recomendación médica.
class RiesgoClinicoWidget extends StatefulWidget {
  const RiesgoClinicoWidget({super.key, required this.data});

  /// Mapa JSON directo del endpoint /api/ia/riesgo/.
  final Map<String, dynamic> data;

  @override
  State<RiesgoClinicoWidget> createState() => _RiesgoClinicoWidgetState();
}

class _RiesgoClinicoWidgetState extends State<RiesgoClinicoWidget> {
  late final List<RiesgoItem> _items;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _items = RiesgoItem.fromApiResponse(widget.data);

    // ISO 25010 – Feedback háptico: vibración inmediata si hay riesgo urgente.
    if (_items.any((e) => e.esUrgente)) {
      HapticFeedback.vibrate();
    }
  }

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No hay datos de riesgo disponibles para este paciente.',
            style: TextStyle(color: Colors.grey, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _RiesgoCard(
        item: _items[i],
        expanded: _expanded.contains(i),
        onTap: () => _toggle(i),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta individual

class _RiesgoCard extends StatelessWidget {
  const _RiesgoCard({
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final RiesgoItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // ISO 25010 – área de toque grande: cubre toda la tarjeta.
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            // Padding vertical generoso → altura mínima de ~80 px para el pulgar.
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila de cabecera ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Indicador de color semántico
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Porcentaje destacado
                    Text(
                      '${item.probabilidad.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Flecha animada que rota al expandir
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Barra de progreso ──────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.probabilidad / 100,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 7,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Chip de nivel de alerta ───────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(
                    item.nivelAlerta,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),

                // ── Sección expandible (AnimatedSize) ────────────────────
                // ISO 25010 – expansión suave que revela detalles clínicos.
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(
                                height: 1,
                                color: color.withOpacity(0.25),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.label_outline_rounded,
                                color: color,
                                text: 'Clasificación: ${item.clasificacion}',
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.medical_services_outlined,
                                color: color,
                                text: item.recomendacion,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de detalle reutilizable

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
