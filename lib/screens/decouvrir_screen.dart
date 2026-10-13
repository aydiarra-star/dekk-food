/// Écran « Découvrir » : recherche nationale, filtres, liste et carte.
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../models/catalogue.dart';
import '../widgets/communs.dart';
import 'carte_screen.dart';
import 'fiche_screen.dart';

class DecouvrirScreen extends StatefulWidget {
  const DecouvrirScreen({super.key});

  @override
  State<DecouvrirScreen> createState() => _DecouvrirScreenState();
}

class _DecouvrirScreenState extends State<DecouvrirScreen> {
  final _controleRecherche = TextEditingController();
  FiltresCatalogue _filtres = const FiltresCatalogue();
  bool _afficherCarte = false;

  @override
  void initState() {
    super.initState();
    CatalogueRepository.instance.charger();
  }

  @override
  void dispose() {
    _controleRecherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;

    return AnimatedBuilder(
      animation: depot,
      builder: (context, _) {
        if (!depot.charge) {
          return const Center(child: CircularProgressIndicator());
        }
        if (depot.erreur != null) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(depot.erreur!)));
        }

        final resultats = depot.rechercher(_filtres);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'DEKK FOOD - Sénégal',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: couleurPrincipale,
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: _afficherCarte ? 'Afficher la liste' : 'Afficher la carte',
                icon: Icon(_afficherCarte ? Icons.view_list : Icons.map_outlined, color: Colors.white),
                onPressed: () => setState(() => _afficherCarte = !_afficherCarte),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _controleRecherche,
                  onChanged: (valeur) => setState(() => _filtres = _filtres.copierAvec(recherche: valeur)),
                  decoration: InputDecoration(
                    hintText: 'Nom, plat, spécialité, quartier, ville…',
                    prefixIcon: const Icon(Icons.search, color: couleurPrincipale),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              _BandeauFiltres(
                filtres: _filtres,
                depot: depot,
                onChangement: (filtres) => setState(() => _filtres = filtres),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${resultats.length} établissement${resultats.length > 1 ? 's' : ''}'
                        ' · ${depot.regions.length} région${depot.regions.length > 1 ? 's' : ''} couverte${depot.regions.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    if (_filtres.estActif)
                      TextButton.icon(
                        onPressed: () {
                          _controleRecherche.clear();
                          setState(() => _filtres = const FiltresCatalogue());
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Effacer les filtres'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _afficherCarte
                    ? CarteScreen(etablissements: resultats)
                    : resultats.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Aucun établissement ne correspond à cette recherche.\n'
                                'Le recensement est progressif : utilisez « Proposer un établissement » '
                                'depuis les Paramètres pour en signaler un.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: resultats.length,
                            itemBuilder: (context, index) => CarteEtablissement(
                              etablissement: resultats[index],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Filtres : région, type, catégorie, budget, services, disponibilité des données.
class _BandeauFiltres extends StatelessWidget {
  final FiltresCatalogue filtres;
  final CatalogueRepository depot;
  final ValueChanged<FiltresCatalogue> onChangement;

  const _BandeauFiltres({
    required this.filtres,
    required this.depot,
    required this.onChangement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _puceRegion(context),
              _puceType(context),
              _puceCategorie(context),
              _puceBudget(context),
              _puceService(context),
              FilterChip(
                label: const Text('Avec GPS vérifié'),
                selected: filtres.seulementGps,
                onSelected: (valeur) => onChangement(filtres.copierAvec(seulementGps: valeur)),
              ),
              const SizedBox(width: 4),
              FilterChip(
                label: const Text('Avec menu'),
                selected: filtres.seulementMenus,
                onSelected: (valeur) => onChangement(filtres.copierAvec(seulementMenus: valeur)),
              ),
              const SizedBox(width: 4),
              FilterChip(
                label: const Text('Fiches vérifiées'),
                selected: filtres.seulementVerifies,
                onSelected: (valeur) => onChangement(filtres.copierAvec(seulementVerifies: valeur)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _puceRegion(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<String?>(
          onSelected: (valeur) => onChangement(valeur == null
              ? filtres.copierAvec(reinitialiserRegion: true)
              : filtres.copierAvec(region: valeur)),
          itemBuilder: (context) => [
            const PopupMenuItem<String?>(value: null, child: Text('Toutes les régions')),
            ...depot.regions.map((region) => PopupMenuItem<String?>(value: region, child: Text(region))),
          ],
          child: Chip(
            avatar: const Icon(Icons.place_outlined, size: 16),
            label: Text(filtres.region ?? 'Région'),
            backgroundColor: filtres.region == null ? null : couleurPrincipale.withAlpha(30),
          ),
        ),
      );

  Widget _puceType(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<String?>(
          onSelected: (valeur) => onChangement(valeur == null
              ? filtres.copierAvec(reinitialiserType: true)
              : filtres.copierAvec(typeEtablissement: valeur)),
          itemBuilder: (context) => [
            const PopupMenuItem<String?>(value: null, child: Text('Tous les types')),
            ...depot.typesEtablissement
                .map((code) => PopupMenuItem<String?>(value: code, child: Text(depot.libelleType(code)))),
          ],
          child: Chip(
            avatar: const Icon(Icons.storefront_outlined, size: 16),
            label: Text(filtres.typeEtablissement == null
                ? 'Type'
                : depot.libelleType(filtres.typeEtablissement!)),
            backgroundColor: filtres.typeEtablissement == null ? null : couleurPrincipale.withAlpha(30),
          ),
        ),
      );

  Widget _puceCategorie(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<String?>(
          onSelected: (valeur) => onChangement(valeur == null
              ? filtres.copierAvec(reinitialiserCategorie: true)
              : filtres.copierAvec(categorie: valeur)),
          itemBuilder: (context) => [
            const PopupMenuItem<String?>(value: null, child: Text('Toutes les cuisines')),
            ...depot.categories
                .map((code) => PopupMenuItem<String?>(value: code, child: Text(depot.libelleCategorie(code)))),
          ],
          child: Chip(
            avatar: const Icon(Icons.restaurant_outlined, size: 16),
            label: Text(filtres.categorie == null ? 'Cuisine' : depot.libelleCategorie(filtres.categorie!)),
            backgroundColor: filtres.categorie == null ? null : couleurPrincipale.withAlpha(30),
          ),
        ),
      );

  Widget _puceBudget(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<double?>(
          onSelected: (valeur) => onChangement(valeur == null
              ? filtres.copierAvec(reinitialiserPrix: true)
              : filtres.copierAvec(prixMax: valeur)),
          itemBuilder: (context) => const [
            PopupMenuItem<double?>(value: null, child: Text('Tous les budgets')),
            PopupMenuItem<double?>(value: 3000, child: Text('Jusqu\u2019à 3 000 FCFA')),
            PopupMenuItem<double?>(value: 7000, child: Text('Jusqu\u2019à 7 000 FCFA')),
            PopupMenuItem<double?>(value: 15000, child: Text('Jusqu\u2019à 15 000 FCFA')),
          ],
          child: Chip(
            avatar: const Icon(Icons.payments_outlined, size: 16),
            label: Text(filtres.prixMax == null ? 'Budget' : '≤ ${filtres.prixMax!.round()} FCFA'),
            backgroundColor: filtres.prixMax == null ? null : couleurPrincipale.withAlpha(30),
          ),
        ),
      );

  Widget _puceService(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<String?>(
          onSelected: (valeur) => onChangement(valeur == null
              ? filtres.copierAvec(reinitialiserService: true)
              : filtres.copierAvec(service: valeur)),
          itemBuilder: (context) => const [
            PopupMenuItem<String?>(value: null, child: Text('Tous les modes de contact')),
            PopupMenuItem<String?>(value: 'telephone', child: Text('Téléphone renseigné')),
            PopupMenuItem<String?>(value: 'whatsapp', child: Text('WhatsApp renseigné')),
            PopupMenuItem<String?>(value: 'site_web', child: Text('Site web renseigné')),
            PopupMenuItem<String?>(value: 'commande_en_ligne', child: Text('Commande en ligne')),
            PopupMenuItem<String?>(value: 'reservation', child: Text('Réservation')),
          ],
          child: Chip(
            avatar: const Icon(Icons.local_dining_outlined, size: 16),
            label: const Text('Service'),
            backgroundColor: filtres.service == null ? null : couleurPrincipale.withAlpha(30),
          ),
        ),
      );
}

/// Carte de résultat dans la liste.
class CarteEtablissement extends StatelessWidget {
  final Etablissement etablissement;

  const CarteEtablissement({super.key, required this.etablissement});

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;
    final image = etablissement.images.isEmpty ? null : etablissement.images.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FicheScreen(etablissement: etablissement),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: ImageFiche(image: image, hauteur: 84, largeur: 84, rayon: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            etablissement.nom,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            depot.estFavori(etablissement.id) ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: couleurPrincipale,
                          ),
                          onPressed: () => depot.basculerFavori(etablissement.id),
                        ),
                      ],
                    ),
                    Text(
                      '${etablissement.typeLibelle} · ${etablissement.localisation}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etablissement.categoriesLibelles.isEmpty
                          ? (etablissement.cuisineType ?? 'Cuisine non renseignée')
                          : etablissement.categoriesLibelles.join(' · '),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        BadgeVerification(niveau: etablissement.niveauVerification, compact: true),
                        if (etablissement.fourchettePrixAffichee != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            label: Text(
                              etablissement.fourchettePrixAffichee!,
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
