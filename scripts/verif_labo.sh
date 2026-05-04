#!/bin/bash
# ============================================================
#  SWFE837 – Script de vérification du laboratoire Wi-Fi
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0

check() {
  local label="$1"; local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo -e "  ${GREEN}✔${NC} $label"
    ((PASS++))
  else
    echo -e "  ${RED}✘${NC} $label"
    ((FAIL++))
  fi
}

echo ""
echo -e "${BLUE}${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}   SWFE837 – Vérification du laboratoire  ${NC}"
echo -e "${BLUE}${BOLD}══════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}[1] Outils réseau Wi-Fi${NC}"
check "airodump-ng"     "command -v airodump-ng"
check "aireplay-ng"     "command -v aireplay-ng"
check "aircrack-ng"     "command -v aircrack-ng"
check "iw"             "command -v iw"

echo ""
echo -e "${BOLD}[2] Outils d'attaque / analyse${NC}"
check "hashcat"         "command -v hashcat"
check "tcpdump"         "command -v tcpdump"
check "wireshark"       "command -v wireshark"

echo ""
echo -e "${BOLD}[3] Outils de service${NC}"
check "hostapd"         "command -v hostapd"
check "freeradius"      "command -v freeradius || command -v radiusd"
check "radtest"         "command -v radtest"
check "dnsmasq"         "command -v dnsmasq"

echo ""
echo -e "${BOLD}[4] Python / Scapy${NC}"
check "python3"         "command -v python3"
check "scapy (module)"  "python3 -c 'import scapy'"
check "colorama"        "python3 -c 'import colorama'"

echo ""
echo -e "${BOLD}[5] Certificats TLS (TP2)${NC}"
check "ca.pem"          "test -f /opt/swfe837/certs/ca.pem"
check "server.pem"      "test -f /opt/swfe837/certs/server.pem"
check "client.pem"      "test -f /opt/swfe837/certs/client.pem"

echo ""
echo -e "${BOLD}[6] Wordlist${NC}"
check "rockyou_small"   "test -f /opt/wordlists/rockyou_small.txt"

echo ""
echo -e "${BOLD}[7] Marqueur d'installation${NC}"
check "Marqueur labo"   "grep -q SWFE837_LABO_OK /opt/swfe837/.labo_status 2>/dev/null"

echo ""
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║          ✔  LABO OK  ✔           ║${NC}"
  echo -e "${GREEN}${BOLD}║  $PASS/$TOTAL vérifications réussies    ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════╝${NC}"
else
  echo -e "${RED}${BOLD}╔══════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║        ✘  LABO INCOMPLET         ║${NC}"
  echo -e "${RED}${BOLD}║  $PASS/$TOTAL OK – $FAIL erreur(s) détectée(s)   ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}→ Relancez install_labo.sh pour corriger les erreurs.${NC}"
fi
echo ""
