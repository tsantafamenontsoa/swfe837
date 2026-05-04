# SWFE837 – Sécurité Wi-Fi · Pack complet
## Mastère SIN Expert Cybersécurité · 2025-2026

---

## Démarrage rapide

```bash
# 1. Importer la VM Kali (VirtualBox)
#    → Fichier → Importer un appareil virtuel → Kali_SecWifi_Labo.ova

# 2. Installation du laboratoire (dans la VM)
cd swfe837/
sudo bash scripts/install_labo.sh

# 3. Vérification — doit afficher LABO OK
sudo bash scripts/verif_labo.sh

# 4. Snapshot VirtualBox avant chaque TP
#    → Machine → Créer un instantané → "Avant_TP1"

# 5. Entre deux TP : réinitialisation propre
sudo bash scripts/reset_labo.sh
```

---

## Arborescence

```
swfe837/
│
├── tp_securite_wifi.html           ← Document étudiant (ouvrir dans un navigateur)
├── guide_formateur.html            ← Guide formateur - NE PAS distribuer aux étudiants
├── README.md                       ← Ce fichier
│
├── scripts/
│   ├── install_labo.sh             ← Installation complète du labo (outils, certs, wordlist)
│   ├── verif_labo.sh               ← Vérification de l'installation (23 checks)
│   ├── reset_labo.sh               ← Réinitialisation entre deux TP
│   └── ids_wifi.py                 ← Script IDS Wi-Fi Python/Scapy (TP4)
│
├── configs/
│   ├── hostapd-wpa3-enterprise.conf    ← Config AP WPA3-Enterprise EAP-TLS (TP2)
│   ├── hostapd-evil-twin.conf          ← Config Rogue AP open (TP3)
│   ├── dnsmasq-evil-twin.conf          ← DHCP/DNS pour le Rogue AP (TP3)
│   └── wpa_supplicant-eaptls.conf      ← Config client EAP-TLS (TP2)
│
├── freeradius/
│   ├── clients.conf                ← Déclaration des NAS autorisés (TP2)
│   ├── eap.conf                    ← Configuration EAP-TLS FreeRADIUS (TP2)
│   └── users                       ← Base d'utilisateurs de test (TP2)
│
└── correction/
    └── corrige_tp.html             ← Corrigé complet + grille ECSI 3.4/3.5
                                       ⚠ RÉSERVÉ AU FORMATEUR
```

---

## Contenus par TP

| TP | Titre | Durée | Fichiers clés |
|----|-------|-------|---------------|
| S0 | Mise en place du labo | 1h30 | `install_labo.sh`, `verif_labo.sh` |
| TP1 | Force brute WPA2 | 2h | `aircrack-ng`, `hashcat` (intégrés à Kali) |
| TP2 | WPA3-Enterprise / EAP-TLS | 2h30 | `hostapd-wpa3-enterprise.conf`, `freeradius/`, `wpa_supplicant-eaptls.conf` |
| TP3 | Evil Twin & durcissement | 3h | `hostapd-evil-twin.conf`, `dnsmasq-evil-twin.conf` |
| TP4 | IDS Wi-Fi (Scapy) | 2h | `ids_wifi.py` |

---

## Compétences ECSI visées

- **ECSI 3.4** – Auditer la sécurité d'un réseau Wi-Fi (TP1, TP2, TP3)
- **ECSI 3.5** – Proposer et implémenter des contre-mesures (TP2, TP3, TP4)

---

> ⚠ Tous les fichiers de ce dossier sont destinés à un usage pédagogique exclusivement,
> dans un environnement réseau isolé. Toute utilisation en dehors de ce cadre
> est illégale (Code pénal art. 323, RSSI).
