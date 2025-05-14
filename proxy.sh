#!/bin/bash

# URL du proxy
PROXY_URL="http://monproxy.com:80"
# Valeur attendue pour no_proxy (doit correspondre à ce qui est défini dans set_proxy)
NO_PROXY_EXPECTED_VALUE="localhost,127.0.0.1"
# Fichier de configuration pour suivre l'état du proxy
STATUS_FILE="$HOME/.proxy_status"

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fonction pour afficher un message de vérification
# $1: Nom du test
# $2: Booléen (0 pour succès, 1 pour échec)
# $3: Message en cas de succès (optionnel)
# $4: Message en cas d'échec (optionnel)
check_result() {
    local test_name="$1"
    local result="$2"
    local success_msg="${3:-OK}"
    local failure_msg="${4:-KO}"
    local current_value_msg=""

    # Si le message d'échec contient "(actuel:", on l'isole pour l'affichage
    if [[ "$failure_msg" == *" (actuel:"* ]]; then
        current_value_msg=" ${failure_msg#* (actuel:}" # Récupère la partie après "(actuel:"
        failure_msg="${failure_msg%% (actuel:*}" # Récupère la partie avant "(actuel:"
    fi

    if [ "$result" -eq 0 ]; then
        echo "[✓] $test_name: $success_msg"
    else
        if [ -n "$current_value_msg" ]; then
             echo "[✗] $test_name: $failure_msg (actuel:$current_value_msg"
        else
             echo "[✗] $test_name: $failure_msg"
        fi
    fi
    return "$result"
}

