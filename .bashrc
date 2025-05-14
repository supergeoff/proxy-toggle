# Fonction pour gérer le proxy via le script .proxy_crit.sh
proxycrit() {
    # Chemin vers votre script de gestion du proxy
    local SCRIPT_PATH="$HOME/.proxy_crit.sh"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Erreur : Le script de gestion du proxy ($SCRIPT_PATH) est introuvable."
        return 1 # Code d'erreur
    fi

    # Déterminer l'action. Si aucun argument n'est fourni à 'proxycrit',
    # on peut choisir une action par défaut, par exemple 'toggle'.
    # Par défaut sans action, cela affichera l'aide
    local action="$1"

    # Sourcer le script avec l'action déterminée
    # Le 'source' est crucial pour que les variables d'environnement (http_proxy, etc.)
    # soient définies/supprimées dans le shell courant.
    source "$SCRIPT_PATH" "$action" # On source le script avec l'argument (ou sans si $1 est vide)
    return $? # On propage le code de retour du script sourcé (0 pour succès, 1 pour aide/erreur)
}

# Rafraîchir automatiquement les variables d'environnement du proxy si le proxy était actif.
# Ceci sera exécuté à chaque ouverture d'un nouveau terminal.
if [ -f "$HOME/.proxy_status" ]; then
    # On appelle directement la fonction `proxycrit` avec la nouvelle action.
    # La sortie de 'refresh-env' (si le proxy est actif) servira de log minimal.
    proxycrit refresh-env
fi
