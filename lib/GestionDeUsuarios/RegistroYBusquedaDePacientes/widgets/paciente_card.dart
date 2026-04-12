import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';

class PacienteCard extends StatelessWidget {
  const PacienteCard({
    super.key,
    required this.paciente,
    required this.onTap,
  });

  final PacienteModel paciente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final edad = paciente.edadCalculada;
    final edadTexto = edad != null ? '$edad años' : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.azulCielo.withOpacity(0.6)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.azulCielo,
          child: Text(
            paciente.nombres.isNotEmpty ? paciente.nombres[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.azulElectrico,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          paciente.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('CI: ${paciente.ciCompleto}', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.cake_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(edadTexto, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ),
    );
  }
}