# Fonction pour vérifier l'état des configurations du proxy
# $1: "set" pour vérifier si activé, "unset" pour vérifier si désactivé
verify_proxy_settings() {
    local mode="$1"
    echo ""
    echo "Vérification des configurations (mode: $mode):"
    local overall_status=0 # 0 pour succès global, 1 si au moins un échec

    # 1. Variables d'environnement (celles du script, nécessite de sourcer pour le shell parent)
    if [ "$mode" = "set" ]; then
        check_result "Variable http_proxy" "$([ "${http_proxy:-}" = "$PROXY_URL" ] && echo 0 || echo 1)" "Définie à $PROXY_URL" "Non définie ou incorrecte (actuel: '${http_proxy:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable https_proxy" "$([ "${https_proxy:-}" = "$PROXY_URL" ] && echo 0 || echo 1)" "Définie à $PROXY_URL" "Non définie ou incorrecte (actuel: '${https_proxy:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable HTTP_PROXY" "$([ "${HTTP_PROXY:-}" = "$PROXY_URL" ] && echo 0 || echo 1)" "Définie à $PROXY_URL" "Non définie ou incorrecte (actuel: '${HTTP_PROXY:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable HTTPS_PROXY" "$([ "${HTTPS_PROXY:-}" = "$PROXY_URL" ] && echo 0 || echo 1)" "Définie à $PROXY_URL" "Non définie ou incorrecte (actuel: '${HTTPS_PROXY:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable no_proxy" "$([ "${no_proxy:-}" = "$NO_PROXY_EXPECTED_VALUE" ] && echo 0 || echo 1)" "Définie à $NO_PROXY_EXPECTED_VALUE" "Non définie ou incorrecte (actuel: '${no_proxy:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable NO_PROXY" "$([ "${NO_PROXY:-}" = "$NO_PROXY_EXPECTED_VALUE" ] && echo 0 || echo 1)" "Définie à $NO_PROXY_EXPECTED_VALUE" "Non définie ou incorrecte (actuel: '${NO_PROXY:-non définie}')"
        [[ $? -ne 0 ]] && overall_status=1
    else # unset
        check_result "Variable http_proxy" "$([ -z "${http_proxy:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$http_proxy')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable https_proxy" "$([ -z "${https_proxy:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$https_proxy')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable HTTP_PROXY" "$([ -z "${HTTP_PROXY:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$HTTP_PROXY')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable HTTPS_PROXY" "$([ -z "${HTTPS_PROXY:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$HTTPS_PROXY')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable no_proxy" "$([ -z "${no_proxy:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$no_proxy')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Variable NO_PROXY" "$([ -z "${NO_PROXY:-}" ] && echo 0 || echo 1)" "Non définie" "Toujours définie (actuel: '$NO_PROXY')"
        [[ $? -ne 0 ]] && overall_status=1
    fi

    # 2. Configuration d'apt
    local apt_proxy_file="/etc/apt/apt.conf.d/99proxy"
    if [ "$mode" = "set" ]; then
        local apt_check=1 # échec par défaut
        if [ -f "$apt_proxy_file" ] && sudo grep -q "Acquire::http::Proxy \"$PROXY_URL\";" "$apt_proxy_file" && sudo grep -q "Acquire::https::Proxy \"$PROXY_URL\";" "$apt_proxy_file"; then
            apt_check=0 # succès
        fi
        check_result "Configuration apt" "$apt_check" "Activée et correcte" "Non activée ou incorrecte"
        [[ $? -ne 0 ]] && overall_status=1
    else # unset
        check_result "Configuration apt" "$([ ! -f "$apt_proxy_file" ] && echo 0 || echo 1)" "Désactivée (fichier supprimé)" "Toujours activée (fichier présent)"
        [[ $? -ne 0 ]] && overall_status=1
    fi

    # 3. Configuration de git
    if [ "$mode" = "set" ]; then
        check_result "Git http.proxy" "$([ \"$(git config --global http.proxy || echo "")\" = \"$PROXY_URL\" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$(git config --global http.proxy || echo "non défini")')"
        [[ $? -ne 0 ]] && overall_status=1
        check_result "Git https.proxy" "$([ \"$(git config --global https.proxy || echo "")\" = \"$PROXY_URL\" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$(git config --global https.proxy || echo "non défini")')"
        [[ $? -ne 0 ]] && overall_status=1
    else # unset
        # Git http.proxy
        local git_http_proxy_current_val
        git_http_proxy_current_val=$(git config --global http.proxy 2>/dev/null) # Capture la sortie ou rien, ignore les erreurs ici
        local git_http_check
        if git config --global http.proxy >/dev/null 2>&1; then
            # La commande a réussi (code de sortie 0), donc la config existe encore
            git_http_check=1 # Échec pour "unset"
        else
            # La commande a échoué (code de sortie non-0), donc la config n'existe pas/plus
            git_http_check=0 # Succès pour "unset"
        fi
        # Utilise git_http_proxy_current_val pour le message, avec "non défini" comme fallback si vide
        check_result "Git http.proxy" "$git_http_check" "Non défini" "Toujours défini (actuel: '${git_http_proxy_current_val:-non défini}')"
        [[ $? -ne 0 ]] && overall_status=1

        # Git https.proxy
        local git_https_proxy_current_val
        git_https_proxy_current_val=$(git config --global https.proxy 2>/dev/null) # Capture la sortie ou rien
        local git_https_check
        if git config --global https.proxy >/dev/null 2>&1; then
            git_https_check=1 # Échec pour "unset"
        else
            git_https_check=0 # Succès pour "unset"
        fi
        check_result "Git https.proxy" "$git_https_check" "Non défini" "Toujours défini (actuel: '${git_https_proxy_current_val:-non défini}')"
        [[ $? -ne 0 ]] && overall_status=1
    fi

    # 4. Configuration de npm
    if command_exists npm; then
        if [ "$mode" = "set" ]; then
            local npm_proxy_val; npm_proxy_val=$(npm config get proxy 2>/dev/null || echo "null") # Gère l'erreur si non défini
            check_result "npm proxy" "$([ "$npm_proxy_val" = "$PROXY_URL" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$npm_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1
            
            local npm_https_proxy_val; npm_https_proxy_val=$(npm config get https-proxy 2>/dev/null || echo "null")
            check_result "npm https-proxy" "$([ "$npm_https_proxy_val" = "$PROXY_URL" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$npm_https_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1
        else # unset
            local npm_proxy_val; npm_proxy_val=$(npm config get proxy 2>/dev/null || echo "null")
            check_result "npm proxy" "$([ "$npm_proxy_val" = "null" ] || [ "$npm_proxy_val" = "undefined" ] || [ -z "$npm_proxy_val" ] && echo 0 || echo 1)" "Non défini" "Toujours défini (actuel: '$npm_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1
            
            local npm_https_proxy_val; npm_https_proxy_val=$(npm config get https-proxy 2>/dev/null || echo "null")
            check_result "npm https-proxy" "$([ "$npm_https_proxy_val" = "null" ] || [ "$npm_https_proxy_val" = "undefined" ] || [ -z "$npm_https_proxy_val" ] && echo 0 || echo 1)" "Non défini" "Toujours défini (actuel: '$npm_https_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1
        fi
    else
        echo "[i] npm non trouvé, vérification npm ignorée."
    fi

    # 5. Configuration de pnpm
    if command_exists pnpm; then
        if [ "$mode" = "set" ]; then
            local pnpm_proxy_val; pnpm_proxy_val=$(pnpm config get proxy 2>/dev/null || echo "")
            check_result "pnpm proxy" "$([ "$pnpm_proxy_val" = "$PROXY_URL" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$pnpm_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1

            local pnpm_https_proxy_val; pnpm_https_proxy_val=$(pnpm config get https-proxy 2>/dev/null || echo "")
            check_result "pnpm https-proxy" "$([ "$pnpm_https_proxy_val" = "$PROXY_URL" ] && echo 0 || echo 1)" "Défini à $PROXY_URL" "Non défini ou incorrect (actuel: '$pnpm_https_proxy_val')"
            [[ $? -ne 0 ]] && overall_status=1
        else # unset
            local pnpm_proxy_check=1 # échec par défaut
            # pnpm config get renvoie une chaîne vide et code d'erreur 1 si non défini.
            # Nous vérifions donc si la commande échoue OU si la sortie est vide.
            if ! pnpm config get proxy >/dev/null 2>&1 || [ -z "$(pnpm config get proxy 2>/dev/null || echo "")" ]; then
                pnpm_proxy_check=0 # succès
            fi
            check_result "pnpm proxy" "$pnpm_proxy_check" "Non défini" "Toujours défini (actuel: '$(pnpm config get proxy 2>/dev/null || echo "non défini")')"
            [[ $? -ne 0 ]] && overall_status=1

            local pnpm_https_proxy_check=1 # échec par défaut
            if ! pnpm config get https-proxy >/dev/null 2>&1 || [ -z "$(pnpm config get https-proxy 2>/dev/null || echo "")" ]; then
                pnpm_https_proxy_check=0 # succès
            fi
            check_result "pnpm https-proxy" "$pnpm_https_proxy_check" "Non défini" "Toujours défini (actuel: '$(pnpm config get https-proxy 2>/dev/null || echo "non défini")')"
            [[ $? -ne 0 ]] && overall_status=1
        fi
    else
        echo "[i] pnpm non trouvé, vérification pnpm ignorée."
    fi
    
    echo "--------------------------------------"
    if [ "$overall_status" -eq 0 ]; then
        echo "Vérification terminée: Toutes les configurations sont comme attendues pour le mode '$mode'."
    else
        echo "Vérification terminée: Certaines configurations ne sont PAS comme attendues pour le mode '$mode'."
    fi
    echo ""
    return "$overall_status"
}

# Fonction pour activer les paramètres du proxy
set_proxy() {
    echo "Définition des variables d'environnement pour cette session et ses processus enfants..."
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    export no_proxy="$NO_PROXY_EXPECTED_VALUE"
    export NO_PROXY="$NO_PROXY_EXPECTED_VALUE"
    echo "Variables d'environnement définies."
    echo "IMPORTANT: Pour que ces variables soient appliquées à votre terminal ACTUEL,"
    echo "vous DEVEZ sourcer ce script. Ex: '. $(basename -- "${BASH_SOURCE[0]}") set' ou 'source $(basename -- "${BASH_SOURCE[0]}") set'"
    echo "Sinon, elles ne seront actives que pour les commandes lancées PAR ce script."

    echo "Configuration d'apt..."
    echo "Acquire::http::Proxy \"$PROXY_URL\";" | sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null
    echo "Acquire::https::Proxy \"$PROXY_URL\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy > /dev/null
    echo "Acquire::Pipeline-Depth \"0\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy > /dev/null
    echo "Configuration d'apt terminée."

    echo "Configuration de git..."
    git config --global http.proxy "$PROXY_URL"
    git config --global https.proxy "$PROXY_URL"
    echo "Configuration de git terminée."

    if command_exists npm; then
        echo "Configuration de npm..."
        npm config set proxy "$PROXY_URL" --silent
        npm config set https-proxy "$PROXY_URL" --silent
        echo "Configuration de npm terminée."
    else
        echo "npm non trouvé, étape de configuration npm ignorée."
    fi

    if command_exists pnpm; then
        echo "Configuration de pnpm..."
        pnpm config set proxy "$PROXY_URL"
        pnpm config set https-proxy "$PROXY_URL"
        echo "Configuration de pnpm terminée."
    else
        echo "pnpm non trouvé, étape de configuration pnpm ignorée."
    fi
    return 0 # Indique le succès
}

# Fonction pour désactiver les paramètres du proxy
unset_proxy() {
    echo "Suppression des variables d'environnement..."
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
    echo "Variables d'environnement supprimées."
    echo "IMPORTANT: Pour que la suppression des variables d'environnement soit effective dans votre terminal ACTUEL,"
    echo "vous DEVEZ sourcer ce script. Ex: '. $(basename -- "${BASH_SOURCE[0]}") unset' ou 'source $(basename -- "${BASH_SOURCE[0]}") unset'"

    echo "Suppression de la configuration d'apt..."
    sudo rm -f /etc/apt/apt.conf.d/99proxy
    echo "Configuration d'apt supprimée."

    echo "Suppression de la configuration de git..."
    git config --global --unset http.proxy || true
    git config --global --unset https.proxy || true
    echo "Configuration de git supprimée."

    if command_exists npm; then
        echo "Suppression de la configuration de npm..."
        npm config delete proxy --silent || true
        npm config delete https-proxy --silent || true
        echo "Configuration de npm supprimée."
    else
        echo "npm non trouvé, étape de suppression npm ignorée."
    fi

    if command_exists pnpm; then
        echo "Suppression de la configuration de pnpm..."
        pnpm config delete proxy || true
        pnpm config delete https-proxy || true
        echo "Configuration de pnpm supprimée."
    else
        echo "pnpm non trouvé, étape de suppression pnpm ignorée."
    fi
    return 0 # Indique le succès
}

# Fonction pour afficher l'état actuel (format que vous aviez)
show_status() {
    echo "--- État du Proxy ---"
    if [ -f "$STATUS_FILE" ]; then
        echo "Indicateur de statut ($STATUS_FILE): ACTIVÉ"
    else
        echo "Indicateur de statut ($STATUS_FILE): DÉSACTIVÉ"
    fi

    echo ""
    echo "Variables d'environnement (état actuel dans CE SCRIPT, sourcez pour affecter le shell parent):"
    echo "http_proxy: ${http_proxy:-non défini}"
    echo "https_proxy: ${https_proxy:-non défini}"
    echo "HTTP_PROXY: ${HTTP_PROXY:-non défini}"
    echo "HTTPS_PROXY: ${HTTPS_PROXY:-non défini}"
    echo "no_proxy: ${no_proxy:-non défini}"
    echo "NO_PROXY: ${NO_PROXY:-non défini}"
    
    echo ""
    echo "Configuration apt (/etc/apt/apt.conf.d/99proxy):"
    if [ -f "/etc/apt/apt.conf.d/99proxy" ]; then
        # Utiliser sudo pour lire le fichier, au cas où les permissions seraient restrictives
        sudo cat "/etc/apt/apt.conf.d/99proxy"
    else
        echo "Non configuré."
    fi

    echo ""
    echo "Configuration git globale:"
    echo "http.proxy: $(git config --global http.proxy || echo 'non défini')"
    echo "https.proxy: $(git config --global https.proxy || echo 'non défini')"

    if command_exists npm; then
        echo ""
        echo "Configuration npm:"
        # Gérer les erreurs si npm config get échoue (par ex. si le fichier .npmrc est corrompu)
        echo "proxy: $(npm config get proxy 2>/dev/null || echo 'non défini')"
        echo "https-proxy: $(npm config get https-proxy 2>/dev/null || echo 'non défini')"
    fi

    if command_exists pnpm; then
        echo ""
        echo "Configuration pnpm:"
        echo "proxy: $(pnpm config get proxy 2>/dev/null || echo 'non défini')"
        echo "https-proxy: $(pnpm config get https-proxy 2>/dev/null || echo 'non défini')"
    fi
    echo "---------------------"
    return 0 # Indique le succès
}


# Logique principale pour basculer, activer, désactiver ou afficher l'état
case "$1" in
    set)
        echo "Activation explicite du proxy..."
        set_proxy
        touch "$STATUS_FILE"
        echo "Proxy activé."
        verify_proxy_settings "set"
        echo "N'oubliez pas de sourcer le script si ce n'est pas déjà fait pour les variables d'environnement."
        ;;
    unset)
        echo "Désactivation explicite du proxy..."
        unset_proxy
        rm -f "$STATUS_FILE"
        echo "Proxy désactivé."
        verify_proxy_settings "unset"
        echo "N'oubliez pas de sourcer le script si ce n'est pas déjà fait pour les variables d'environnement."
        ;;
    toggle)
        if [ -f "$STATUS_FILE" ]; then
            echo "Proxy actuellement activé (selon $STATUS_FILE), désactivation..."
            unset_proxy
            rm -f "$STATUS_FILE"
            echo "Proxy désactivé."
            verify_proxy_settings "unset"
        else
            echo "Proxy actuellement désactivé (selon $STATUS_FILE), activation..."
            set_proxy
            touch "$STATUS_FILE"
            echo "Proxy activé."
            verify_proxy_settings "set"
        fi
        echo "N'oubliez pas de sourcer le script si ce n'est pas déjà fait pour les variables d'environnement."
        ;;
    status)
        show_status
        ;;
    *)
        # Utiliser basename "${BASH_SOURCE[0]}" pour afficher le nom réel du script
        # ${BASH_SOURCE[0]} est le chemin du script lui-même.
        # Si le script est sourcé, ${BASH_SOURCE[0]} sera le chemin du script sourcé.
        # Si le script est exécuté directement, ${BASH_SOURCE[0]} sera le chemin du script exécuté.
        # $0 est le nom de la commande (ex: bash, ou le nom du script si exécuté directement).
        local script_name
        script_name=$(basename -- "${BASH_SOURCE[0]}") # Obtient le nom du fichier du script actuel

        echo "Usage: proxycrit (ou alias .bashrc) {set|unset|toggle|status} OU $script_name {set|unset|toggle|status}"
        echo "Exemples:"
        echo "proxycrit toggle OU . $script_name toggle           # Bascule ET applique les variables d'env au shell actuel"
        echo "proxycrit set OU source $script_name set            # Active ET applique les variables d'env au shell actuel"
        echo "proxycrit unset OU source $script_name unset        # Desactive ET applique les variables d'env au shell actuel"
        echo "proxycrit status OU $script_name status             # Affiche l'état actuel des configurations"
        
        # Vérifier si le script est sourcé ou exécuté directement
        # ${BASH_SOURCE[0]} est le chemin du script.
        # $0 est le nom de la commande (ex: bash, ou le nom du script si exécuté directement).
        # Si différents, le script est sourcé.
        if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
            return 1 # Script sourcé : retourne une erreur sans quitter le shell
        else
            exit 1   # Script exécuté directement : quitte avec un code d'erreur
        fi
        ;;
esac

# Si une action valide a été exécutée (set, unset, toggle, status),
# le script arrivera ici. On s'assure de retourner 0 (succès) si le script est sourcé.
# Pour le cas '*', le 'return 1' ou 'exit 1' est déjà géré.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0 # Succès pour les actions valides lorsqu'il est sourcé
fi
