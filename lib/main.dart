import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'detail_page.dart';

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
      // Limite l'agrandissement des textes pour que l'interface reste lisible
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
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
  final _controleur = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _equipements = _charger();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
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

  bool _correspond(dynamic e) {
    final texte =
        '${e['nom']} ${e['categorie']} ${e['lieu']} ${e['etat']}'.toLowerCase();
    return texte.contains(_recherche.toLowerCase().trim());
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

          final equipements = snapshot.data!.where(_correspond).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _controleur,
                  onChanged: (v) => setState(() => _recherche = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un équipement...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _recherche.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controleur.clear();
                              setState(() => _recherche = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _recharger();
                    try {
                      await _equipements;
                    } catch (_) {}
                  },
                  child: equipements.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                  child: Text('Aucun équipement trouvé.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: equipements.length,
                          itemBuilder: (context, i) {
                            final e = equipements[i];
                            final etat = (e['etat'] ?? '').toString();
                            final couleur = _couleurEtat(etat);
                            return Card(
                              child: ListTile(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailPage(
                                      equipementId: e['id'] as int,
                                      nom: e['nom'].toString(),
                                    ),
                                  ),
                                ).then((_) => _recharger()),
                                leading: const Icon(
                                    Icons.precision_manufacturing,
                                    color: bleu),
                                title: Text(e['nom'].toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle:
                                    Text('${e['categorie']} · ${e['lieu']}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: couleur.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(etat,
                                      style: TextStyle(
                                          color: couleur,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}