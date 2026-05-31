import 'package:flutter/material.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/screens/login_screen.dart';
import 'package:histolink/shared/theme/app_colors.dart';

class ErrorScreen extends StatelessWidget {
  final int statusCode;
  final String? mensaje;

  const ErrorScreen({super.key, required this.statusCode, this.mensaje});

  _ErrorInfo _info() {
    switch (statusCode) {
      case 400:
        return _ErrorInfo(
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFF59E0B),
          titulo: 'Error de validación',
          descripcion:
              'Los datos enviados no son válidos. Revisa los campos e intenta de nuevo.',
        );
      case 401:
        return _ErrorInfo(
          icon: Icons.lock_outline_rounded,
          color: const Color(0xFFEF4444),
          titulo: 'No autorizado',
          descripcion:
              'Tu sesión ha expirado o no tienes credenciales válidas. Por favor inicia sesión nuevamente.',
        );
      case 403:
        return _ErrorInfo(
          icon: Icons.block_rounded,
          color: const Color(0xFFEF4444),
          titulo: 'Acceso denegado',
          descripcion:
              'No tienes permisos suficientes para acceder a esta sección. Contacta al administrador si crees que esto es un error.',
        );
      case 404:
        return _ErrorInfo(
          icon: Icons.search_off_rounded,
          color: const Color(0xFF6B7280),
          titulo: 'No encontrado',
          descripcion: 'El recurso solicitado no existe o fue eliminado.',
        );
      case 500:
        return _ErrorInfo(
          icon: Icons.cloud_off_rounded,
          color: const Color(0xFF6B7280),
          titulo: 'Error del servidor',
          descripcion:
              'Ocurrió un problema en el servidor. Intenta más tarde o contacta al soporte técnico.',
        );
      default:
        return _ErrorInfo(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFF6B7280),
          titulo: 'Error inesperado',
          descripcion: 'Ocurrió un error desconocido. Por favor intenta de nuevo.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info();
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        title: Text('Error $statusCode'),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: info.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(info.icon, size: 44, color: info.color),
              ),
              const SizedBox(height: 24),
              Text(
                '$statusCode',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: info.color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                info.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                info.descripcion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (mensaje != null && mensaje!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: info.color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: info.color.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: info.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mensaje!,
                          style: TextStyle(
                            fontSize: 13,
                            color: info.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (canGoBack)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azulElectrico,
                      side: const BorderSide(color: AppColors.azulElectrico),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (statusCode == 401) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                      (_) => false,
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Ir al inicio de sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulElectrico,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color color;
  final String titulo;
  final String descripcion;

  const _ErrorInfo({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.descripcion,
  });
}
