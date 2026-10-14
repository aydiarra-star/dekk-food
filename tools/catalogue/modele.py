"""Modèle de données du catalogue national DEKK FOOD.

Le modèle applique les règles du cahier des charges :
- aucune donnée sans provenance (source + date) ;
- les prix, promotions, photos et identités de propriétaires ne sont publiés
  comme « confirmés » que s'ils sont adossés à une source ;
- une fiche incomplète reste publiable mais affiche clairement ses manques.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from . import normalisation as norm

STATUTS = {"ouvert", "ferme_temporairement", "ferme_definitivement", "a_verifier"}
NIVEAUX_VERIFICATION = {
    "verifie",
    "partiellement_verifie",
    "a_confirmer",
    "information_indisponible",
    "fermeture_a_verifier",
}
STATUTS_CONFIRMATION = {"confirme", "partiellement_confirme", "inconnu", "a_confirmer"}
TYPES_MEDIA = {
    "photo_facade",
    "photo_salle",
    "photo_terrasse",
    "photo_plat",
    "photo_cadre",
    "logo",
    "illustration_generique",
    "photo_autre",
}
CATEGORIES_PLAT = {
    "entree",
    "plat_principal",
    "accompagnement",
    "dessert",
    "boisson",
    "formule",
    "menu_enfant",
    "specialite",
    "petit_dejeuner",
}
JOURS = {0: "dimanche", 1: "lundi", 2: "mardi", 3: "mercredi", 4: "jeudi", 5: "vendredi", 6: "samedi"}


@dataclass
class Probleme:
    """Anomalie détectée sur une fiche."""

    niveau: str  # 'erreur' ou 'avertissement'
    code: str
    message: str
    champ: Optional[str] = None

    def as_dict(self) -> dict[str, Any]:
        return {"niveau": self.niveau, "code": self.code, "message": self.message, "champ": self.champ}


@dataclass
class Source:
    code: str
    url: Optional[str] = None
    date_collecte: Optional[str] = None
    donnees_collectees: Optional[str] = None
    niveau_confiance: str = "moyen"

    @classmethod
    def depuis_dict(cls, data: Any) -> "Source":
        if isinstance(data, str):
            return cls(code=data)
        return cls(
            code=str(data.get("source") or data.get("code") or ""),
            url=norm.normaliser_url(data.get("url")),
            date_collecte=data.get("date_collecte"),
            donnees_collectees=data.get("donnees") or data.get("donnees_collectees"),
            niveau_confiance=data.get("niveau_confiance", "moyen"),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "source": self.code,
            "url": self.url,
            "date_collecte": self.date_collecte,
            "donnees": self.donnees_collectees,
            "niveau_confiance": self.niveau_confiance,
        }


@dataclass
class Contact:
    type: str
    valeur: str
    libelle: Optional[str] = None
    confirme: bool = False
    est_principal: bool = False
    source: Optional[str] = None
    source_url: Optional[str] = None
    date_collecte: Optional[str] = None

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Contact":
        type_contact = str(data.get("type", "")).strip().lower()
        brut = data.get("valeur", "")
        if type_contact == "telephone":
            valeur = norm.normaliser_telephone(brut) or str(brut)
        elif type_contact == "whatsapp":
            valeur = norm.normaliser_whatsapp(brut) or str(brut)
        elif type_contact == "email":
            valeur = norm.normaliser_email(brut) or str(brut)
        elif type_contact in {"site_web", "facebook", "instagram", "tiktok", "x", "commande_en_ligne", "reservation"}:
            valeur = norm.normaliser_url(brut) or str(brut)
        else:
            valeur = str(brut).strip()

        return cls(
            type=type_contact,
            valeur=valeur,
            libelle=data.get("libelle"),
            confirme=bool(data.get("confirme", False)),
            est_principal=bool(data.get("est_principal", False)),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            date_collecte=data.get("date_collecte"),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "type": self.type,
            "valeur": self.valeur,
            "libelle": self.libelle,
            "confirme": self.confirme,
            "est_principal": self.est_principal,
            "source": self.source,
            "source_url": self.source_url,
            "date_collecte": self.date_collecte,
        }


@dataclass
class Image:
    url: str
    type_media: str = "photo_autre"
    legende: Optional[str] = None
    est_principale: bool = False
    est_illustration_generique: bool = False
    correspondance_verifiee: bool = False
    auteur: Optional[str] = None
    licence: Optional[str] = None
    autorisation_usage: Optional[str] = None
    autorisation_reference: Optional[str] = None
    autorisation_obtenue_le: Optional[str] = None
    source: Optional[str] = None
    source_url: Optional[str] = None
    date_collecte: Optional[str] = None
    ordre: int = 0

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Image":
        generique = bool(data.get("est_illustration_generique", False)) or data.get("type_media") == "illustration_generique"
        return cls(
            url=norm.normaliser_url(data.get("url")) or "",
            type_media=str(data.get("type_media") or ("illustration_generique" if generique else "photo_autre")),
            legende=data.get("legende"),
            est_principale=bool(data.get("est_principale", False)),
            est_illustration_generique=generique,
            correspondance_verifiee=bool(data.get("correspondance_verifiee", False)) and not generique,
            auteur=data.get("auteur"),
            licence=data.get("licence"),
            autorisation_usage=data.get("autorisation_usage"),
            autorisation_reference=data.get("autorisation_reference"),
            autorisation_obtenue_le=data.get("autorisation_obtenue_le"),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            date_collecte=data.get("date_collecte"),
            ordre=int(data.get("ordre", 0)),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "url": self.url,
            "type_media": self.type_media,
            "legende": self.legende,
            "est_principale": self.est_principale,
            "est_illustration_generique": self.est_illustration_generique,
            "correspondance_verifiee": self.correspondance_verifiee,
            "auteur": self.auteur,
            "licence": self.licence,
            "autorisation_usage": self.autorisation_usage,
            "autorisation_reference": self.autorisation_reference,
            "autorisation_obtenue_le": self.autorisation_obtenue_le,
            "source": self.source,
            "source_url": self.source_url,
            "date_collecte": self.date_collecte,
            "ordre": self.ordre,
        }


@dataclass
class Plat:
    nom: str
    description: Optional[str] = None
    categorie: str = "plat_principal"
    prix: Optional[float] = None
    devise: str = "XOF"
    taille_portion: Optional[str] = None
    options: Optional[str] = None
    variantes: Optional[str] = None
    disponibilite: str = "a_confirmer"
    date_debut: Optional[str] = None
    date_fin: Optional[str] = None
    statut_confirmation: str = "a_confirmer"
    source: Optional[str] = None
    source_url: Optional[str] = None
    allergenes: list[str] = field(default_factory=list)
    regimes: list[str] = field(default_factory=list)
    image: Optional[Image] = None

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Plat":
        prix, devise = norm.normaliser_prix(data.get("prix"), data.get("devise", "XOF"))
        image = data.get("image") or data.get("photo")
        return cls(
            nom=str(data.get("nom", "")).strip(),
            description=data.get("description") or data.get("desc"),
            categorie=data.get("categorie", "plat_principal"),
            prix=prix,
            devise=devise,
            taille_portion=data.get("taille_portion") or data.get("taille"),
            options=data.get("options"),
            variantes=data.get("variantes"),
            disponibilite=data.get("disponibilite", "a_confirmer"),
            date_debut=data.get("date_debut"),
            date_fin=data.get("date_fin"),
            statut_confirmation=data.get("statut_confirmation", "a_confirmer"),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            allergenes=list(data.get("allergenes") or []),
            regimes=list(data.get("regimes") or []),
            image=Image.depuis_dict({**image, "type_media": image.get("type_media", "photo_plat")}) if image else None,
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "nom": self.nom,
            "description": self.description,
            "categorie": self.categorie,
            "prix": self.prix,
            "devise": self.devise,
            "taille_portion": self.taille_portion,
            "options": self.options,
            "variantes": self.variantes,
            "disponibilite": self.disponibilite,
            "date_debut": self.date_debut,
            "date_fin": self.date_fin,
            "statut_confirmation": self.statut_confirmation,
            "source": self.source,
            "source_url": self.source_url,
            "allergenes": self.allergenes,
            "regimes": self.regimes,
            "image": self.image.as_dict() if self.image else None,
        }


@dataclass
class Menu:
    nom: str
    type: str = "carte"
    statut: str = "a_confirmer"
    devise: str = "XOF"
    source: Optional[str] = None
    source_url: Optional[str] = None
    date_collecte: Optional[str] = None
    date_debut: Optional[str] = None
    date_fin: Optional[str] = None
    plats: list[Plat] = field(default_factory=list)

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Menu":
        return cls(
            nom=str(data.get("nom", "Carte")).strip() or "Carte",
            type=data.get("type", "carte"),
            statut=data.get("statut", "a_confirmer"),
            devise=data.get("devise", "XOF"),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            date_collecte=data.get("date_collecte"),
            date_debut=data.get("date_debut"),
            date_fin=data.get("date_fin"),
            plats=[Plat.depuis_dict(p) for p in data.get("plats", [])],
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "nom": self.nom,
            "type": self.type,
            "statut": self.statut,
            "devise": self.devise,
            "source": self.source,
            "source_url": self.source_url,
            "date_collecte": self.date_collecte,
            "date_debut": self.date_debut,
            "date_fin": self.date_fin,
            "plats": [p.as_dict() for p in self.plats],
        }


@dataclass
class Horaire:
    jour: int
    service: str = "continu"
    ouverture: Optional[str] = None
    fermeture: Optional[str] = None
    ferme: bool = False
    confirme: bool = False
    source: Optional[str] = None
    source_url: Optional[str] = None
    date_verification: Optional[str] = None

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Horaire":
        jour = data.get("jour")
        if isinstance(jour, str):
            jour = {v: k for k, v in JOURS.items()}.get(norm.sans_accents(jour).lower(), 1)
        return cls(
            jour=int(jour if jour is not None else 1),
            service=data.get("service", "continu"),
            ouverture=norm.normaliser_horaire(data.get("ouverture")),
            fermeture=norm.normaliser_horaire(data.get("fermeture")),
            ferme=bool(data.get("ferme", False)),
            confirme=bool(data.get("confirme", False)),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            date_verification=data.get("date_verification"),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "jour": self.jour,
            "service": self.service,
            "ouverture": self.ouverture,
            "fermeture": self.fermeture,
            "ferme": self.ferme,
            "confirme": self.confirme,
            "source": self.source,
            "source_url": self.source_url,
            "date_verification": self.date_verification,
        }


@dataclass
class Exploitation:
    role: str
    nom_public: Optional[str] = None
    entreprise: Optional[str] = None
    fonction: Optional[str] = None
    telephone_pro: Optional[str] = None
    email_pro: Optional[str] = None
    source: Optional[str] = None
    source_url: Optional[str] = None
    date_verification: Optional[str] = None
    statut_confirmation: str = "inconnu"

    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Exploitation":
        return cls(
            role=data.get("role", "exploitant"),
            nom_public=data.get("nom_public"),
            entreprise=data.get("entreprise") or data.get("raison_sociale"),
            fonction=data.get("fonction"),
            telephone_pro=norm.normaliser_telephone(data.get("telephone_pro")),
            email_pro=norm.normaliser_email(data.get("email_pro")),
            source=data.get("source"),
            source_url=norm.normaliser_url(data.get("source_url")),
            date_verification=data.get("date_verification"),
            statut_confirmation=data.get("statut_confirmation", "inconnu"),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "role": self.role,
            "nom_public": self.nom_public,
            "entreprise": self.entreprise,
            "fonction": self.fonction,
            "telephone_pro": self.telephone_pro,
            "email_pro": self.email_pro,
            "source": self.source,
            "source_url": self.source_url,
            "date_verification": self.date_verification,
            "statut_confirmation": self.statut_confirmation,
        }


# --------------------------------------------------------------------------- #
# Règle de publication (une seule source de vérité : pipeline, base, application)
# --------------------------------------------------------------------------- #
REGLE_PUBLICATION = (
    "Une fiche n'est publiée que si les quatre conditions suivantes sont réunies : "
    "(1) sa région est renseignée (localisation minimale, contrainte de base "
    "restaurants_publication_localisation_check) ; "
    "(2) elle est rattachée à au moins une source documentée ; "
    "(3) son niveau de vérification n'est pas « information indisponible » ; "
    "(4) sa validation ne remonte aucune erreur. "
    "Le drapeau « est_publication_visible » du fichier de collecte exprime l'intention : "
    "la règle ne peut que le restreindre, jamais l'élargir. "
    "Une fiche non publiée est CONSERVÉE dans le dépôt, dans le catalogue et dans la base, "
    "accompagnée de son motif : aucune donnée n'est supprimée, et l'application l'annonce "
    "au lieu de l'afficher comme une fiche ordinaire."
)


@dataclass
class DecisionPublication:
    """Résultat explicite et traçable de la règle de publication."""

    visible: bool
    motifs: list[str]

    @property
    def motif_texte(self) -> Optional[str]:
        return " ; ".join(self.motifs) if self.motifs else None


def decider_publication(etablissement: "Etablissement") -> DecisionPublication:
    """Applique la règle de publication et explique chaque refus par un motif lisible."""
    motifs: list[str] = []
    if not etablissement.est_publication_visible:
        motifs.append("publication désactivée dans le fichier de collecte")
    if not norm.non_vide(etablissement.region):
        motifs.append("région non renseignée (localisation minimale exigée)")
    if not etablissement.sources:
        motifs.append("aucune source documentée")
    if etablissement.niveau_verification == "information_indisponible":
        motifs.append("niveau de vérification « information indisponible »")
    for probleme in etablissement.valider():
        if probleme.niveau == "erreur":
            motifs.append(f"{probleme.code} : {probleme.message}")
    return DecisionPublication(visible=not motifs, motifs=motifs)


@dataclass
class Etablissement:
    cle: str
    nom: str
    numero_fiche: Optional[str] = None
    slug: Optional[str] = None
    nom_officiel: Optional[str] = None
    nom_commercial: Optional[str] = None
    type_etablissement: Optional[str] = None
    categories: list[str] = field(default_factory=list)
    cuisine_type: Optional[str] = None
    description_courte: Optional[str] = None
    description_longue: Optional[str] = None
    statut: str = "a_verifier"
    niveau_verification: str = "a_confirmer"
    region: Optional[str] = None
    departement: Optional[str] = None
    commune: Optional[str] = None
    quartier: Optional[str] = None
    quartier_libre: Optional[str] = None
    ville_libre: Optional[str] = None
    adresse_complete: Optional[str] = None
    points_de_repere: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    gps_verifie: bool = False
    contacts: list[Contact] = field(default_factory=list)
    horaires: list[Horaire] = field(default_factory=list)
    services: list[str] = field(default_factory=list)
    zones_livraison: list[dict[str, Any]] = field(default_factory=list)
    fourchette_prix_min: Optional[float] = None
    fourchette_prix_max: Optional[float] = None
    devise: str = "XOF"
    ambiance: Optional[str] = None
    clientele: Optional[str] = None
    modes_paiement: list[str] = field(default_factory=list)
    accessibilite: Optional[str] = None
    equipements: list[str] = field(default_factory=list)
    images: list[Image] = field(default_factory=list)
    menus: list[Menu] = field(default_factory=list)
    exploitation: list[Exploitation] = field(default_factory=list)
    sources: list[Source] = field(default_factory=list)
    site_web: Optional[str] = None
    facebook: Optional[str] = None
    instagram: Optional[str] = None
    commande_en_ligne_url: Optional[str] = None
    reservation_url: Optional[str] = None
    date_collecte: Optional[str] = None
    derniere_verification_le: Optional[str] = None
    commentaire_verification: Optional[str] = None
    origine_donnee: Optional[str] = None
    est_publication_visible: bool = False
    motif_non_publication: Optional[str] = None
    statut_validation: str = "non_validee"
    validation_par: Optional[str] = None
    validation_le: Optional[str] = None

    # ------------------------------------------------------------------ lecture
    @classmethod
    def depuis_dict(cls, data: dict[str, Any]) -> "Etablissement":
        adresse = data.get("adresse") or {}
        fourchette = data.get("fourchette_prix") or {}
        latitude, longitude = norm.verifier_coordonnees(
            adresse.get("latitude", data.get("latitude")), adresse.get("longitude", data.get("longitude"))
        )

        etablissement = cls(
            cle=str(data.get("cle") or norm.slugifier(data.get("nom", ""))),
            nom=str(data.get("nom", "")).strip(),
            numero_fiche=data.get("numero_fiche"),
            slug=data.get("slug") or norm.slugifier(data.get("nom", "")),
            nom_officiel=data.get("nom_officiel"),
            nom_commercial=data.get("nom_commercial"),
            type_etablissement=data.get("type_etablissement"),
            categories=list(data.get("categories") or []),
            cuisine_type=data.get("cuisine_type"),
            description_courte=data.get("description_courte") or data.get("description"),
            description_longue=data.get("description_longue"),
            statut=data.get("statut", "a_verifier"),
            niveau_verification=data.get("niveau_verification", "a_confirmer"),
            region=adresse.get("region") or data.get("region"),
            departement=adresse.get("departement") or data.get("departement"),
            commune=adresse.get("commune") or data.get("commune"),
            quartier=adresse.get("quartier") or data.get("quartier"),
            quartier_libre=adresse.get("quartier_libre") or data.get("neighborhood"),
            ville_libre=adresse.get("ville_libre") or data.get("ville_libre"),
            adresse_complete=adresse.get("adresse_complete") or data.get("address"),
            points_de_repere=adresse.get("points_de_repere") or data.get("points_de_repere"),
            latitude=latitude,
            longitude=longitude,
            gps_verifie=bool(adresse.get("gps_verifie", False)) and latitude is not None,
            contacts=[Contact.depuis_dict(c) for c in data.get("contacts", [])],
            horaires=[Horaire.depuis_dict(h) for h in data.get("horaires", [])],
            services=list(data.get("services") or []),
            zones_livraison=list(data.get("zones_livraison") or []),
            fourchette_prix_min=fourchette.get("min"),
            fourchette_prix_max=fourchette.get("max"),
            devise=fourchette.get("devise", "XOF"),
            ambiance=data.get("ambiance"),
            clientele=data.get("clientele"),
            modes_paiement=list(data.get("modes_paiement") or []),
            accessibilite=data.get("accessibilite"),
            equipements=list(data.get("equipements") or []),
            images=[Image.depuis_dict(i) for i in data.get("images", [])],
            menus=[Menu.depuis_dict(m) for m in data.get("menus", [])],
            exploitation=[Exploitation.depuis_dict(e) for e in data.get("exploitation", [])],
            sources=[Source.depuis_dict(s) for s in data.get("sources", [])],
            site_web=norm.normaliser_url(data.get("site_web")),
            facebook=norm.normaliser_url(data.get("facebook")),
            instagram=norm.normaliser_url(data.get("instagram")),
            commande_en_ligne_url=norm.normaliser_url(data.get("commande_en_ligne_url")),
            reservation_url=norm.normaliser_url(data.get("reservation_url")),
            date_collecte=data.get("date_collecte"),
            derniere_verification_le=data.get("derniere_verification_le"),
            commentaire_verification=data.get("commentaire_verification"),
            origine_donnee=data.get("origine_donnee"),
            est_publication_visible=bool(data.get("est_publication_visible", False)),
            motif_non_publication=data.get("motif_non_publication"),
            statut_validation=data.get("statut_validation") or "non_validee",
            validation_par=data.get("validation_par"),
            validation_le=data.get("validation_le"),
        )

        # Un numéro fixe ne peut pas être un WhatsApp : on retire ce contact plutôt
        # que d'afficher un bouton WhatsApp qui ne fonctionnerait pas.
        etablissement.contacts = [
            contact
            for contact in etablissement.contacts
            if not (
                contact.type == "whatsapp"
                and norm.normaliser_whatsapp(contact.valeur) is None
                and norm.normaliser_telephone(contact.valeur) is not None
            )
        ]

        # Les contacts implicites (site_web, réseaux sociaux) deviennent des contacts typés.
        for type_contact, valeur in (
            ("site_web", etablissement.site_web),
            ("facebook", etablissement.facebook),
            ("instagram", etablissement.instagram),
            ("commande_en_ligne", etablissement.commande_en_ligne_url),
            ("reservation", etablissement.reservation_url),
        ):
            if valeur and not any(c.type == type_contact and c.valeur == valeur for c in etablissement.contacts):
                etablissement.contacts.append(Contact(type=type_contact, valeur=valeur, source=etablissement.origine_donnee))

        return etablissement

    # --------------------------------------------------------------- écriture
    def as_dict(self) -> dict[str, Any]:
        return {
            "cle": self.cle,
            "numero_fiche": self.numero_fiche,
            "nom": self.nom,
            "nom_officiel": self.nom_officiel,
            "nom_commercial": self.nom_commercial,
            "slug": self.slug,
            "type_etablissement": self.type_etablissement,
            "categories": self.categories,
            "cuisine_type": self.cuisine_type,
            "description_courte": self.description_courte,
            "description_longue": self.description_longue,
            "statut": self.statut,
            "niveau_verification": self.niveau_verification,
            "adresse": {
                "region": self.region,
                "departement": self.departement,
                "commune": self.commune,
                "quartier": self.quartier,
                "quartier_libre": self.quartier_libre,
                "ville_libre": self.ville_libre,
                "adresse_complete": self.adresse_complete,
                "points_de_repere": self.points_de_repere,
                "latitude": self.latitude,
                "longitude": self.longitude,
                "gps_verifie": self.gps_verifie,
            },
            "contacts": [c.as_dict() for c in self.contacts],
            "horaires": [h.as_dict() for h in self.horaires],
            "services": self.services,
            "zones_livraison": self.zones_livraison,
            "fourchette_prix": {
                "min": self.fourchette_prix_min,
                "max": self.fourchette_prix_max,
                "devise": self.devise,
            },
            "ambiance": self.ambiance,
            "clientele": self.clientele,
            "modes_paiement": self.modes_paiement,
            "accessibilite": self.accessibilite,
            "equipements": self.equipements,
            "images": [i.as_dict() for i in self.images],
            "menus": [m.as_dict() for m in self.menus],
            "exploitation": [e.as_dict() for e in self.exploitation],
            "sources": [s.as_dict() for s in self.sources],
            "site_web": self.site_web,
            "facebook": self.facebook,
            "instagram": self.instagram,
            "commande_en_ligne_url": self.commande_en_ligne_url,
            "reservation_url": self.reservation_url,
            "date_collecte": self.date_collecte,
            "derniere_verification_le": self.derniere_verification_le,
            "commentaire_verification": self.commentaire_verification,
            "origine_donnee": self.origine_donnee,
            "est_publication_visible": self.est_publication_visible,
            "motif_non_publication": self.motif_non_publication,
            "statut_validation": self.statut_validation,
            "validation_par": self.validation_par,
            "validation_le": self.validation_le,
        }

    # ------------------------------------------------------------ commodités
    def contact(self, type_contact: str) -> Optional[Contact]:
        for contact in self.contacts:
            if contact.type == type_contact:
                return contact
        return None

    @property
    def telephone(self) -> Optional[str]:
        contact = self.contact("telephone")
        return contact.valeur if contact else None

    @property
    def whatsapp(self) -> Optional[str]:
        contact = self.contact("whatsapp")
        return contact.valeur if contact else None

    @property
    def image_principale(self) -> Optional[Image]:
        for image in self.images:
            if image.est_principale:
                return image
        return self.images[0] if self.images else None

    @property
    def toutes_les_images(self) -> list[Image]:
        images = list(self.images)
        for menu in self.menus:
            for plat in menu.plats:
                if plat.image:
                    images.append(plat.image)
        return images

    @property
    def est_publiable(self) -> bool:
        return self.est_publication_visible and not any(p.niveau == "erreur" for p in self.valider())

    @property
    def publication(self) -> "DecisionPublication":
        """Décision de publication appliquée par le pipeline, la base et l'application."""
        return decider_publication(self)

    # -------------------------------------------------------- validation
    def valider(self) -> list[Probleme]:
        problemes: list[Probleme] = []

        def erreur(code: str, message: str, champ: Optional[str] = None) -> None:
            problemes.append(Probleme("erreur", code, message, champ))

        def avertissement(code: str, message: str, champ: Optional[str] = None) -> None:
            problemes.append(Probleme("avertissement", code, message, champ))

        if not norm.non_vide(self.nom):
            erreur("nom_manquant", "Le nom de l'établissement est obligatoire.", "nom")
        if self.statut not in STATUTS:
            erreur("statut_invalide", f"Statut inconnu : {self.statut}.", "statut")
        if self.niveau_verification not in NIVEAUX_VERIFICATION:
            erreur("niveau_invalide", f"Niveau de vérification inconnu : {self.niveau_verification}.", "niveau_verification")
        if self.est_publication_visible and not norm.non_vide(self.region):
            erreur(
                "region_manquante",
                "Une fiche publiée doit être rattachée à une région (14 régions du Sénégal).",
                "region",
            )
        if not self.sources:
            avertissement(
                "source_manquante",
                "Aucune source enregistrée : la fiche ne peut pas être marquée vérifiée.",
                "sources",
            )
        if not any(s.date_collecte for s in self.sources):
            avertissement("date_collecte_manquante", "Aucune date de collecte renseignée.", "sources")
        if self.niveau_verification == "verifie" and not any(
            (s.niveau_confiance == "eleve") for s in self.sources
        ):
            avertissement(
                "verification_sans_source_forte",
                "Fiche marquée « vérifié » sans source de confiance élevée : vérification humaine à confirmer.",
                "niveau_verification",
            )
        if self.gps_verifie and self.latitude is None:
            erreur("gps_incoherent", "Coordonnées marquées vérifiées alors qu'elles sont absentes ou hors Sénégal.", "gps")
        if self.latitude is not None and not norm.non_vide(self.commune) and not norm.non_vide(self.quartier):
            avertissement("localisation_grossiere", "Ni commune ni quartier renseignés : localisation approximative.", "adresse")

        # Contacts
        contacts_vus: set[tuple[str, str]] = set()
        for contact in self.contacts:
            if contact.type in {"telephone", "whatsapp"}:
                normalise = (
                    norm.normaliser_telephone(contact.valeur)
                    if contact.type == "telephone"
                    else norm.normaliser_whatsapp(contact.valeur)
                )
                if normalise is None:
                    avertissement(
                        "telephone_douteux",
                        f"Numéro non normalisable : « {contact.valeur} » — à vérifier avant publication.",
                        "contacts",
                    )
            if (contact.type, contact.valeur) in contacts_vus:
                avertissement(
                    "contact_duplique",
                    f"Contact {contact.type} en doublon : « {contact.valeur} ».",
                    "contacts",
                )
            contacts_vus.add((contact.type, contact.valeur))
            if contact.confirme and not (contact.source or contact.source_url):
                erreur(
                    "contact_confirme_sans_source",
                    f"Le contact « {contact.valeur} » est marqué confirmé sans source.",
                    "contacts",
                )

        # Horaires
        for horaire in self.horaires:
            if horaire.jour not in JOURS:
                erreur("jour_invalide", f"Jour de semaine invalide : {horaire.jour}.", "horaires")
            if not horaire.ferme and (horaire.ouverture is None or horaire.fermeture is None):
                avertissement(
                    "horaire_incomplet",
                    "Horaire sans heures d'ouverture/fermeture : ne sera pas utilisé pour l'affichage « ouvert maintenant ».",
                    "horaires",
                )
            if horaire.confirme and not (horaire.source or horaire.source_url):
                erreur("horaire_confirme_sans_source", "Horaire confirmé sans source.", "horaires")

        # Menus et plats
        for menu in self.menus:
            if menu.statut == "confirme" and not (menu.source or menu.source_url):
                erreur("menu_confirme_sans_source", f"Menu « {menu.nom} » confirmé sans source.", "menus")
            for plat in menu.plats:
                if not norm.non_vide(plat.nom):
                    erreur("plat_sans_nom", "Un plat sans nom a été fourni.", "menus")
                if plat.categorie not in CATEGORIES_PLAT:
                    avertissement("categorie_plat_inconnue", f"Catégorie de plat inhabituelle : {plat.categorie}.", "menus")
                if plat.prix is not None and plat.prix < 0:
                    erreur("prix_negatif", f"Prix négatif pour « {plat.nom} ».", "menus")
                if plat.statut_confirmation == "confirme" and not (plat.source or plat.source_url):
                    erreur(
                        "prix_confirme_sans_source",
                        f"Prix confirmé sans source pour « {plat.nom} » : un prix ne peut pas être publié comme confirmé sans provenance.",
                        "menus",
                    )
                if plat.prix is not None and plat.statut_confirmation != "confirme":
                    avertissement(
                        "prix_a_confirmer",
                        f"Prix de « {plat.nom} » à confirmer auprès de l'établissement.",
                        "menus",
                    )
                if plat.image and plat.image.type_media == "photo_plat" and not plat.image.est_illustration_generique:
                    if not (plat.image.licence or plat.image.autorisation_usage):
                        erreur(
                            "image_plat_sans_droits",
                            f"La photo de « {plat.nom} » n'a ni licence ni autorisation d'usage.",
                            "images",
                        )
                    if not plat.image.correspondance_verifiee:
                        avertissement(
                            "image_plat_non_verifiee",
                            f"La photo de « {plat.nom} » n'est pas certifiée comme correspondant au plat servi.",
                            "images",
                        )

        # Images de l'établissement
        principales = [i for i in self.images if i.est_principale]
        if len(principales) > 1:
            erreur("images_principales_multiples", "Plusieurs images principales déclarées.", "images")
        for image in self.images:
            if not norm.non_vide(image.url):
                erreur("image_sans_url", "Une image sans URL a été fournie.", "images")
            if image.est_illustration_generique and image.correspondance_verifiee:
                erreur(
                    "illustration_presentee_comme_authentique",
                    "Une illustration générique ne peut pas être marquée comme correspondant à l'établissement.",
                    "images",
                )
            if not image.est_illustration_generique and not norm.non_vide(image.licence) and not norm.non_vide(image.autorisation_usage):
                avertissement(
                    "image_sans_droits",
                    f"Image « {image.url} » sans licence ni autorisation d'usage connue.",
                    "images",
                )

        # Exploitation : jamais d'identité sans source
        for exploitation in self.exploitation:
            if exploitation.statut_confirmation == "confirme" and not (exploitation.source or exploitation.source_url):
                erreur(
                    "proprietaire_confirme_sans_source",
                    "Un propriétaire/exploitant ne peut être publié comme confirmé sans source publique fiable.",
                    "exploitation",
                )
            if exploitation.statut_confirmation == "confirme" and not exploitable_public(exploitation):
                avertissement(
                    "proprietaire_a_verifier",
                    "Information de propriété à revérifier : nom public non renseigné.",
                    "exploitation",
                )

        # Livraison
        for zone in self.zones_livraison:
            if zone.get("confirme") and not (zone.get("source_url") or zone.get("source")):
                erreur(
                    "livraison_confirmee_sans_source",
                    "Des frais ou délais de livraison ne peuvent pas être confirmés sans source.",
                    "zones_livraison",
                )

        return problemes


def exploitable_public(exploitation: Exploitation) -> bool:
    """Vrai si l'exploitation porte au moins un nom public ou une entreprise."""
    return norm.non_vide(exploitation.nom_public) or norm.non_vide(exploitation.entreprise)


def charger_etablissements(donnees: dict[str, Any]) -> list[Etablissement]:
    """Charge une liste d'établissements depuis un document JSON."""
    brut = donnees.get("etablissements", donnees if isinstance(donnees, list) else [])
    return [Etablissement.depuis_dict(item) for item in brut]
