#!/usr/bin/env python3
"""
=================================================================
  SWFE837 – IDS Wi-Fi (TP4) – Script complet
  Mastère SIN Expert Cybersécurité – 2025-2026
  Détection : Désauthentification massive, Evil Twin, Probe Flood
=================================================================
Usage : sudo python3 ids_wifi.py -i wlan3mon [-t 5] [-v]
"""

import argparse
import time
import signal
import sys
from collections import defaultdict
from datetime import datetime

try:
    from scapy.all import (
        sniff, Dot11, Dot11Deauth, Dot11Disas,
        Dot11Beacon, Dot11ProbeReq, Dot11Elt, conf
    )
    from colorama import init, Fore, Style
    init(autoreset=True)
except ImportError as e:
    print(f"[ERREUR] Module manquant : {e}")
    print("→ Installez avec : pip3 install scapy colorama")
    sys.exit(1)

# ── Constantes ────────────────────────────────────────────────
DEAUTH_THRESHOLD   = 5    # Alertes si > N désauth en WINDOW secondes
PROBE_THRESHOLD    = 20   # Alertes si > N probes du même client
WINDOW_SECONDS     = 10   # Fenêtre de comptage

# ── État global ───────────────────────────────────────────────
stats = {
    "deauth":   0,
    "disassoc": 0,
    "beacons":  0,
    "probes":   0,
    "alerts":   0,
}

deauth_counter  = defaultdict(list)   # {src_mac: [timestamp, ...]}
probe_counter   = defaultdict(list)   # {src_mac: [timestamp, ...]}
seen_ssids      = {}                  # {ssid: bssid}
alert_log       = []

args_global = None

# ── Fonctions utilitaires ─────────────────────────────────────

def ts():
    return datetime.now().strftime("%H:%M:%S")

def alert(level, message):
    """Affiche et enregistre une alerte."""
    color = Fore.RED if level == "CRITIQUE" else Fore.YELLOW
    line = f"[{ts()}] [{level}] {message}"
    print(color + Style.BRIGHT + line)
    alert_log.append(line)
    stats["alerts"] += 1

def info(message):
    if args_global and args_global.verbose:
        print(Fore.CYAN + f"[{ts()}] [INFO] {message}")

# ── Handlers de paquets ───────────────────────────────────────

def handle_deauth(pkt):
    """Détecte les attaques par désauthentification massive."""
    src = pkt.addr2 or "??:??:??:??:??:??"
    dst = pkt.addr1 or "ff:ff:ff:ff:ff:ff"
    reason = pkt[Dot11Deauth].reason if pkt.haslayer(Dot11Deauth) else (pkt[Dot11Disas].reason if pkt.haslayer(Dot11Disas) else "?")
    now = time.time()

    deauth_counter[src].append(now)
    # Purge de la fenêtre
    deauth_counter[src] = [t for t in deauth_counter[src] if now - t < WINDOW_SECONDS]

    count = len(deauth_counter[src])
    info(f"Désauth {src} → {dst} | raison={reason} | compteur={count}")

    if count == DEAUTH_THRESHOLD:
        alert("CRITIQUE",
              f"DEAUTH FLOOD : {src} → {dst} ({count} en {WINDOW_SECONDS}s) "
              f"| Raison : {reason} | Possible attaque aireplay-ng !")

    stats["deauth"] += 1


def handle_beacon(pkt):
    """Détecte un Evil Twin (même SSID, BSSID différent)."""
    if not pkt.haslayer(Dot11Elt):
        return
    bssid = pkt.addr3 or "?"
    try:
        ssid = pkt[Dot11Elt].info.decode("utf-8", errors="replace")
    except Exception:
        return

    if not ssid:
        return

    stats["beacons"] += 1

    if ssid in seen_ssids:
        if seen_ssids[ssid] != bssid:
            alert("CRITIQUE",
                  f"EVIL TWIN détecté ! SSID='{ssid}' | "
                  f"AP légitime={seen_ssids[ssid]} | "
                  f"Rogue AP={bssid}")
    else:
        seen_ssids[ssid] = bssid
        info(f"Nouveau AP : SSID='{ssid}' BSSID={bssid}")


def handle_probe(pkt):
    """Détecte un probe flood (scan intensif d'un client)."""
    src = pkt.addr2 or "??:??:??:??:??:??"
    now = time.time()

    probe_counter[src].append(now)
    probe_counter[src] = [t for t in probe_counter[src] if now - t < WINDOW_SECONDS]
    count = len(probe_counter[src])

    if count == PROBE_THRESHOLD:
        alert("AVERTISSEMENT",
              f"PROBE FLOOD : {src} a envoyé {count} probes en {WINDOW_SECONDS}s "
              f"(scan de réseaux agressif)")
    stats["probes"] += 1


def packet_handler(pkt):
    """Dispatcher principal."""
    if not pkt.haslayer(Dot11):
        return
    if pkt.haslayer(Dot11Deauth) or pkt.haslayer(Dot11Disas):
        handle_deauth(pkt)
    elif pkt.haslayer(Dot11Beacon):
        handle_beacon(pkt)
    elif pkt.haslayer(Dot11ProbeReq):
        handle_probe(pkt)


# ── Rapport final ─────────────────────────────────────────────

def print_report(signum=None, frame=None):
    print("\n")
    print(Fore.BLUE + Style.BRIGHT + "═" * 55)
    print(Fore.BLUE + Style.BRIGHT + "  SWFE837 IDS – Rapport de session")
    print(Fore.BLUE + Style.BRIGHT + "═" * 55)
    print(f"  Trames désauth/disassoc captées : {stats['deauth']}")
    print(f"  Trames beacon captées           : {stats['beacons']}")
    print(f"  Probe requests captées          : {stats['probes']}")
    print(f"  Total alertes générées          : {stats['alerts']}")
    print()
    if alert_log:
        print(Fore.RED + Style.BRIGHT + "  ── Journal des alertes ──────────────")
        for line in alert_log:
            print("  " + line)
    else:
        print(Fore.GREEN + "  Aucune alerte – Trafic normal.")
    print(Fore.BLUE + Style.BRIGHT + "═" * 55)
    sys.exit(0)


# ── Point d'entrée ────────────────────────────────────────────

def main():
    global args_global
    parser = argparse.ArgumentParser(
        description="SWFE837 – IDS Wi-Fi (TP4)")
    parser.add_argument("-i", "--iface",   required=True,
                        help="Interface en mode monitor (ex: wlan3mon)")
    parser.add_argument("-t", "--timeout", type=int, default=0,
                        help="Durée de capture en secondes (0 = infini)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Mode verbeux (affiche tous les paquets)")
    args = parser.parse_args()
    args_global = args

    signal.signal(signal.SIGINT, print_report)

    print(Fore.GREEN + Style.BRIGHT + """
  ╔══════════════════════════════════════════════╗
  ║  SWFE837 – IDS Wi-Fi  |  TP4 Cybersécurité  ║
  ╚══════════════════════════════════════════════╝""")
    print(f"  Interface : {args.iface}")
    print(f"  Seuil désauth : {DEAUTH_THRESHOLD} en {WINDOW_SECONDS}s")
    print(f"  Durée : {'∞' if args.timeout == 0 else str(args.timeout) + 's'}")
    print("  Ctrl+C pour arrêter et afficher le rapport\n")

    conf.iface = args.iface
    sniff(
        iface=args.iface,
        prn=packet_handler,
        store=False,
        timeout=args.timeout if args.timeout > 0 else None
    )

    print_report()


if __name__ == "__main__":
    main()