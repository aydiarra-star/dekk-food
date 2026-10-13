"""Génération des livrables à partir des données de collecte (source unique) :

1. `assets/data/catalogue.json` — catalogue embarqué dans l'application Flutter ;
2. `supabase/seed/10_etablissements.sql` — jeu de données idempotent pour Supabase.

Le même fichier de collecte alimente donc l'application web et la base, ce qui
garantit qu'ils ne divergent pas.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any, Iterable

from .modele import Etablissement, Plat

TYPES_LIBELLES = {
    "restaurant": "Restaurant",
    "fast_food": "Fast-food",
    "gargote": "Gargote",
    "dibiterie": "Dibiterie",
    "pizzeria": "Pizzeria",
    "cafe_restaurant": "Café-restaurant",
    "salon_de_the": "Salon de thé",
    "patisserie": "Pâtisserie",
    "boulangerie": "Boulangerie",
    "glacier": "Glacier",
    "grillades": "Grillades",
    "restaurant_hotel": "Restaurant d'hôtel",
    "restaurant_plage": "Restaurant de plage",
    "restaurant_rooftop": "Restaurant / rooftop",
    "bar_lounge_restaurant": "Bar-lounge",
    "traiteur": "Traiteur",
    "service_livraison": "Service de livraison",
    "snack": "Snack",
    "maquis": "Maquis",
    "cantine": "Cantine",
    "complexe_restauration": "Complexe de restauration",
}

CATEGORIES_LIBELLES = {
    "senegalaise": "Cuisine sénégalaise",
    "africaine": "Cuisine africaine",
    "creole": "Cuisine créole",
    "congolaise": "Cuisine congolaise",
    "libanaise": "Libanaise",
    "francaise": "Française",
    "italienne": "Italienne",
    "internationale": "Internationale",
    "asiatique": "Asiatique",
    "chinoise": "Chinoise",
    "fruits_de_mer": "Poissons & fruits de mer",
    "grillades": "Grillades",
    "street_food": "Street food",
    "pizza": "Pizza",
    "burgers": "Burgers",
    "patisserie_dessert": "Pâtisserie & desserts",
    "petit_dejeuner": "Petit-déjeuner",
    "brunch": "Brunch",
    "buffet": "Buffet",
    "healthy": "Healthy",
}

SERVICES_LIBELLES = {
    "sur_place": "Sur place",
    "a_emporter": "À emporter",
    "retrait_sur_place": "Retrait sur place",
    "livraison_restaurant": "Livraison par le restaurant",
    "livraison_partenaire": "Livraison par un partenaire",
    "commande_telephone": "Commande par téléphone",
    "commande_whatsapp": "Commande par WhatsApp",
    "commande_site_web": "Commande sur le site du restaurant",
    "commande_dekk_food": "Commande DEKK FOOD",
    "reservation": "Réservation",
    "traiteur": "Traiteur",
    "buffet": "Buffet",
    "terrasse": "Terrasse",
    "climatisation": "Salle climatisée",
    "wifi": "Wi-Fi",
    "parking": "Parking",
    "acces_pmr": "Accès PMR",
    "vue_mer": "Vue mer",
    "piscine": "Piscine",
    "salle_privee": "Salle privée",
    "paiement_especes": "Espèces",
    "paiement_carte": "Carte bancaire",
    "paiement_mobile_money": "Mobile money",
}


def _libelle_categories(etablissement: Etablissement) -> str | None:
    """Libellé de repli pour `cuisine_type`, dérivé des catégories sourcées.

    On ne devine aucune cuisine : on se contente de reprendre les catégories
    réellement collectées (ou None si aucune ne l'a été).
    """
    libelles = [CATEGORIES_LIBELLES.get(code, code) for code in etablissement.categories]
    return " & ".join(libelles[:2]) if libelles else None


def _prix_libelle(etablissement: Etablissement) -> str | None:
    mini, maxi = etablissement.fourchette_prix_min, etablissement.fourchette_prix_max
    if mini is None and maxi is None:
        return None

    def formater(valeur: float) -> str:
        return f"{int(valeur):,}".replace(",", " ")

    if mini is not None and maxi is not None:
        return f"{formater(mini)} – {formater(maxi)} {etablissement.devise}"
    return f"{formater(mini if mini is not None else maxi)} {etablissement.devise}"


def construire_fiche_application(etablissement: Etablissement) -> dict[str, Any]:
    """Construit la fiche telle que consommée par l'application Flutter."""
    image_principale = etablissement.image_principale
    telephone = etablissement.contact("telephone")
    whatsapp = etablissement.contact("whatsapp")

    fiche: dict[str, Any] = {
        "id": etablissement.numero_fiche or etablissement.cle,
        "cle": etablissement.cle,
        "slug": etablissement.slug,
        "nom": etablissement.nom_commercial or etablissement.nom,
        "nom_officiel": etablissement.nom_officiel or etablissement.nom,
        "nom_commercial": etablissement.nom_commercial,
        "type_etablissement": etablissement.type_etablissement,
        "type_libelle": TYPES_LIBELLES.get(etablissement.type_etablissement or "", "Établissement"),
        "categories": etablissement.categories,
        "categories_libelles": [CATEGORIES_LIBELLES.get(c, c) for c in etablissement.categories],
        "cuisine_type": etablissement.cuisine_type,
        "description_courte": etablissement.description_courte,
        "description_longue": etablissement.description_longue,
        "statut": etablissement.statut,
        "niveau_verification": etablissement.niveau_verification,
        "region": etablissement.region,
        "departement": etablissement.departement,
        "commune": etablissement.commune,
        "quartier": etablissement.quartier or etablissement.quartier_libre,
        "quartier_libre": etablissement.quartier_libre,
        "ville_libre": etablissement.ville_libre,
        "adresse": etablissement.adresse_complete,
        "points_de_repere": etablissement.points_de_repere,
        "latitude": etablissement.latitude,
        "longitude": etablissement.longitude,
        "gps_verifie": etablissement.gps_verifie,
        "telephone": telephone.valeur if telephone else None,
        "telephone_confirme": telephone.confirme if telephone else False,
        "whatsapp": whatsapp.valeur if whatsapp else None,
        "whatsapp_confirme": whatsapp.confirme if whatsapp else False,
        "email": (etablissement.contact("email").valeur if etablissement.contact("email") else None),
        "site_web": etablissement.site_web,
        "facebook": etablissement.facebook,
        "instagram": etablissement.instagram,
        "commande_en_ligne_url": etablissement.commande_en_ligne_url,
        "reservation_url": etablissement.reservation_url,
        "fourchette_prix": {
            "min": etablissement.fourchette_prix_min,
            "max": etablissement.fourchette_prix_max,
            "devise": etablissement.devise,
            "libelle": _prix_libelle(etablissement),
            "confirmee": False,
        },
        "ambiance": etablissement.ambiance,
        "clientele": etablissement.clientele,
        "modes_paiement": etablissement.modes_paiement,
        "accessibilite": etablissement.accessibilite,
        "equipements": etablissement.equipements,
        "services": [
            {
                "code": code,
                "libelle": SERVICES_LIBELLES.get(code, code),
                # Un service n'est affiché comme confirmé qu'après vérification documentée.
                "confirme": False,
            }
            for code in etablissement.services
        ],
        "horaires": [h.as_dict() for h in etablissement.horaires],
        "zones_livraison": etablissement.zones_livraison,
        "images": [i.as_dict() for i in etablissement.images],
        "image_principale_url": image_principale.url if image_principale else None,
        "image_principale_est_generique": image_principale.est_illustration_generique if image_principale else None,
        "image_principale_legende": image_principale.legende if image_principale else None,
        "menus": [m.as_dict() for m in etablissement.menus],
        "menu_disponible": any(
            p.prix is not None for m in etablissement.menus for p in m.plats
        ),
        "exploitation": [
            {
                "role": e.role,
                "nom_public": e.nom_public,
                "entreprise": e.entreprise,
                "fonction": e.fonction,
                "statut_confirmation": e.statut_confirmation,
                "source": e.source,
                "source_url": e.source_url,
                "date_verification": e.date_verification,
                "libelle": (
                    (e.nom_public or e.entreprise)
                    if e.statut_confirmation != "inconnu" and (e.nom_public or e.entreprise)
                    else "Propriétaire non renseigné"
                ),
            }
            for e in etablissement.exploitation
        ]
        or [
            {
                "role": "exploitant",
                "libelle": "Propriétaire non renseigné",
                "statut_confirmation": "inconnu",
            }
        ],
        "sources": [s.as_dict() for s in etablissement.sources],
        "origine_donnee": etablissement.origine_donnee,
        "date_collecte": etablissement.date_collecte,
        "derniere_verification_le": etablissement.derniere_verification_le,
        "commentaire_verification": etablissement.commentaire_verification,
        "note_moyenne": None,       # aucune note inventée : alimenté par les avis modérés uniquement
        "nombre_avis": 0,
        "commande_integree_disponible": False,  # activée uniquement fiche par fiche, après accord du restaurant
    }
    return fiche


def construire_catalogue(
    etablissements: Iterable[Etablissement],
    date_generation: str | None = None,
) -> dict[str, Any]:
    """Document complet embarqué par l'application."""
    fiches = [construire_fiche_application(e) for e in etablissements]
    fiches.sort(key=lambda f: (f["region"] or "zz", f["nom"]))

    regions = sorted({f["region"] for f in fiches if f["region"]})
    departements = sorted({f["departement"] for f in fiches if f["departement"]})
    communes = sorted({f["commune"] for f in fiches if f["commune"]})
    categories = sorted({c for f in fiches for c in f["categories_libelles"]})
    types = sorted({f["type_libelle"] for f in fiches})

    return {
        "version": 1,
        "genere_le": date_generation or date.today().isoformat(),
        "avertissement": (
            "Catalogue DEKK FOOD. Toutes les fiches ne sont pas vérifiées : "
            "le champ « niveau_verification » et la date de collecte accompagnent chaque information. "
            "Aucun prix, horaire, avis ni photo n'est inventé ; les images non authentiques sont "
            "signalées par « est_illustration_generique »."
        ),
        "couverture": {
            "etablissements": len(fiches),
            "regions_couvertes": regions,
            "departements": departements,
            "communes": communes,
            "categories": categories,
            "types": types,
            "avertissement": (
                "Le recensement national est incomplet par nature : aucune source publique ne "
                "permet de garantir l'exhaustivité des restaurants du Sénégal."
            ),
        },
        "etablissements": fiches,
    }


# --------------------------------------------------------------------------- #
# Génération SQL
# --------------------------------------------------------------------------- #
def _sql(valeur: Any) -> str:
    """Convertit une valeur Python en littéral SQL sûr."""
    if valeur is None or valeur == "":
        return "null"
    if isinstance(valeur, bool):
        return "true" if valeur else "false"
    if isinstance(valeur, (int, float)):
        return str(valeur)
    if isinstance(valeur, (list, tuple)):
        if not valeur:
            return "null"
        return "array[" + ", ".join(_sql(v) for v in valeur) + "]::text[]"
    texte = str(valeur).replace("'", "''")
    return f"'{texte}'"


def _lien_source(code: str | None, url: str | None) -> tuple[str, str]:
    """Renvoie (expression source_id, expression source_url)."""
    source_id = f"(select id from public.sources where code = {_sql(code)})" if code else "null"
    return source_id, _sql(url)


def generer_sql(etablissements: Iterable[Etablissement]) -> str:
    """Génère le script SQL idempotent d'amorçage du catalogue."""
    lignes: list[str] = [
        "-- =============================================================================",
        "-- DEKK FOOD / DAKA FOOD — Amorçage du catalogue (fichier GÉNÉRÉ)",
        "-- Source : data/seed/*.json via tools/catalogue (ne pas modifier à la main).",
        f"-- Généré le {date.today().isoformat()}",
        "-- Le script est idempotent : il met à jour les fiches existantes (clé : slug).",
        "-- =============================================================================",
        "",
        "begin;",
        "",
    ]

    for etablissement in etablissements:
        slug = etablissement.slug
        source_code = etablissement.sources[0].code if etablissement.sources else None
        source_url = next((s.url for s in etablissement.sources if s.url), None)
        source_id_expr, source_url_expr = _lien_source(source_code, source_url)

        lignes.append(f"-- ── {etablissement.nom} ({etablissement.region or 'région inconnue'}) ──")
        lignes.append(
            "insert into public.restaurants ("
            "numero_fiche, slug, name, nom_officiel, nom_commercial, cuisine_type, neighborhood, address, "
            "adresse_complete, phone, whatsapp, latitude, longitude, is_active, region_id, departement_id, "
            "commune_id, quartier_id, ville_libre, type_etablissement_id, description_courte, description_longue, "
            "statut, niveau_verification, gps_verifie, fourchette_prix_min, fourchette_prix_max, devise, ambiance, "
            "clientele, modes_paiement, accessibilite, equipements, site_web, facebook, instagram, "
            "commande_en_ligne_url, reservation_url, points_de_repere, source_principale_id, source_principale_url, "
            "date_collecte, derniere_verification_le, commentaire_verification, origine_donnee, "
            "est_publication_visible, image_principale_url"
            ") select "
            f"{_sql(etablissement.numero_fiche)}, {_sql(slug)}, {_sql(etablissement.nom)}, "
            f"{_sql(etablissement.nom_officiel)}, {_sql(etablissement.nom_commercial)}, "
            f"{_sql(etablissement.cuisine_type or _libelle_categories(etablissement))}, "
            f"{_sql(etablissement.quartier_libre or etablissement.quartier or etablissement.commune or etablissement.ville_libre)}, "
            f"{_sql(etablissement.adresse_complete)}, {_sql(etablissement.adresse_complete)}, "
            f"{_sql(etablissement.telephone)}, {_sql(etablissement.whatsapp)}, "
            f"{_sql(etablissement.latitude)}, {_sql(etablissement.longitude)}, true, "
            f"(select id from public.regions where nom = {_sql(etablissement.region)}), "
            f"(select id from public.departements where nom = {_sql(etablissement.departement)}), "
            f"(select c.id from public.communes c join public.departements d on d.id = c.departement_id "
            f"where c.nom = {_sql(etablissement.commune)} and d.nom = {_sql(etablissement.departement)} limit 1), "
            f"(select q.id from public.quartiers q join public.communes c on c.id = q.commune_id "
            f"join public.departements d on d.id = c.departement_id "
            f"where q.nom = {_sql(etablissement.quartier)} and c.nom = {_sql(etablissement.commune)} limit 1), "
            f"{_sql(etablissement.ville_libre)}, "
            f"(select id from public.types_etablissement where code = {_sql(etablissement.type_etablissement)}), "
            f"{_sql(etablissement.description_courte)}, {_sql(etablissement.description_longue)}, "
            f"{_sql(etablissement.statut)}, {_sql(etablissement.niveau_verification)}, "
            f"{'true' if etablissement.gps_verifie else 'false'}, "
            f"{_sql(etablissement.fourchette_prix_min)}, {_sql(etablissement.fourchette_prix_max)}, "
            f"{_sql(etablissement.devise)}, {_sql(etablissement.ambiance)}, {_sql(etablissement.clientele)}, "
            f"{_sql(etablissement.modes_paiement)}, {_sql(etablissement.accessibilite)}, "
            f"{_sql(etablissement.equipements)}, {_sql(etablissement.site_web)}, {_sql(etablissement.facebook)}, "
            f"{_sql(etablissement.instagram)}, {_sql(etablissement.commande_en_ligne_url)}, "
            f"{_sql(etablissement.reservation_url)}, {_sql(etablissement.points_de_repere)}, "
            f"{source_id_expr}, {source_url_expr}, "
            f"{_sql(etablissement.date_collecte)}::date, {_sql(etablissement.derniere_verification_le)}::date, "
            f"{_sql(etablissement.commentaire_verification)}, {_sql(etablissement.origine_donnee)}, "
            f"{'true' if etablissement.est_publication_visible else 'false'}, "
            f"{_sql(etablissement.image_principale.url if etablissement.image_principale else None)}"
            " on conflict (slug) do update set "
            "numero_fiche = excluded.numero_fiche, name = excluded.name, nom_officiel = excluded.nom_officiel, "
            "nom_commercial = excluded.nom_commercial, cuisine_type = excluded.cuisine_type, "
            "neighborhood = excluded.neighborhood, address = excluded.address, adresse_complete = excluded.adresse_complete, "
            "phone = excluded.phone, whatsapp = excluded.whatsapp, latitude = excluded.latitude, "
            "longitude = excluded.longitude, region_id = excluded.region_id, departement_id = excluded.departement_id, "
            "commune_id = excluded.commune_id, quartier_id = excluded.quartier_id, ville_libre = excluded.ville_libre, "
            "type_etablissement_id = excluded.type_etablissement_id, description_courte = excluded.description_courte, "
            "description_longue = excluded.description_longue, statut = excluded.statut, "
            "niveau_verification = excluded.niveau_verification, gps_verifie = excluded.gps_verifie, "
            "fourchette_prix_min = excluded.fourchette_prix_min, fourchette_prix_max = excluded.fourchette_prix_max, "
            "devise = excluded.devise, ambiance = excluded.ambiance, clientele = excluded.clientele, "
            "modes_paiement = excluded.modes_paiement, accessibilite = excluded.accessibilite, "
            "equipements = excluded.equipements, site_web = excluded.site_web, facebook = excluded.facebook, "
            "instagram = excluded.instagram, commande_en_ligne_url = excluded.commande_en_ligne_url, "
            "reservation_url = excluded.reservation_url, points_de_repere = excluded.points_de_repere, "
            "source_principale_id = excluded.source_principale_id, source_principale_url = excluded.source_principale_url, "
            "date_collecte = excluded.date_collecte, derniere_verification_le = excluded.derniere_verification_le, "
            "commentaire_verification = excluded.commentaire_verification, origine_donnee = excluded.origine_donnee, "
            "est_publication_visible = excluded.est_publication_visible, image_principale_url = excluded.image_principale_url;"
        )

        # Catégories
        for categorie in etablissement.categories:
            lignes.append(
                "insert into public.etablissement_categories (restaurant_id, categorie_id, est_principale) "
                "select r.id, c.id, false from public.restaurants r, public.categories_culinaires c "
                f"where r.slug = {_sql(slug)} and c.code = {_sql(categorie)} "
                "on conflict (restaurant_id, categorie_id) do nothing;"
            )

        # Contacts
        for contact in etablissement.contacts:
            contact_source_id, _ = _lien_source(contact.source, None)
            lignes.append(
                "insert into public.contacts (restaurant_id, type, valeur, libelle, confirme, est_principal, "
                "source_id, source_url, date_collecte) "
                f"select r.id, {_sql(contact.type)}, {_sql(contact.valeur)}, {_sql(contact.libelle)}, "
                f"{'true' if contact.confirme else 'false'}, {'true' if contact.est_principal else 'false'}, "
                f"{contact_source_id}, {_sql(contact.source_url)}, {_sql(contact.date_collecte)}::date "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (restaurant_id, type, valeur) do update set confirme = excluded.confirme, "
                "source_id = excluded.source_id, date_collecte = excluded.date_collecte, "
                "source_url = coalesce(excluded.source_url, public.contacts.source_url);"
            )

        # Horaires
        for horaire in etablissement.horaires:
            horaire_source_id, _ = _lien_source(horaire.source, None)
            lignes.append(
                "insert into public.horaires (restaurant_id, jour, service, ferme, ouverture, fermeture, "
                "confirme, source_id, source_url, date_verification) "
                f"select r.id, {horaire.jour}, {_sql(horaire.service)}, "
                f"{'true' if horaire.ferme else 'false'}, {_sql(horaire.ouverture)}::time, "
                f"{_sql(horaire.fermeture)}::time, {'true' if horaire.confirme else 'false'}, "
                f"{horaire_source_id}, {_sql(horaire.source_url)}, {_sql(horaire.date_verification)}::date "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (restaurant_id, jour, service) do update set ferme = excluded.ferme, "
                "ouverture = excluded.ouverture, fermeture = excluded.fermeture, confirme = excluded.confirme, "
                "source_id = excluded.source_id;"
            )

        # Services et équipements
        for service in etablissement.services + [e for e in etablissement.equipements if e]:
            correspondance = _SERVICES_EQUIPEMENTS.get(service, service)
            lignes.append(
                "insert into public.etablissement_services (restaurant_id, service_id, confirme, source_id) "
                "select r.id, s.id, false, (select id from public.sources where code = "
                f"{_sql(source_code)}) from public.restaurants r, public.services s "
                f"where r.slug = {_sql(slug)} and s.code = {_sql(correspondance)} "
                "on conflict (restaurant_id, service_id) do nothing;"
            )

        # Zones de livraison
        for zone in etablissement.zones_livraison:
            zone_source_id, _ = _lien_source(zone.get("source"), None)
            lignes.append(
                "insert into public.zones_livraison (restaurant_id, commune_id, libelle_zone, frais_livraison, "
                "devise, delai_estime, minimum_commande, confirme, source_id, source_url) "
                f"select r.id, (select id from public.communes where nom = {_sql(zone.get('commune'))} limit 1), "
                f"{_sql(zone.get('libelle_zone'))}, {_sql(zone.get('frais_livraison'))}, "
                f"{_sql(zone.get('devise', 'XOF'))}, {_sql(zone.get('delai_estime'))}, "
                f"{_sql(zone.get('minimum_commande'))}, "
                f"{'true' if zone.get('confirme') else 'false'}, {zone_source_id}, {_sql(zone.get('source_url'))} "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (restaurant_id, coalesce(commune_id, 0), coalesce(libelle_zone, '')) do nothing;"
            )

        # Images de l'établissement
        for image in etablissement.images:
            image_source_id, _ = _lien_source(image.source, None)
            lignes.append(
                "insert into public.images (restaurant_id, url, type_media, legende, est_principale, "
                "est_illustration_generique, correspondance_verifiee, auteur, licence, autorisation_usage, "
                "source_id, source_url, date_collecte, ordre) "
                f"select r.id, {_sql(image.url)}, {_sql(image.type_media)}, {_sql(image.legende)}, "
                f"{'true' if image.est_principale else 'false'}, "
                f"{'true' if image.est_illustration_generique else 'false'}, "
                f"{'true' if image.correspondance_verifiee else 'false'}, {_sql(image.auteur)}, "
                f"{_sql(image.licence)}, {_sql(image.autorisation_usage)}, {image_source_id}, "
                f"{_sql(image.source_url)}, {_sql(image.date_collecte)}::date, {image.ordre} "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (coalesce(restaurant_id, '00000000-0000-0000-0000-000000000000'::uuid), url) do update set "
                "type_media = excluded.type_media, est_principale = excluded.est_principale, "
                "est_illustration_generique = excluded.est_illustration_generique, "
                "correspondance_verifiee = excluded.correspondance_verifiee, licence = excluded.licence;"
            )

        # Menus et plats
        menus = etablissement.menus or []
        for menu in menus:
            menu_source_id, _ = _lien_source(menu.source, None)
            lignes.append(
                "insert into public.menus (restaurant_id, nom, type, statut, devise, source_id, source_url, "
                "date_collecte, date_debut, date_fin, derniere_maj) "
                f"select r.id, {_sql(menu.nom)}, {_sql(menu.type)}, {_sql(menu.statut)}, {_sql(menu.devise)}, "
                f"{menu_source_id}, {_sql(menu.source_url)}, {_sql(menu.date_collecte)}::date, "
                f"{_sql(menu.date_debut)}::date, {_sql(menu.date_fin)}::date, current_date "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (restaurant_id, nom, type) do update set statut = excluded.statut, "
                "source_id = excluded.source_id, source_url = excluded.source_url, derniere_maj = current_date;"
            )
            for plat in menu.plats:
                plat_source_id, _ = _lien_source(plat.source, None)
                lignes.append(
                    "insert into public.plats (restaurant_id, menu_id, nom, description, categorie, prix, devise, "
                    "taille_portion, options, variantes, disponibilite, date_debut, date_fin, statut_confirmation, "
                    "source_id, source_url, derniere_maj) "
                    f"select r.id, m.id, {_sql(plat.nom)}, {_sql(plat.description)}, {_sql(plat.categorie)}, "
                    f"{_sql(plat.prix)}, {_sql(plat.devise)}, {_sql(plat.taille_portion)}, {_sql(plat.options)}, "
                    f"{_sql(plat.variantes)}, {_sql(plat.disponibilite)}, {_sql(plat.date_debut)}::date, "
                    f"{_sql(plat.date_fin)}::date, {_sql(plat.statut_confirmation)}, {plat_source_id}, "
                    f"{_sql(plat.source_url)}, current_date "
                    "from public.restaurants r join public.menus m on m.restaurant_id = r.id "
                    f"where r.slug = {_sql(slug)} and m.nom = {_sql(menu.nom)} and m.type = {_sql(menu.type)} "
                    "on conflict (menu_id, nom) do update set description = excluded.description, "
                    "categorie = excluded.categorie, prix = excluded.prix, statut_confirmation = excluded.statut_confirmation, "
                    "disponibilite = excluded.disponibilite, source_id = excluded.source_id, "
                    "source_url = excluded.source_url, derniere_maj = current_date;"
                )
                for allergene in plat.allergenes:
                    lignes.append(
                        "insert into public.plat_allergenes (plat_id, allergene_id) "
                        "select p.id, a.id from public.plats p, public.allergenes a "
                        f"where p.restaurant_id = (select id from public.restaurants where slug = {_sql(slug)}) "
                        f"and p.nom = {_sql(plat.nom)} and a.code = {_sql(allergene)} "
                        "on conflict (plat_id, allergene_id) do nothing;"
                    )
                for regime in plat.regimes:
                    lignes.append(
                        "insert into public.plat_regimes (plat_id, regime_id) "
                        "select p.id, rg.id from public.plats p, public.regimes_alimentaires rg "
                        f"where p.restaurant_id = (select id from public.restaurants where slug = {_sql(slug)}) "
                        f"and p.nom = {_sql(plat.nom)} and rg.code = {_sql(regime)} "
                        "on conflict (plat_id, regime_id) do nothing;"
                    )
                if plat.image:
                    image = plat.image
                    image_source_id, _ = _lien_source(image.source, None)
                    lignes.append(
                        "insert into public.images (plat_id, url, type_media, legende, est_illustration_generique, "
                        "correspondance_verifiee, auteur, licence, autorisation_usage, source_id, source_url, date_collecte) "
                        f"select p.id, {_sql(image.url)}, {_sql(image.type_media)}, {_sql(image.legende)}, "
                        f"{'true' if image.est_illustration_generique else 'false'}, "
                        f"{'true' if image.correspondance_verifiee else 'false'}, {_sql(image.auteur)}, "
                        f"{_sql(image.licence)}, {_sql(image.autorisation_usage)}, {image_source_id}, "
                        f"{_sql(image.source_url)}, {_sql(image.date_collecte)}::date "
                        "from public.plats p join public.restaurants r on r.id = p.restaurant_id "
                        f"where r.slug = {_sql(slug)} and p.nom = {_sql(plat.nom)} "
                        "on conflict (coalesce(restaurant_id, '00000000-0000-0000-0000-000000000000'::uuid), url) do nothing;"
                    )

        # Entreprises, gestionnaires, exploitation
        for exploitation in etablissement.exploitation:
            if exploitation.statut_confirmation == "inconnu" or not (
                exploitation.nom_public or exploitation.entreprise
            ):
                # Aucune identité publique : la fiche affichera « Propriétaire non renseigné ».
                continue
            nom_entreprise = exploitation.entreprise or exploitation.nom_public or "Entreprise non nommée"
            exploitation_source_id, _ = _lien_source(exploitation.source, None)
            lignes.append(
                "insert into public.entreprises (raison_sociale, nom_commercial, source_id, source_url, "
                "date_verification, statut_confirmation) select "
                f"{_sql(nom_entreprise)}, {_sql(exploitation.nom_public)}, {exploitation_source_id}, "
                f"{_sql(exploitation.source_url)}, {_sql(exploitation.date_verification)}::date, "
                f"{_sql(exploitation.statut_confirmation)} "
                "where not exists (select 1 from public.entreprises e "
                f"where e.raison_sociale = {_sql(nom_entreprise)});"
            )
            lignes.append(
                "insert into public.etablissement_exploitation (restaurant_id, entreprise_id, role, source_id, "
                "source_url, date_verification, statut_confirmation) "
                "select r.id, e.id, "
                f"{_sql(exploitation.role)}, {exploitation_source_id}, {_sql(exploitation.source_url)}, "
                f"{_sql(exploitation.date_verification)}::date, {_sql(exploitation.statut_confirmation)} "
                f"from public.restaurants r, public.entreprises e where r.slug = {_sql(slug)} "
                f"and e.raison_sociale = {_sql(nom_entreprise)} "
                # gestionnaire_id étant NULL ici, l'unicité est garantie par un contrôle explicite
                # (une contrainte UNIQUE classique ne détecte pas les doublons sur NULL).
                "and not exists (select 1 from public.etablissement_exploitation ex "
                "where ex.restaurant_id = r.id and ex.entreprise_id = e.id and ex.role = "
                f"{_sql(exploitation.role)});"
            )

        # Provenance
        for source in etablissement.sources:
            source_id_expr, _ = _lien_source(source.code, None)
            lignes.append(
                "insert into public.etablissement_sources (restaurant_id, source_id, url_exacte, date_collecte, "
                "donnees_collectees, niveau_confiance, collecte_par) "
                f"select r.id, {source_id_expr}, {_sql(source.url)}, "
                f"coalesce({_sql(source.date_collecte)}::date, current_date), {_sql(source.donnees_collectees)}, "
                f"{_sql(source.niveau_confiance)}, 'import' "
                f"from public.restaurants r where r.slug = {_sql(slug)} "
                "on conflict (restaurant_id, source_id, coalesce(url_exacte, '')) do update set "
                "donnees_collectees = excluded.donnees_collectees, niveau_confiance = excluded.niveau_confiance;"
            )
        lignes.append("")

    lignes.append("commit;")
    lignes.append("")
    return "\n".join(lignes)


# Correspondance libellés de services/équipements -> codes de la nomenclature.
_SERVICES_EQUIPEMENTS = {
    "sur place": "sur_place",
    "à emporter": "a_emporter",
    "livraison assurée par le restaurant": "livraison_restaurant",
    "livraison par un partenaire": "livraison_partenaire",
    "réservation": "reservation",
    "traiteur": "traiteur",
    "buffet": "buffet",
    "wifi": "wifi",
    "wi-fi": "wifi",
    "climatisation": "climatisation",
    "terrasse": "terrasse",
    "parking": "parking",
    "accès pmr": "acces_pmr",
    "vue mer": "vue_mer",
    "piscine": "piscine",
    "salle privée": "salle_privee",
}


def ecrire_fichier(chemin: str | Path, contenu: str) -> None:
    chemin = Path(chemin)
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_text(contenu, encoding="utf-8")
