import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class InterventionPage extends StatefulWidget {
  final List<Map<String, dynamic>> pannes; // pannes non résolues

  const InterventionPage({super.key, required this.pannes});

  @override
  State<InterventionPage> createState() => _InterventionPageState();
}

class _InterventionPageState extends State<InterventionPage> {
  final _formKey = GlobalKey<FormState>();
  final _technicien = TextEditingController();
  final _description = TextEditingController();
  final _duree = TextEditingController();
  late int _panneId;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _panneId = widget.pannes.first['id'] as int;
  }

  @override
  void dispose() {
    _technicien.dispose();
    _description.dispose();
    _duree.dispose();
    super.dispose();
  }

  void _afficher(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _envoyer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      final duree = _duree.text.trim().replaceAll(',', '.');
      final corps = {
        'technicien': _technicien.text.trim(),
        'description': _description.text.trim(),
        'duree_heures': duree.isEmpty ? null : double.parse(duree),
      };
      final reponse = await http
          .post(
            Uri.parse('$apiUrl/pannes/$_panneId/interventions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(corps),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (reponse.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        var message = 'Erreur (${reponse.statusCode})';
        try {
          final donnees = jsonDecode(utf8.decode(reponse.bodyBytes));
          message = donnees['erreur']?.toString() ?? message;
        } catch (_) {}
        _afficher(message);
      }
    } catch (_) {
      if (mounted) _afficher('Connexion impossible. Réessaie.');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        title: const Text('Nouvelle intervention',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _panneId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Panne concernée', border: OutlineInputBorder()),
              items: [
                for (final p in widget.pannes)
                  DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text(
                      '${p['description']} (${p['date_declaration']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _panneId = v ?? _panneId),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _technicien,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Technicien', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Description du travail effectué',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _duree,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Durée en heures (facultatif)',
                  border: OutlineInputBorder()),
              validator: (v) {
                final t = (v ?? '').trim().replaceAll(',', '.');
                if (t.isNotEmpty && double.tryParse(t) == null) {
                  return 'Nombre invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: bleu,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _envoi ? null : _envoyer,
              icon: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_envoi ? 'Envoi...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
