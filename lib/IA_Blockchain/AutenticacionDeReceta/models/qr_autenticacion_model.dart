/// Sprint 5 — Respuesta del backend al generar el QR de autenticación.
/// El QR codifica [urlVerificacion]: una URL pública con un JWT firmado
/// que expira en [expiraEnSegundos] (5 minutos). Nunca contiene datos clínicos.
class QrAutenticacionModel {
  final String numeroReceta;
  final String token;
  final String urlVerificacion;
  final int expiraEnSegundos;
  final String expiraEn;

  QrAutenticacionModel({
    required this.numeroReceta,
    required this.token,
    required this.urlVerificacion,
    required this.expiraEnSegundos,
    required this.expiraEn,
  });

  factory QrAutenticacionModel.fromJson(Map<String, dynamic> j) =>
      QrAutenticacionModel(
        numeroReceta: j['numero_receta'] ?? '',
        token: j['token'] ?? '',
        urlVerificacion: j['url_verificacion'] ?? '',
        expiraEnSegundos: j['expira_en_segundos'] ?? 300,
        expiraEn: j['expira_en'] ?? '',
      );
}
