#!/bin/bash
# ============================================================
#  SWFE837 – Script de réinitialisation du laboratoire
#  Remet les interfaces dans un état propre entre les TP
#  Version corrigée – Ne redémarre pas NetworkManager
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[RESET]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[!]${NC}    $1"; }

[[ $EUID -ne 0 ]] && { echo "Exécuter en root (sudo)"; exit 1; }

info "Arrêt des services en cours..."

# Arrêter NetworkManager et wpa_supplicant système (évite la recréation du socket)
systemctl stop NetworkManager wpa_supplicant 2>/dev/null && success "NetworkManager/wpa_supplicant système arrêtés" || warn "Services déjà arrêtés ou non présents"
pkill -9 wpa_supplicant 2>/dev/null || true
sleep 1

# Arrêt des processus du labo
pkill -9 hostapd     2>/dev/null && success "hostapd arrêté"      || true
pkill -9 dnsmasq     2>/dev/null && success "dnsmasq arrêté"      || true
pkill -9 tcpdump     2>/dev/null && success "tcpdump arrêté"      || true
pkill -9 airodump-ng 2>/dev/null && success "airodump-ng arrêté"  || true
pkill -9 aireplay-ng 2>/dev/null && success "aireplay-ng arrêté"  || true
pkill -9 python3     2>/dev/null && success "scripts Python arrêtés" || true

info "Nettoyage des sockets wpa_supplicant..."
# Supprime aussi bien le dossier système que les éventuels dossiers temporaires
rm -rf /run/wpa_supplicant/wlan* 2>/dev/null && success "Sockets /run/wpa_supplicant supprimés"
rm -rf /tmp/wpa_supplicant_labo 2>/dev/null && success "Dossier temporaire supprimé"

info "Remise des interfaces en mode managed..."
for iface in $(iw dev 2>/dev/null | grep Interface | awk '{print $2}'); do
  # Si l'interface est en mode monitor, on la repasse en managed
  if iw dev "$iface" info 2>/dev/null | grep -q monitor; then
    # Utiliser airmon-ng stop pour un retour propre, sinon ip link set
    airmon-ng stop "$iface" &>/dev/null || {
      ip link set "$iface" down 2>/dev/null
      iw dev "$iface" set type managed 2>/dev/null
      ip link set "$iface" up 2>/dev/null
    }
    success "Interface $iface remise en mode managed"
  fi
done

info "Nettoyage des règles iptables temporaires..."
iptables -F 2>/dev/null && success "iptables vidé"
iptables -t nat -F 2>/dev/null

info "Suppression des fichiers de capture temporaires..."
rm -f /tmp/*.pcap /tmp/*.cap /tmp/*.hc22000 2>/dev/null
success "Fichiers temporaires supprimés"

info "Restauration des routes réseau..."
# NetworkManager reste volontairement arrêté pour ne pas interférer avec les TP.
# Pour le redémarrer après la séance, exécutez : sudo systemctl start NetworkManager
warn "NetworkManager est maintenu à l'arrêt (évite les conflits avec les TP)."
warn "Après la formation, relancez-le avec : sudo systemctl start NetworkManager"

# Création du répertoire de contrôle isolé pour wpa_supplicant
mkdir -p /tmp/wpa_supplicant_labo
success "Répertoire de contrôle client prêt : /tmp/wpa_supplicant_labo"

# ... début du script ...
echo ""
echo -e "${BLUE}${BOLD}[1] Vérification du module Wi-Fi simulé${NC}"
if lsmod | grep -q mac80211_hwsim; then
  success "mac80211_hwsim déjà chargé"
else
  modprobe mac80211_hwsim radios=4 && success "mac80211_hwsim chargé (4 radios)" || warn "Impossible de charger mac80211_hwsim"
fi

# Puis la remise en managed...

echo ""
echo -e "${GREEN}═══════════════════════════════════${NC}"
echo -e "${GREEN}  Labo réinitialisé – Prêt pour TP ${NC}"
echo -e "${GREEN}═══════════════════════════════════${NC}"