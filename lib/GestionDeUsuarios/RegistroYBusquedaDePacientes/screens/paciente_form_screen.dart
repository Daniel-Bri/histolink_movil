import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/custom_text_field.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';

class PacienteFormScreen extends StatefulWidget {
  const PacienteFormScreen({super.key});

  @override
  State<PacienteFormScreen> createState() => _PacienteFormScreenState();
}

class _PacienteFormScreenState extends State<PacienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _comp = TextEditingController();
  final _nombres = TextEditingController();
  final _apPaterno = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _dir = TextEditingController();
  final _fechaCtrl = TextEditingController();

  final _service = PacienteService();

  DateTime? _fechaNac;
  String _sexo = 'M';
  bool _guardando = false;

  static final _soloLetrasEspacios = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ ']+$");
  static final _emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  @override
  void dispose() {
    _ci.dispose();
    _comp.dispose();
    _nombres.dispose();
    _apPaterno.dispose();
    _email.dispose();
    _tel.dispose();
    _dir.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNac ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.azulElectrico, secondary: AppColors.mentaVibrante),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaNac = picked;
        _fechaCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  String? _vCi(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'El CI es obligatorio';
    if (!RegExp(r'^\d{4,10}$').hasMatch(s)) return 'CI: solo números, entre 4 y 10 dígitos';
    return null;
  }

  String? _vComp(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z0-9]{1,2}$').hasMatch(s)) return 'Máximo 2 caracteres alfanuméricos';
    return null;
  }

  String? _vNombres(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Los nombres son obligatorios';
    if (!_soloLetrasEspacios.hasMatch(s)) return 'Solo letras y espacios';
    return null;
  }

  String? _vApellido(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'El apellido paterno es obligatorio';
    if (!_soloLetrasEspacios.hasMatch(s)) return 'Solo letras y espacios';
    return null;
  }

  String? _vEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (!_emailOk.hasMatch(s)) return 'Email no válido';
    return null;
  }

  String? _vTel(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d{7,15}$').hasMatch(s)) return 'Teléfono: 7 a 15 dígitos';
    return null;
  }

  String _fechaIso() {
    if (_fechaNac == null) return '';
    final d = _fechaNac!;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _guardar() async {
    if (_fechaNac == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de nacimiento'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final modelo = PacienteModel(
        id: 0,
        ci: _ci.text.trim(),
        ciComplemento: _comp.text.trim().isEmpty ? null : _comp.text.trim(),
        nombres: _nombres.text.trim(),
        apellidoPaterno: _apPaterno.text.trim(),
        fechaNacimiento: _fechaIso(),
        sexo: _sexo,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        telefono: _tel.text.trim().isEmpty ? null : _tel.text.trim(),
        direccion: _dir.text.trim().isEmpty ? null : _dir.text.trim(),
      );
      await _service.crear(modelo);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PacienteApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se pudo guardar'),
          content: SingleChildScrollView(child: Text(e.message)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Registrar paciente'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            CustomTextField(
              controller: _ci,
              label: 'CI *',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _vCi,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _comp,
              label: 'Complemento CI (opcional)',
              inputFormatters: [LengthLimitingTextInputFormatter(2)],
              validator: _vComp,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _nombres,
              label: 'Nombres *',
              textCapitalization: TextCapitalization.words,
              validator: _vNombres,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _apPaterno,
              label: 'Apellido paterno *',
              textCapitalization: TextCapitalization.words,
              validator: _vApellido,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              readOnly: true,
              onTap: _elegirFecha,
              label: 'Fecha de nacimiento *',
              controller: _fechaCtrl,
              hint: 'Toca para elegir',
              suffixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.azulElectrico),
            ),
            const SizedBox(height: 8),
            const Text('Sexo *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azulElectrico)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'M', label: Text('Masc.'), tooltip: 'Masculino'),
                ButtonSegment<String>(value: 'F', label: Text('Fem.'), tooltip: 'Femenino'),
                ButtonSegment<String>(value: 'O', label: Text('Otro'), tooltip: 'Otro'),
              ],
              selected: {_sexo},
              onSelectionChanged: (Set<String> selection) {
                if (selection.isNotEmpty) setState(() => _sexo = selection.first);
              },
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _email,
              label: 'Email (opcional)',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: _vEmail,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _tel,
              label: 'Teléfono (opcional)',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _vTel,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _dir,
              label: 'Dirección (opcional)',
              maxLines: 2,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azulPuro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azulElectrico,
                  side: const BorderSide(color: AppColors.azulElectrico),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
