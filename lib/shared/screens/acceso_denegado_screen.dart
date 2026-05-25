import 'package:flutter/material.dart';

enum TipoAccesoDenegado { sinPermiso, sesionExpirada }

class AccesoDenegadoScreen extends StatelessWidget {
  final TipoAccesoDenegado tipo;
  final String? mensajePersonalizado;

  const AccesoDenegadoScreen({
    super.key,
    this.tipo = TipoAccesoDenegado.sinPermiso,
    this.mensajePersonalizado,
  });

  @override
  Widget build(BuildContext context) {
    final esSesion = tipo == TipoAccesoDenegado.sesionExpirada;

    final icono       = esSesion ? '🔐' : '🚫';
    final codigo      = esSesion ? 'ERROR 401' : 'ERROR 403';
    final titulo      = esSesion ? 'Sesión expirada' : 'Sin acceso';
    final descripcion = mensajePersonalizado ??
        (esSesion
            ? 'Tu sesión ha expirado o no tienes credenciales válidas. Inicia sesión para continuar.'
            : 'No tienes permisos para realizar esta acción. Contacta a tu administrador si crees que es un error.');
    final labelBtn    = esSesion ? 'Ir al login' : 'Volver al inicio';
    final colorPrin   = esSesion ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626);
    final colorBg     = esSesion ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2);
    final colorBorde  = esSesion ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Círculo con ícono
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorBorde, width: 2),
                  ),
                  child: Center(
                    child: Text(icono, style: const TextStyle(fontSize: 42)),
                  ),
                ),
                const SizedBox(height: 24),

                // Código HTTP
                Text(
                  codigo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorPrin.withValues(alpha: 0.7),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),

                // Título
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Descripción
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (esSesion) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrin,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      labelBtn,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botón volver
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      '← Volver atrás',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
