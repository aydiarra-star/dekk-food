/// Carte interactive des établissements.
///
/// CHOIX DE DONNÉES : seules les fiches dont les coordonnées GPS ont été
/// vérifiées sont marquées. Les fiches non géolocalisées sont listées à part
/// avec un lien de recherche textuelle — on n'invente jamais une position.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/catalogue.dart';
import '../widgets/communs.dart';
import 'fiche_screen.dart';

class CarteScreen extends StatelessWidget {
  final List<Etablissement> etablissements;

  const CarteScreen({super.key, required this.etablissements});

  @override
  Widget build(BuildContext context) {
    final geolocalises =
        etablissements.where((element) => element.aDesCoordonnees).toList(growable: false);
    final sansGps = etablissements.where((element) => !element.aDesCoordonnees).toList(growable: false);

    final points = geolocalises
        .map((element) => LatLng(element.latitude!, element.longitude!))
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(14.6928, -17.4467), // Dakar
                  initialZoom: 11.5,
                  initialCameraFit: points.length >= 2
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(50),
                          maxZoom: 14,
                        )
                      : null,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'sn.dekkfood.app',
                  ),
                  if (points.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (final etablissement in geolocalises)
                          Marker(
                            point: LatLng(etablissement.latitude!, etablissement.longitude!),
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () => _ouvrirFiche(context, etablissement),
                              child: Tooltip(
                                message: etablissement.nom,
                                child: Icon(
                                  Icons.location_on,
                                  size: 38,
                                  color: etablissement.estVerifie || etablissement.estPartiellementVerifie
                                      ? Colors.green.shade700
                                      : couleurPrincipale,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SimpleAttributionWidget(
                    source: Text('Fond de carte © OpenStreetMap'),
                  ),
                ],
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: BandeauInformation(
                  couleur: Colors.white,
                  icone: Icons.info_outline,
                  message: points.isEmpty
                      ? 'Aucune fiche géolocalisée dans cette sélection. Les coordonnées seront '
                          'ajoutées après vérification sur place.'
                      : '${points.length} fiche(s) géolocalisée(s) affichée(s). '
                          'La géolocalisation est vérifiée progressivement.',
                ),
              ),
            ],
          ),
        ),
        if (sansGps.isNotEmpty)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    '${sansGps.length} fiche(s) sans coordonnées vérifiées',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: sansGps.length,
                    itemBuilder: (context, index) {
                      final etablissement = sansGps[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_off_outlined, size: 20),
                        title: Text(etablissement.nom, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          etablissement.adresse ?? etablissement.localisation,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _ouvrirFiche(context, etablissement),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _ouvrirFiche(BuildContext context, Etablissement etablissement) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FicheScreen(etablissement: etablissement)),
    );
  }
}
