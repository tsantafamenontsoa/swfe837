#!/bin/bash
# ============================================================
#  SWFE837 – Script de réinitialisation du laboratoire
#  Remet les interfaces dans un état propre entre les TP
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[RESET]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }

[[ $EUID -ne 0 ]] && { echo "Exécuter en root (sudo)"; exit 1; }

info "Arrêt des services en cours..."

# Arrêter NetworkManager et wpa_supplicant système (évite la recréation du socket)
systemctl stop NetworkManager wpa_supplicant 2>/dev/null && success "NetworkManager/wpa_supplicant système arrêtés" || true
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
rm -rf /run/wpa_supplicant/wlan* 2>/dev/null && success "Sockets wpa_supplicant supprimés" || true

info "Remise des interfaces en mode managed..."
for iface in $(iw dev 2>/dev/null | grep Interface | awk '{print $2}'); do
  if iw dev "$iface" info 2>/dev/null | grep -q monitor; then
    airmon-ng stop "$iface" 2>/dev/null || ip link set "$iface" down 2>/dev/null
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
# Relancer le service réseau si nécessaire
systemctl restart NetworkManager 2>/dev/null && success "NetworkManager redémarré" || true

echo ""
echo -e "${GREEN}═══════════════════════════════════${NC}"
echo -e "${GREEN}  Labo réinitialisé – Prêt pour TP ${NC}"
echo -e "${GREEN}═══════════════════════════════════${NC}"
