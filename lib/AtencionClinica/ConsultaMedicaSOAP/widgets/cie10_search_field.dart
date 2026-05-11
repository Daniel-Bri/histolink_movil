import 'dart:async';
import 'package:flutter/material.dart';
import '../services/consulta_service.dart';

class Cie10SearchField extends StatefulWidget {
  final Function(Map<String, dynamic>?) onSelected;
  final Map<String, dynamic>? initialValue;
  final bool isReadOnly;
  final String? errorText;

  const Cie10SearchField({
    super.key,
    required this.onSelected,
    this.initialValue,
    this.isReadOnly = false,
    this.errorText,
  });

  @override
  State<Cie10SearchField> createState() => _Cie10SearchFieldState();
}

class _Cie10SearchFieldState extends State<Cie10SearchField> {
  final TextEditingController _controller = TextEditingController();
  final ConsultaService _service = ConsultaService();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounce;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _selected = widget.initialValue;
      _controller.text = "${_selected!['codigo']} - ${_selected!['descripcion']}";
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (query.length < 1) { // Cambiado de 2 a 1 para que busque con el primer caracter
        setState(() => _results = []);
        return;
      }

      setState(() => _isLoading = true);
      try {
        final results = await _service.searchCIE10(query);
        
        // MODO DEMO LOCAL: Si el servidor no devuelve resultados (error 403 o 404), mostrar catálogo de prueba
        if (results.isEmpty) {
          final queryUpper = query.toUpperCase();
          final demoCie10 = [
            {"codigo": "A00", "descripcion": "Cólera"},
            {"codigo": "A01", "descripcion": "Fiebre tifoidea"},
            {"codigo": "B01", "descripcion": "Varicela"},
            {"codigo": "E11.9", "descripcion": "Diabetes Mellitus tipo 2"},
            {"codigo": "I10", "descripcion": "Hipertensión esencial"},
            {"codigo": "J00", "descripcion": "Rinofaringitis aguda"},
            {"codigo": "K29.0", "descripcion": "Gastritis aguda"},
            {"codigo": "N39.0", "descripcion": "Infección de vías urinarias"},
          ].where((item) => 
            item['codigo']!.contains(queryUpper) || 
            item['descripcion']!.toUpperCase().contains(queryUpper)
          ).toList();
          setState(() => _results = demoCie10);
        } else {
          setState(() => _results = results);
        }
      } catch (e) {
        print("DEBUG: Error buscando CIE10, activando catálogo demo: $e");
        // Catálogo de emergencia si falla la red por completo
        final queryUpper = query.toUpperCase();
        final emergencyCie10 = [
          {"codigo": "A00", "descripcion": "Cólera"},
          {"codigo": "E11.9", "descripcion": "Diabetes"},
          {"codigo": "J00", "descripcion": "Resfriado común"},
        ].where((item) => 
          item['codigo']!.contains(queryUpper) || 
          item['descripcion']!.toUpperCase().contains(queryUpper)
        ).toList();
        setState(() => _results = emergencyCie10);
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Diagnóstico Principal (CIE-10)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_selected != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${_selected!['codigo']} - ${_selected!['descripcion']}",
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w600),
                  ),
                ),
                if (!widget.isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _selected = null;
                        _controller.clear();
                      });
                      widget.onSelected(null);
                    },
                  ),
              ],
            ),
          )
        else
          TextFormField(
            controller: _controller,
            readOnly: widget.isReadOnly,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Escriba código o descripción...",
              prefixIcon: const Icon(Icons.search),
              errorText: widget.errorText,
              suffixIcon: _isLoading ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (_results.isNotEmpty && _selected == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item['codigo'] ?? ''),
                  subtitle: Text(item['descripcion'] ?? ''),
                  onTap: () {
                    setState(() {
                      _selected = item;
                      _results = [];
                    });
                    widget.onSelected(item);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
