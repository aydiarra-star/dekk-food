/// Contributions des visiteurs : avis, signalement d'erreur, demande de mise à
/// jour, revendication de fiche, proposition d'établissement absent.
///
/// IMPORTANT : aucune contribution n'est publiée automatiquement. Les avis sont
/// enregistrés « en attente de modération », et une revendication ne rend JAMAIS
/// une fiche « vérifiée » (la procédure de contrôle est décrite dans
/// docs/SOURCES.md).
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../models/catalogue.dart';
import '../widgets/communs.dart';

enum ModeContribution { deposerAvis, signalerErreur, demanderMiseAJour, revendiquer, proposerEtablissement }

class ContributionsScreen extends StatefulWidget {
  final Etablissement? etablissement;
  final ModeContribution mode;

  const ContributionsScreen({super.key, this.etablissement, required this.mode});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _contact = TextEditingController();
  final _nom = TextEditingController();
  final _note = ValueNotifier<int>(5);
  bool _envoye = false;

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    _nom.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _titre => switch (widget.mode) {
        ModeContribution.deposerAvis => 'Donner mon avis',
        ModeContribution.signalerErreur => 'Signaler une erreur',
        ModeContribution.demanderMiseAJour => 'Demander une mise à jour',
        ModeContribution.revendiquer => 'Revendiquer cette fiche',
        ModeContribution.proposerEtablissement => 'Proposer un établissement',
      };

  String get _aide => switch (widget.mode) {
        ModeContribution.deposerAvis =>
          'Votre avis sera examiné par l\u2019équipe avant publication. Les avis haineux, '
              'publicitaires ou sans rapport avec une expérience réelle sont refusés.',
        ModeContribution.signalerErreur =>
          'Décrivez précisément l\u2019information erronée (horaires, adresse, téléphone, fermeture…). '
              'Une correction n\u2019est appliquée qu\u2019après vérification.',
        ModeContribution.demanderMiseAJour =>
          'Indiquez les informations à actualiser. Elles seront vérifiées avant publication.',
        ModeContribution.revendiquer =>
          'Vous êtes responsable de cet établissement ? Décrivez votre lien avec lui. '
              'La revendication est contrôlée avant activation : elle ne rend pas la fiche « vérifiée » '
              'automatiquement, et un historique des modifications est conservé.',
        ModeContribution.proposerEtablissement =>
          'Indiquez le nom, la ville/quartier et, si possible, un contact officiel. '
              'L\u2019équipe vérifiera l\u2019existence de l\u2019établissement avant toute publication.',
      };

  Future<void> _envoyer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;

    final depot = CatalogueRepository.instance;
    final maintenant = DateTime.now();

    if (widget.mode == ModeContribution.deposerAvis) {
      await depot.deposerAvis(Avis(
        etablissementId: widget.etablissement?.id ?? '',
        auteur: _nom.text.trim().isEmpty ? null : _nom.text.trim(),
        note: _note.value,
        commentaire: _message.text.trim(),
        deposeLe: maintenant,
      ));
    } else {
      await depot.enregistrerDemande(Demande(
        type: switch (widget.mode) {
          ModeContribution.signalerErreur => 'signalement',
          ModeContribution.demanderMiseAJour => 'demande_correction',
          ModeContribution.revendiquer => 'revendication',
          ModeContribution.proposerEtablissement => 'suggestion_etablissement',
          ModeContribution.deposerAvis => 'signalement',
        },
        etablissementId: widget.etablissement?.id,
        message: _message.text.trim(),
        contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        creeLe: maintenant,
      ));
    }

    setState(() => _envoye = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titre, style: const TextStyle(color: Colors.white)),
        backgroundColor: couleurPrincipale,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _envoye
          ? _ecranConfirmation()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formulaire,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.etablissement != null)
                      Text(
                        widget.etablissement!.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    BandeauInformation(
                      couleur: Colors.blueGrey,
                      message: _aide,
                    ),
                    const SizedBox(height: 16),
                    if (widget.mode == ModeContribution.deposerAvis) ...[
                      const Text('Votre note', style: TextStyle(fontWeight: FontWeight.w600)),
                      ValueListenableBuilder<int>(
                        valueListenable: _note,
                        builder: (context, note, _) => Row(
                          children: [
                            for (var index = 1; index <= 5; index++)
                              IconButton(
                                onPressed: () => _note.value = index,
                                icon: Icon(
                                  index <= note ? Icons.star : Icons.star_border,
                                  color: couleurPrincipale,
                                ),
                              ),
                            Text('$note / 5'),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: _nom,
                        decoration: const InputDecoration(
                          labelText: 'Votre nom ou pseudonyme (facultatif)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.mode == ModeContribution.proposerEtablissement)
                      TextFormField(
                        controller: _nom,
                        decoration: const InputDecoration(
                          labelText: 'Nom de l\u2019établissement et ville/quartier',
                          border: OutlineInputBorder(),
                        ),
                        validator: (valeur) =>
                            (valeur == null || valeur.trim().length < 3) ? 'Précisez le nom et la localité' : null,
                      ),
                    if (widget.mode == ModeContribution.proposerEtablissement) const SizedBox(height: 12),
                    TextFormField(
                      controller: _message,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Votre message',
                        border: OutlineInputBorder(),
                      ),
                      validator: (valeur) =>
                          (valeur == null || valeur.trim().length < 10) ? 'Message trop court (10 caractères minimum)' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contact,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Contact (e-mail ou téléphone, facultatif)',
                        helperText: 'Utilisé uniquement pour vous répondre. Aucune donnée privée n\u2019est publiée.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: couleurPrincipale,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: _envoyer,
                        child: Text(_titre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _ecranConfirmation() {
    final depot = CatalogueRepository.instance;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Contribution enregistrée',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              depot.baseConnectee
                  ? 'Votre contribution a été transmise pour modération. Elle n\u2019apparaît pas '
                      'publiquement avant validation par l\u2019équipe.'
                  : 'Votre contribution est conservée sur cet appareil en attente de synchronisation. '
                      'La base communautaire n\u2019est pas encore connectée à cette version de l\u2019application : '
                      'elle ne sera donc pas publiée automatiquement.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: couleurPrincipale, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}
