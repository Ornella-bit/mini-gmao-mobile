import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'intervention_page.dart';

class DetailPage extends StatefulWidget {
  final int equipementId;
  final String nom;

  const DetailPage({super.key, required this.equipementId, required this.nom});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Future<Map<String, dynamic>> _detail;
  List<Map<String, dynamic>> _pannesOuvertes = [];

  @override
  void initState() {
    super.initState();
    _detail = _charger();
  }

  Future<Map<String, dynamic>> _charger() async {
    final reponse = await http
        .get(Uri.parse('$apiUrl/equipements/${widget.equipementId}'))
        .timeout(const Duration(seconds: 20));
    if (reponse.statusCode != 200) {
      throw Exception('Erreur serveur (${reponse.statusCode})');
    }
    final donnees =
        jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
    _pannesOuvertes = (donnees['pannes'] as List<dynamic>)
        .where((p) => p['statut'] != 'Résolue')
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    return donnees;
  }

  void _recharger() {
    setState(() {
      _detail = _charger();
    });
  }

  Future<void> _ouvrirFormulaire() async {
    if (_pannesOuvertes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune panne à traiter pour cet équipement.')));
      return;
    }
    final enregistre = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => InterventionPage(pannes: _pannesOuvertes)),
    );
    if (enregistre == true && mounted) {
      _recharger();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention enregistrée.')));
    }
  }

  Color _couleurEtat(String etat) {
    switch (etat) {
      case 'En service':
      case 'Résolue':
        return const Color(0xFF2E8B57);
      case 'En panne':
      case 'Ouverte':
        return const Color(0xFFC0392B);
      default:
        return const Color(0xFFE08E0B);
    }
  }

  Widget _badge(String texte) {
    final couleur = _couleurEtat(texte);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texte,
          style: TextStyle(color: couleur, fontWeight: FontWeight.bold)),
    );
  }

  Widget _titre(String texte) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(texte,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: bleu)),
    );
  }

  Widget _ligne(String label, Object? valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text('${valeur ?? 'Non renseigné'}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        title: Text(widget.nom,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        onPressed: _ouvrirFormulaire,
        icon: const Icon(Icons.build),
        label: const Text('Intervention'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detail,
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
                    const Text('Impossible de charger cet équipement.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _recharger, child: const Text('Réessayer')),
                  ],
                ),
              ),
            );
          }

          final d = snapshot.data!;
          final pannes = d['pannes'] as List<dynamic>;
          final interventions = d['interventions'] as List<dynamic>;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ligne('Catégorie', d['categorie']),
                      _ligne('Lieu', d['lieu']),
                      _ligne('Installé le', d['date_installation']),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const SizedBox(
                              width: 100,
                              child: Text('État',
                                  style: TextStyle(color: Colors.grey))),
                          _badge((d['etat'] ?? '').toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _titre('Pannes (${pannes.length})'),
              if (pannes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Aucune panne enregistrée.'),
                ),
              for (final p in pannes)
                Card(
                  child: ListTile(
                    title: Text(p['description'].toString()),
                    subtitle: Text(
                        'Déclarée le ${p['date_declaration']} · Gravité : ${p['gravite']}'),
                    trailing: _badge(p['statut'].toString()),
                  ),
                ),
              _titre('Interventions (${interventions.length})'),
              if (interventions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Aucune intervention enregistrée.'),
                ),
              for (final i in interventions)
                Card(
                  child: ListTile(
                    title: Text('${i['technicien']} · ${i['date_intervention']}'),
                    subtitle: Text(
                        '${i['description']}${i['duree_heures'] != null ? '\nDurée : ${i['duree_heures']} h' : ''}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}