"""Qualification sûre des noms de schéma dans le seed SQL généré.

Cette fonction ne crée aucun objet SQL et ne remplace que les qualificateurs
relationnels `public.` dans le texte généré. Elle ne rend pas un schéma cible
prêt à l'emploi : tables, fonctions, contraintes, RLS et grants doivent exister
et être validés séparément avant exécution du seed.
"""
from __future__ import annotations

import re

_IDENTIFIANT_SCHEMA = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")
_QUALIFICATEUR_PUBLIC = re.compile(r"(?<![A-Za-z0-9_$])public\.")


def qualifier_schema_sql(sql: str, schema_cible: str = "public") -> str:
    """Remplace les références SQL explicites à public par un schéma validé."""
    if not isinstance(schema_cible, str) or not _IDENTIFIANT_SCHEMA.fullmatch(schema_cible):
        raise ValueError(
            "Nom de schéma invalide : utilisez un identifiant PostgreSQL minuscule "
            "commençant par une lettre ou '_' (63 caractères maximum)."
        )
    if schema_cible == "public":
        return sql
    return _QUALIFICATEUR_PUBLIC.sub(f"{schema_cible}.", sql)
