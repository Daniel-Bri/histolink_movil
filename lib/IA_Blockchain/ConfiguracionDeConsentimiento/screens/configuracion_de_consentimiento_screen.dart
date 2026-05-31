import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme/app_colors.dart';
import '../services/emergency_consent_service.dart';
import 'emergency_consent_screen.dart';

class ConfiguracionDeConsentimientoScreen extends StatefulWidget {
  const ConfiguracionDeConsentimientoScreen({super.key});

  @override
  State<ConfiguracionDeConsentimientoScreen> createState() => _ConfiguracionDeConsentimientoScreenState();
}

class _ConfiguracionDeConsentimientoScreenState extends State<ConfiguracionDeConsentimientoScreen> {
  final _service = EmergencyConsentService();
  List<Map<String, dynamic>> _consents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    setState(() => _isLoading = true);
    final data = await _service.fetchRegisteredConsents();
    setState(() {
      _consents = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Gestión de Consentimientos', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: AppColors.azulElectrico,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConsents,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _consents.isEmpty 
          ? _buildEmptyState()
          : _buildConsentTable(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmergencyConsentScreen()),
          );
          _loadConsents(); // Recargar al volver
        },
        backgroundColor: AppColors.azulElectrico,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No hay consentimientos registrados', 
            style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildConsentTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.azulElectrico.withOpacity(0.1)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Paciente', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Fecha Registro', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Vigencia', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _consents.map((c) {
            final date = DateTime.parse(c['fecha_hora']);
            // Cambio: Vigencia de 1 año (Punto 1 y 2)
            final vigencia = DateTime(date.year + 1, date.month, date.day, date.hour, date.minute);
            
            return DataRow(cells: [
              DataCell(Text(c['paciente_nombre'] ?? 'N/A')),
              DataCell(Text(c['procedimiento'] ?? 'Emergencia')),
              DataCell(_buildStatusChip('Activo')),
              DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(date))),
              DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(vigencia))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A9D8F).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Color(0xFF2A9D8F), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
