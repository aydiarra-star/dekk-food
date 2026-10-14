"""Qualification sûre des noms de schéma dans le seed SQL généré.

Cette fonction ne crée aucun objet SQL et ne remplace que les qualificateurs
relationnels `public.` hors chaînes et commentaires SQL. Elle ne rend pas un
schéma cible prêt à l'emploi : tables, fonctions, contraintes, RLS et grants
doivent exister et être validés séparément avant exécution du seed.
"""
from __future__ import annotations

import re

_IDENTIFIANT_SCHEMA = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")


def qualifier_schema_sql(sql: str, schema_cible: str = "public") -> str:
    """Remplace les références SQL explicites à public par un schéma validé."""
    if not isinstance(schema_cible, str) or not _IDENTIFIANT_SCHEMA.fullmatch(schema_cible):
        raise ValueError(
            "Nom de schéma invalide : utilisez un identifiant PostgreSQL minuscule "
            "commençant par une lettre ou '_' (63 caractères maximum)."
        )
    if schema_cible == "public":
        return sql

    resultat: list[str] = []
    i = 0
    etat = "normal"
    while i < len(sql):
        courant = sql[i]
        suivant = sql[i + 1] if i + 1 < len(sql) else ""

        if etat == "chaine":
            resultat.append(courant)
            if courant == "'" and suivant == "'":
                resultat.append(suivant)
                i += 2
                continue
            if courant == "'":
                etat = "normal"
            i += 1
            continue

        if etat == "identifiant":
            resultat.append(courant)
            if courant == '"' and suivant == '"':
                resultat.append(suivant)
                i += 2
                continue
            if courant == '"':
                etat = "normal"
            i += 1
            continue

        if etat == "commentaire_ligne":
            resultat.append(courant)
            if courant == "\n":
                etat = "normal"
            i += 1
            continue

        if etat == "commentaire_bloc":
            if courant == "*" and suivant == "/":
                resultat.extend((courant, suivant))
                i += 2
                etat = "normal"
            else:
                resultat.append(courant)
                i += 1
            continue

        if courant == "'" :
            resultat.append(courant)
            etat = "chaine"
            i += 1
        elif courant == '"':
            resultat.append(courant)
            etat = "identifiant"
            i += 1
        elif courant == "-" and suivant == "-":
            resultat.extend((courant, suivant))
            etat = "commentaire_ligne"
            i += 2
        elif courant == "/" and suivant == "*":
            resultat.extend((courant, suivant))
            etat = "commentaire_bloc"
            i += 2
        elif sql.startswith("public.", i) and (
            i == 0 or not (sql[i - 1].isalnum() or sql[i - 1] in "_$")
        ):
            resultat.append(f"{schema_cible}.")
            i += len("public.")
        else:
            resultat.append(courant)
            i += 1

    return "".join(resultat)
