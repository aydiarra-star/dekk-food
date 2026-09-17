# DEKK FOOD — Sénégal

Guide culinaire et parcours de commande pour les restaurants du corridor Dakar → Rufisque → Diamniadio / AIBD → Petite Côte.

## Ce qui a été amélioré

- **Recherche instantanée et tolérante aux accents** : ville, zone, quartier, restaurant, type de cuisine **et plats du menu** sont indexés localement au démarrage. Par exemple, `ceebu jen`, `thiéb`, `gambas` ou `ngor` trouvent les bonnes adresses sans attendre le réseau.
- **Données métier structurées** : `RestaurantAddress`, `RestaurantRating`, `RestaurantContact`, `MenuItem` et `FoodOrder` remplacent les accès `Map<String, dynamic>` dans l'interface. Les prix sont désormais des entiers FCFA, ce qui fiabilise les totaux.
- **Commande plus sûre** : un panier ne mélange jamais deux restaurants ; le remplacement du panier est confirmé, les quantités et le sous-total sont calculés de manière typée, et le formulaire valide le nom, le téléphone sénégalais et l'adresse de livraison.
- **Confirmation WhatsApp fiable** : la commande est conservée tant que WhatsApp ne s'ouvre pas. Une fois l'ouverture confirmée, elle est enregistrée dans l'historique local avec son détail et son statut.
- **Favoris et paramètres utiles** : les favoris, l'historique et les préférences sont persistés sur l'appareil. Les paramètres influencent réellement le mode de réception prérempli, la langue indiquée au restaurant et l'affichage des garanties d'hygiène.
- **UX préservée et renforcée** : thème orange, cartes de restaurants, filtres de zone et navigation basse sont conservés. Les images réseau disposent maintenant d'états de chargement/erreur et les actions longues s'adaptent aux petits écrans.

## Lancer le projet

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Pour un build web de production :

```bash
flutter build web --release --base-href=/dekk-food/
```

## Architecture

```text
lib/
├── data/restaurant_catalog.dart       # catalogue local de démarrage
├── models/                            # Restaurant, MenuItem, panier et commande typés
├── screens/                           # découverte, restaurant, panier, compte
├── services/                          # stockage local + adaptateur Supabase
├── state/app_state.dart               # panier, favoris, commandes, préférences
├── utils/                             # format FCFA, liens externes, garde-fou panier
└── widgets/dekk_ui.dart               # cartes, images résilientes, contrôles réutilisables
```

Le catalogue local permet une découverte immédiate hors connexion. `SupabaseService` utilise les mêmes modèles et peut devenir la source de données distante dès que l'initialisation Supabase et les variables d'environnement de production sont ajoutées.

## Données et Supabase

Le fichier [`supabase/schema.sql`](supabase/schema.sql) est une migration idempotente qui :

1. enrichit les restaurants avec zone, ville, adresse, notes, avis, types de cuisine, fourchette de prix et contact ;
2. enrichit les menus avec image, note d'hygiène, disponibilité et ordre d'affichage ;
3. prépare `orders`, `order_items` et `favorites` ;
4. active la RLS : le guide public est lisible, mais les données client de commande restent réservées à un backend/une Edge Function sécurisée.

> Avant de brancher des commandes distantes, créez une Edge Function qui valide le panier, calcule de nouveau les prix côté serveur et insère `orders` / `order_items` avec le rôle service. Ne donnez pas au rôle `anon` un accès direct aux coordonnées clients.

## Qualité et suite recommandée

Le diagnostic et les prochaines étapes de production sont détaillés dans [`docs/technical-audit.md`](docs/technical-audit.md). Les tests de logique couvrent la recherche normalisée, les prix et l'isolement du panier.
