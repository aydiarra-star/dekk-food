/// Carte interactive des établissements.
///
/// POLITIQUE DE POSITION (explicite et vérifiable) :
///  - une fiche n'est marquée que si ses coordonnées sont exploitables
///    (présentes et dans l'emprise du Sénégal) ;
///  - une coordonnée disponible n'est PAS une coordonnée confirmée : les
///    positions non confirmées sont affichées à titre indicatif, avec un
///    pictogramme, une couleur et une légende distincts ;
///  - aucune position estimée ne peut devenir « confirmée » dans l'application :
///    seul le champ gps_verifie (renseigné par une vérification recevable,
///    côté données) change cet état ;
///  - les fiches sans coordonnées exploitables sont listées à part, sans
///    position inventée.
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
    // Coordonnées exploitables uniquement (les valeurs aberrantes sont traitées
    // comme absentes par le modèle).
    final positionnes =
        etablissements.where((element) => element.coordonneesValides).toList(growable: false);
    final sansPosition =
        etablissements.where((element) => !element.coordonneesValides).toList(growable: false);

    final confirmees =
        positionnes.where((element) => element.positionConfirmee).toList(growable: false);
    final indicatives =
        positionnes.where((element) => !element.positionConfirmee).toList(growable: false);

    final points = positionnes
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
                        for (final etablissement in positionnes)
                          Marker(
                            point: LatLng(etablissement.latitude!, etablissement.longitude!),
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () => _ouvrirFiche(context, etablissement),
                              child: Tooltip(
                                // Le libellé dit toujours l'état réel de la position.
                                message: '${etablissement.nom}\n${etablissement.etatPosition}',
                                child: Icon(
                                  etablissement.positionConfirmee
                                      ? Icons.location_on
                                      : Icons.location_on_outlined,
                                  size: 38,
                                  // Position confirmée : vert plein (comme avant).
                                  // Position indicative : couleur de marque, pictogramme
                                  // creux — l'incertitude est visible sans casser l'identité.
                                  color: etablissement.positionConfirmee
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
                  message: _bilanPosition(positionnes, confirmees, indicatives),
                ),
              ),
              if (positionnes.isNotEmpty)
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: _LegendePosition(),
                ),
            ],
          ),
        ),
        if (sansPosition.isNotEmpty)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    '${sansPosition.length} fiche(s) sans coordonnées exploitables',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: sansPosition.length,
                    itemBuilder: (context, index) {
                      final etablissement = sansPosition[index];
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

  /// Bilan chiffré : jamais de formulation laissant croire que toutes les
  /// positions affichées sont vérifiées.
  static String _bilanPosition(
    List<Etablissement> positionnes,
    List<Etablissement> confirmees,
    List<Etablissement> indicatives,
  ) {
    if (positionnes.isEmpty) {
      return 'Aucune position exploitable dans cette sélection. Aucune position n\'est inventée : '
          'les fiches sans coordonnées sont listées sous la carte.';
    }
    if (confirmees.isEmpty) {
      return '${positionnes.length} fiche(s) positionnée(s) : ${indicatives.length} position(s) '
          'INDICATIVE(S) (coordonnées publiées, non vérifiées sur place), '
          '0 position confirmée.';
    }
    return '${positionnes.length} fiche(s) positionnée(s) : '
        '${confirmees.length} position(s) confirmée(s), '
        '${indicatives.length} indicative(s) (non vérifiée(s) sur place).';
  }

  void _ouvrirFiche(BuildContext context, Etablissement etablissement) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FicheScreen(etablissement: etablissement)),
    );
  }
}

/// Légende de la carte : elle explique la différence entre les deux pictogrammes.
class _LegendePosition extends StatelessWidget {
  const _LegendePosition();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.92 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: Color(0xFF2E7D32)),
              SizedBox(width: 4),
              Text('Position confirmée', style: TextStyle(fontSize: 11)),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: couleurPrincipale),
              SizedBox(width: 4),
              Text('Position indicative (non vérifiée)', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
