"""Qualification sûre des noms de schéma dans le seed SQL généré.

Cette fonction ne crée aucun objet SQL et ne remplace que les qualificateurs
relationnels `public.` hors chaînes et commentaires SQL. Elle ne rend pas un
schéma cible prêt à l'emploi : tables, fonctions, contraintes, RLS et grants
doivent exister et être validés séparément avant exécution du seed.
"""
from __future__ import annotations

import re

_IDENTIFIANT_SCHEMA = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")
_DELIMITEUR_DOLLAR = re.compile(r"\$(?:[a-zA-Z_][a-zA-Z0-9_]*)?\$")


def qualifier_schema_sql(sql: str, schema_cible: str = "public") -> str:
    """Remplace les références SQL explicites à public par un schéma validé.

    Les chaînes dollar-quotées PostgreSQL et les commentaires de bloc imbriqués
    sont conservés. Il s'agit d'un ciblage textuel contrôlé, pas d'un parseur SQL.
    """
    if not isinstance(sql, str):
        raise TypeError("Le SQL doit être une chaîne de caractères.")
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
    delimiteur_dollar = ""
    profondeur_commentaire = 0
    chaine_echappement = False

    while i < len(sql):
        courant = sql[i]
        suivant = sql[i + 1] if i + 1 < len(sql) else ""

        if etat == "chaine":
            resultat.append(courant)
            if chaine_echappement and courant == "\\" and i + 1 < len(sql):
                resultat.append(suivant)
                i += 2
                continue
            if courant == "'" and suivant == "'":
                resultat.append(suivant)
                i += 2
                continue
            if courant == "'":
                etat = "normal"
                chaine_echappement = False
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

        if etat == "dollar":
            if sql.startswith(delimiteur_dollar, i):
                resultat.append(delimiteur_dollar)
                i += len(delimiteur_dollar)
                etat = "normal"
            else:
                resultat.append(courant)
                i += 1
            continue

        if etat == "commentaire_ligne":
            resultat.append(courant)
            if courant == "\n":
                etat = "normal"
            i += 1
            continue

        if etat == "commentaire_bloc":
            if courant == "/" and suivant == "*":
                resultat.extend((courant, suivant))
                profondeur_commentaire += 1
                i += 2
            elif courant == "*" and suivant == "/":
                resultat.extend((courant, suivant))
                profondeur_commentaire -= 1
                i += 2
                if profondeur_commentaire == 0:
                    etat = "normal"
            else:
                resultat.append(courant)
                i += 1
            continue

        if courant == "'":
            resultat.append(courant)
            # PostgreSQL E'...' autorise les échappements par antislash.
            chaine_echappement = (
                i > 0
                and sql[i - 1] in "eE"
                and (i < 2 or not (sql[i - 2].isalnum() or sql[i - 2] in "_$"))
            )
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
            profondeur_commentaire = 1
            i += 2
        elif courant == "$":
            correspondance = _DELIMITEUR_DOLLAR.match(sql, i)
            if correspondance:
                delimiteur_dollar = correspondance.group(0)
                resultat.append(delimiteur_dollar)
                i += len(delimiteur_dollar)
                etat = "dollar"
            else:
                resultat.append(courant)
                i += 1
        elif sql.startswith("public.", i) and (
            i == 0 or not (sql[i - 1].isalnum() or sql[i - 1] in "_$")
        ):
            resultat.append(f"{schema_cible}.")
            i += len("public.")
        else:
            resultat.append(courant)
            i += 1

    return "".join(resultat)
