#!/bin/bash
# ============================================================
#  SWFE837 – Script d'installation du laboratoire Wi-Fi
#  Mastère SIN Expert Cybersécurité – 2025-2026
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

# ── Répertoire source : parent du script (dossier swfe837/) ───
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
LABO_SRC="$(dirname "$SCRIPT_DIR")"   # swfe837/

# ── Vérifications préalables ──────────────────────────────────
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."
[[ $(uname -s) != "Linux" ]] && error "Ce script est prévu pour Linux (Kali)."
[[ ! -d "$LABO_SRC/configs" ]] && error "Dossier configs introuvable. Exécutez ce script depuis swfe837/scripts/ après avoir extrait le ZIP."

info "Répertoire source détecté : $LABO_SRC"

info "Mise à jour des dépôts..."
apt-get update -qq

# ── Paquets requis ────────────────────────────────────────────
PKGS=(
  aircrack-ng      # Suite Wi-Fi (airodump, aireplay, aircrack)
  hashcat          # Cracking GPU/CPU
  hostapd          # Point d'accès logiciel (TP2 & TP3)
  freeradius       # Serveur RADIUS (TP2)
  freeradius-utils # radtest, etc.
  tcpdump          # Capture réseau (TP3)
  wireshark        # Analyse de paquets
  python3-scapy    # IDS Python (TP4)
  python3-pip      # Pour dépendances Python
  net-tools        # ifconfig, etc.
  iw               # Gestion interfaces Wi-Fi
  wireless-tools   # iwconfig, iwlist
  dnsmasq          # DHCP/DNS pour Evil Twin
  curl             # Téléchargements
  hcxdumptool      # Capture PMKID
  hcxtools         # Conversion pcapng → hc22000
)

info "Installation des paquets..."
for pkg in "${PKGS[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    success "$pkg déjà installé"
  else
    apt-get install -y -qq "$pkg" && success "$pkg installé" || \
      info "$pkg non disponible (non bloquant)"
  fi
done

# ── Dépendances Python ────────────────────────────────────────
info "Installation des modules Python..."
pip3 install -q scapy colorama 2>/dev/null && success "Modules Python installés"

# ── Téléchargement wordlist ───────────────────────────────────
WORDLIST_DIR="/opt/wordlists"
mkdir -p "$WORDLIST_DIR"
if [ ! -f "$WORDLIST_DIR/rockyou_small.txt" ]; then
  info "Création de rockyou_small.txt..."
  if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    gunzip -c /usr/share/wordlists/rockyou.txt.gz | head -100000 > "$WORDLIST_DIR/rockyou_small.txt"
    success "rockyou_small.txt créé (100 000 entrées)"
  else
    printf "password\n123456\nwifi1234\nMotDePasse\nadmin\nazerty\nqwerty\n12345678\nlabo2026\nsecwifi\n" \
      > "$WORDLIST_DIR/rockyou_small.txt"
    success "Wordlist de démonstration créée"
  fi
fi

# ── Interfaces virtuelles ─────────────────────────────────────
info "Vérification des interfaces Wi-Fi..."
WIFI_IFACES=$(iw dev 2>/dev/null | grep Interface | awk '{print $2}' | tr '\n' ' ')
if [ -n "$WIFI_IFACES" ]; then
  success "Interfaces détectées : $WIFI_IFACES"
else
  info "Aucune interface physique — chargement de mac80211_hwsim..."
  modprobe mac80211_hwsim radios=4 2>/dev/null && success "4 interfaces virtuelles créées" || \
    info "mac80211_hwsim non disponible sur ce noyau."
fi

# ── Forwarding IP ─────────────────────────────────────────────
info "Activation du forwarding IP..."
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || \
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
success "Forwarding IP activé"

# ── Permissions Wireshark ─────────────────────────────────────
usermod -aG wireshark "$SUDO_USER" 2>/dev/null || true

# ── Arborescence /opt/swfe837 ─────────────────────────────────
LABO_DIR="/opt/swfe837"
mkdir -p "$LABO_DIR"/{captures,certs,configs,freeradius,scripts}
chmod -R 755 "$LABO_DIR"
success "Arborescence $LABO_DIR créée"

# ── Copie des fichiers de config depuis le ZIP extrait ────────
info "Copie des fichiers de configuration..."
cp -f "$LABO_SRC/configs/"* "$LABO_DIR/configs/"
success "Configs copiés dans $LABO_DIR/configs/"

info "Copie des fichiers FreeRADIUS..."
cp -f "$LABO_SRC/freeradius/"* "$LABO_DIR/freeradius/"
success "Fichiers FreeRADIUS copiés dans $LABO_DIR/freeradius/"

# ── Génération des certificats TLS (TP2) ──────────────────────
info "Génération des certificats TLS pour TP2..."
CERT_DIR="$LABO_DIR/certs"
if [ ! -f "$CERT_DIR/ca.pem" ]; then
  # CA
  openssl genrsa -out "$CERT_DIR/ca.key" 2048 2>/dev/null
  openssl req -new -x509 -days 365 -key "$CERT_DIR/ca.key" \
    -out "$CERT_DIR/ca.pem" \
    -subj "/C=FR/ST=Paris/O=SWFE837-CA/CN=labo-ca" 2>/dev/null
  # Certificat serveur RADIUS
  openssl genrsa -out "$CERT_DIR/server.key" 2048 2>/dev/null
  openssl req -new -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -subj "/C=FR/ST=Paris/O=SWFE837/CN=radius.labo" 2>/dev/null
  openssl x509 -req -days 365 -in "$CERT_DIR/server.csr" \
    -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
    -out "$CERT_DIR/server.pem" 2>/dev/null
  # Certificat client
  openssl genrsa -out "$CERT_DIR/client.key" 2048 2>/dev/null
  openssl req -new -key "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client.csr" \
    -subj "/C=FR/ST=Paris/O=SWFE837/CN=etudiant1" 2>/dev/null
  openssl x509 -req -days 365 -in "$CERT_DIR/client.csr" \
    -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
    -out "$CERT_DIR/client.pem" 2>/dev/null
  # Paramètres DH pour FreeRADIUS
  openssl dhparam -out "$CERT_DIR/dh2048.pem" 2048 2>/dev/null
  chmod 640 "$CERT_DIR"/*.key "$CERT_DIR"/*.pem
  chown -R freerad:freerad "$CERT_DIR" 2>/dev/null || true
  success "Certificats et DH générés dans $CERT_DIR"
else
  success "Certificats déjà présents"
fi

mkdir -p /tmp/wpa_supplicant_labo
success "Répertoire de contrôle client créé"

# ── Marqueur ──────────────────────────────────────────────────
echo "SWFE837_LABO_OK_$(date +%Y%m%d)" > "$LABO_DIR/.labo_status"
success "Marqueur de labo créé"

echo ""
echo -e "${GREEN}╔══════════════════════════════════╗${NC}"
echo -e "${GREEN}║       INSTALLATION TERMINÉE      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════╝${NC}"
echo ""
echo "Lancez maintenant : sudo bash verif_labo.sh"
