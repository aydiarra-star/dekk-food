# Audit technique — DEKK FOOD Sénégal

## Diagnostic initial

| Sujet | Constat initial | Risque produit | Correction livrée |
| --- | --- | --- | --- |
| Recherche | La recherche reconstruisait une liste de `Map` à chaque rendu et ne cherchait pas les plats. | Résultats incomplets pour une intention comme « yassa » ; coût inutile en grandissant. | Index de recherche normalisé et pré-calculé par restaurant, avec recherche instantanée sur zone, quartier, cuisine et menu. |
| Données | Les écrans lisaient des chaînes et des `Map<String, dynamic>` (`r['rating']`, `dish['price']`). | Erreurs de clé, prix mal parsés, évolution difficile du schéma. | Modèles immuables `Restaurant`, `RestaurantAddress`, `RestaurantRating`, `RestaurantContact`, `MenuItem`, `CartLine`, `FoodOrder`. |
| Panier | Le panier mélangeait logique UI et données ; un restaurant différent pouvait être refusé silencieusement. | Client bloqué sans explication ; risque d'envoyer au mauvais restaurant. | Garde-fou métier typé + dialogue explicite avant de remplacer un panier. |
| Validation | Les contrôleurs n'étaient pas libérés ; la validation était minimale ; la commande était effacée avant de savoir si WhatsApp s'ouvrait. | Fuite de ressources, commandes perdues, faux succès. | `dispose`, validation nom/téléphone/adresse, note facultative, conservation du panier si l'action externe échoue. |
| Favoris / commandes | Écrans vides ou historiques en mémoire seulement. | Les fonctions annoncées n'étaient pas utilisables après un redémarrage. | Favoris, préférences et historique persistant localement ; détail de commande et reprise de contact WhatsApp. |
| Images / petits écrans | Images réseau sans état d'erreur et trois boutons dans une `Row` fixe. | Écrans cassés hors réseau ou sur téléphone étroit. | Composant image avec placeholder/erreur et actions dans un `Wrap`. |
| Base de données | Schéma minimal, pas d'index de recherche, pas de tables de commande, pas de RLS. | Données clients exposables et recherche serveur lente. | Migration idempotente structurée, index, `orders` / `order_items` / `favorites` et politiques RLS. |

## Choix d'architecture

### Recherche locale d'abord

Le catalogue est chargé en objets immuables une seule fois. Chaque `Restaurant` fabrique un index sans accents contenant :

- nom de l'enseigne ;
- ville, zone, quartier, rue ;
- tous les types de cuisine ;
- nom, description et catégorie de chaque plat.

Le filtrage ne déclenche aucun appel réseau et vérifie tous les mots saisis. Cette approche est instantanée pour le catalogue actuel et reste appropriée pour quelques centaines d'adresses. Lorsque le volume augmentera, conserver cette recherche locale pour les données déjà chargées et ajouter une recherche Supabase paginée (trigram / FTS) pour les résultats lointains.

### Source de données interchangeable

L'interface ne lit plus le format du catalogue brut. Le catalogue local et `SupabaseService` produisent les mêmes modèles de domaine. La migration vers Supabase peut ainsi être réalisée derrière un repository sans réécrire les cartes, le détail ni le panier.

### Commande : responsabilité claire

1. Le menu fournit un `MenuItem` avec un prix entier FCFA.
2. `CartModel` crée des `CartLine` figées et interdit le mélange de restaurants.
3. Le checkout valide les coordonnées et crée un `FoodOrder` immuable.
4. WhatsApp est ouvert avec un message construit à partir de cet instantané.
5. L'historique local est enregistré seulement si l'ouverture réussit.

Le sous-total présenté est un montant de plats : les frais de livraison doivent être confirmés par le restaurant tant qu'une règle tarifaire par zone n'est pas gérée côté serveur.

## Priorités de production recommandées

### P0 — avant encaissement ou mise en production commerciale

- Déployer une **Edge Function** `create-order` authentifiée ou protégée contre l'abus. Elle doit vérifier disponibilité, prix, restaurant et total côté serveur ; ne jamais faire confiance au prix envoyé par l'appareil.
- Ajouter un mécanisme d'identité (OTP téléphone ou compte) avant de synchroniser commandes et favoris entre appareils.
- Prévoir consentement, durée de conservation et procédure d'effacement pour les noms, numéros et adresses des clients.
- Faire confirmer par chaque restaurant son numéro WhatsApp, ses horaires, ses zones et la fraîcheur des informations de menu.

### P1 — amélioration de l'exploitation

- Ajouter horaires, statut ouvert/fermé, délai estimé, frais de livraison et minimum de commande au modèle restaurant.
- Paginer les réponses Supabase et utiliser une recherche serveur indexée à partir d'un catalogue conséquent.
- Mettre en place le suivi de statut (`confirmed`, `preparing`, `on_the_way`, `completed`) via webhook/outil restaurant plutôt que de déduire l'état de WhatsApp.
- Instrumenter les événements anonymisés : recherche, ouverture de fiche, ajout panier, abandon checkout, ouverture WhatsApp.

### P2 — qualité continue

- Ajouter des tests widget pour le parcours : recherche d'un plat → ajout → changement de restaurant → checkout.
- Tester sur réseau lent / hors ligne, écran 320 px, Chrome Android et Safari iOS.
- Remplacer progressivement les URLs d'images tierces par un stockage optimisé (Supabase Storage/CDN) avec tailles adaptées et droits d'utilisation validés.

## Indicateurs à suivre

- délai entre frappe et affichage de résultat (objectif ressenti : immédiat) ;
- taux de recherche sans résultat, par zone et par requête ;
- taux fiche → ajout panier ;
- taux panier → ouverture WhatsApp ;
- taux de confirmation restaurant et délai de confirmation ;
- taux d'échec d'ouverture de liens externes.
