import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/widgets/paciente_card.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/screens/paciente_form_screen.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/screens/paciente_detalle_screen.dart';

class PacienteListScreen extends StatefulWidget {
  const PacienteListScreen({super.key});

  @override
  State<PacienteListScreen> createState() => _PacienteListScreenState();
}

class _PacienteListScreenState extends State<PacienteListScreen> {
  final _searchCtrl = TextEditingController();
  final _service = PacienteService();

  List<PacienteModel> _items = [];
  bool _loading = false;
  String? _error;
  bool _buscoAlgunaVez = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    _error = null;
    try {
      final list = await _service.listar(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text);
      if (!mounted) return;
      setState(() {
        _items = list;
        _buscoAlgunaVez = true;
      });
    } on PacienteApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFDC2626)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Pacientes'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PacienteFormScreen()),
          );
          if (!context.mounted) return;
          if (ok == true) {
            await _cargar(silent: true);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paciente registrado correctamente'), backgroundColor: AppColors.mentaVibrante),
            );
          }
        },
        backgroundColor: AppColors.azulPuro,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: 'CI o nombre / apellido',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.azulElectrico),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _buscar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.azulElectrico,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded, size: 26),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.azulPuro,
              onRefresh: () => _cargar(silent: true),
              child: _loading && !_buscoAlgunaVez
                  ? const LoadingIndicator(message: 'Buscando pacientes…')
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _buscoAlgunaVez ? 'Sin resultados' : 'Busca por CI o nombre',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                _buscoAlgunaVez
                                    ? 'Prueba con otros términos o registra un paciente nuevo.'
                                    : 'Escribe en el campo superior y pulsa la lupa, o desliza hacia abajo para cargar el listado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 88),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final p = _items[i];
                            return PacienteCard(
                              paciente: p,
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PacienteDetalleScreen(pacienteId: p.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
