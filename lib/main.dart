import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = 'https://ashley.pythonanywhere.com/api';
const Color bleu = Color(0xFF1F3A5F);

void main() => runApp(const MiniGmaoApp());

class MiniGmaoApp extends StatelessWidget {
  const MiniGmaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini-GMAO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: bleu),
        useMaterial3: true,
      ),
      home: const EquipementsPage(),
    );
  }
}

class EquipementsPage extends StatefulWidget {
  const EquipementsPage({super.key});

  @override
  State<EquipementsPage> createState() => _EquipementsPageState();
}

class _EquipementsPageState extends State<EquipementsPage> {
  late Future<List<dynamic>> _equipements;

  @override
  void initState() {
    super.initState();
    _equipements = _charger();
  }

  Future<List<dynamic>> _charger() async {
    final reponse = await http
        .get(Uri.parse('$apiUrl/equipements'))
        .timeout(const Duration(seconds: 20));
    if (reponse.statusCode != 200) {
      throw Exception('Erreur serveur (${reponse.statusCode})');
    }
    return jsonDecode(utf8.decode(reponse.bodyBytes)) as List<dynamic>;
  }

  void _recharger() {
    setState(() {
      _equipements = _charger();
    });
  }

  Color _couleurEtat(String etat) {
    switch (etat) {
      case 'En service':
        return const Color(0xFF2E8B57);
      case 'En panne':
        return const Color(0xFFC0392B);
      default:
        return const Color(0xFFE08E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        title: const Text('Mini-GMAO',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _equipements,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Impossible de charger les équipements.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _recharger, child: const Text('Réessayer')),
                  ],
                ),
              ),
            );
          }
          final equipements = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _recharger();
              try {
                await _equipements;
              } catch (_) {}
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: equipements.length,
              itemBuilder: (context, i) {
                final e = equipements[i];
                final etat = (e['etat'] ?? '').toString();
                final couleur = _couleurEtat(etat);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.precision_manufacturing, color: bleu),
                    title: Text(e['nom'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${e['categorie']} · ${e['lieu']}'),
                    trailing: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(etat,
                          style: TextStyle(
                              color: couleur, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
