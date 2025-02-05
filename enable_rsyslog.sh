#!/bin/bash

# Configuration
LOG_FILE="/var/log/rsyslog_install.log"
CONF_BACKUP="/etc/rsyslog.conf.bak"

# Initialisation du logging
exec > >(tee -a "$LOG_FILE") 2>&1

# Fonction de journalisation avec horodatage
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Fonction de gestion d'erreur
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Afficher la progression
show_progress() {
    echo -e "\n[Étape $1/$2] $3..."
}

# Vérification root
if [ "$EUID" -ne 0 ]; then
    error_exit "Ce script doit être exécuté en tant que root"
fi

log "Début de l'installation/configuration de rsyslog"

# Étape 1: Mise à jour des paquets
show_progress 1 5 "Mise à jour des paquets"
apt-get update -q || error_exit "Échec de la mise à jour des paquets"

# Étape 2: Installation de rsyslog
show_progress 2 5 "Installation du paquet rsyslog"
if ! dpkg -l | grep -q rsyslog; then
    apt-get install -yq rsyslog || error_exit "Échec de l'installation de rsyslog"
else
    log "Rsyslog est déjà installé"
fi

# Étape 3: Sauvegarde de la configuration existante
show_progress 3 5 "Sauvegarde de la configuration"
if [ ! -f "$CONF_BACKUP" ]; then
    cp /etc/rsyslog.conf "$CONF_BACKUP" || error_exit "Échec de la sauvegarde"
fi

# Étape 4: Configuration de base
show_progress 4 5 "Application de la configuration"
cat > /etc/rsyslog.conf << 'EOF'
# Configuration minimale rsyslog
module(load="imuxsock")    # Support des sockets Unix
module(load="imklog")      # Messages du kernel

# Règles de journalisation
*.info;mail.none;authpriv.none;cron.none  /var/log/messages
authpriv.*                                 /var/log/auth.log
mail.*                                     -/var/log/mail.log
cron.*                                      /var/log/cron.log
*.emerg                                     :omusrmsg:*
local7.*                                    /var/log/boot.log

# Format de sortie
$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
$RepeatedMsgReduction on
EOF

[ $? -eq 0 ] || error_exit "Échec de l'écriture de la configuration"

# Étape 5: Redémarrage du service
show_progress 5 5 "Redémarrage du service"
systemctl restart rsyslog || error_exit "Échec du redémarrage du service"
systemctl enable rsyslog >/dev/null 2>&1 || error_exit "Échec de l'activation au démarrage"

# Vérification finale
if systemctl is-active --quiet rsyslog; then
    log "Installation réussie - Rsyslog est fonctionnel"
    echo "Journal complet disponible sur: $LOG_FILE"
else
    error_exit "Le service rsyslog ne fonctionne pas correctement"
fi
