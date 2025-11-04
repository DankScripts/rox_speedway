# 🏁 ROX_SPEEDWAY – Custom Race Lobby System  
_Originally based on [KOA_ROX_SPEEDWAY by MaxSuperTech](https://github.com/MaxSuperTech/max_rox_speedway)_

🔥 Multiplayer race system with dynamic lobbies, countdown, laps & vehicle selection!

## 🇺🇸 ENGLISH

### Features
- For **qb-core** only  
- Uses **qb-target** only (no ox_target support)  
- **Notification system** supports **okokNotify**, **ox_lib**, or **rtx_notify**  
- **Auto-detects fuel system** (LegacyFuel, cdn-fuel, ox_fuel, or okokGasStation)  
- **Checkpoint spheres** & **poly-zone finish line** for anti-cheat and lap detection  
- **Driver position HUD**, live on-the-fly ranking  
- Create / join custom lobbies  
- Track type & number of laps selection  
- Vehicle selection per player  
- Countdown with sound and GTA-style scaleform  
- Lap tracking system  
- Finish ranking screen with times  
- Lobby management (start, leave, close)  
- Full client-server flow (race lifecycle)  
- Clean separation with ox_lib, localized texts  

### Work In Progress
- **Driver position ranking system & HUD refinements**  
- **Optional “Raceway Leaderboard Display”** integration by Glitchdetector  

### Notes

- [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)

**Race Start Delay:**
You can now configure the race start countdown delay in `config/config.lua`:

```lua
Config.RaceStartDelay = 3 -- Default is 3 seconds for testing, set up to 10 for longer countdown
```

Players generally prefer 10 seconds or less. Adjust as needed for your server.

### AMIR Leaderboard (optional)

If you use Glitchdetector's Raceway Leaderboard Display, this resource can drive it live with the same order as the HUD.

- Repo: [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)
- Enable in `config/config.lua` via `Config.Leaderboard.enabled = true`
- Title shows leader's lap like `2/3`

Config section (excerpt):

```lua
Config.Leaderboard = {
  enabled = true,
  updateIntervalMs = 1000,   -- push cadence; lower can cause flicker
  toggleIntervalMs = 2000,   -- how often to flip Names <-> Times
  viewMode = "toggle",       -- "toggle" or "names" ("times" is not supported alone)
  timeMode = "total",        -- how Times are computed when shown: "total" or "lap"
}
```

Modes:

- names: always shows player names (stable, minimal updates)
- toggle: flips between Names and Times every `toggleIntervalMs`
  - Times lines keep the same order as the HUD and are in milliseconds (AMIR formats to MM:SS)
  - `timeMode` controls whether Times are total race time so far or current lap time

Runtime override (host/admin):

- In chat: `/lb names` or `/lb toggle`
- From server console: `lb names <LobbyName>` or `lb toggle <LobbyName>`

Flicker avoidance:

- The server only sends AMIR updates on actual content changes (order/lap title) or when the toggle flips, which prevents the board from flashing.

🛠️ Contributions & feedback welcome!

---

## 🇫🇷 FRANÇAIS

### Fonctionnalités
- Pour **qb-core** uniquement  
- Utilise exclusivement **qb-target** (pas de support ox_target)  
- **Système de notifications** compatible **okokNotify**, **ox_lib** ou **rtx_notify**  
- **Détection automatique du système de carburant** (LegacyFuel, cdn-fuel, ox_fuel ou okokGasStation)  
- **Sphères de checkpoints** & **zone poly** pour la ligne d’arrivée  
- **HUD de position des pilotes**, classement en temps réel  
- Création / rejoindre de lobbies personnalisés  
- Sélection du type de circuit et du nombre de tours  
- Sélection du véhicule par joueur  
- Compte à rebours avec son et scaleform style GTA  
- Suivi des tours  
- Écran de classement final avec temps  
- Gestion des lobbies (démarrer, quitter, fermer)  
- Flux complet client-serveur (cycle de vie de la course)  
- Texte localisé avec ox_lib  

### En cours
- **Affichage du classement en direct** (HUD position pilote)  
- Intégration optionnelle de **“Raceway Leaderboard Display”** par Glitchdetector  

### Remarques
- Une partie du code est originale ; d’importantes portions ont été remplacées ou réécrites par DrCannabis  
- Config en cours de développement  
- Props pour barrières & obstacles partiellement placés pour "Short_Track" & "Drift_Track"  
- Personnalisez circuit et **checkpoints** dans `config.lua`  
- Prise en charge des déclencheurs de ligne d’arrivée en **sphère** et **poly-zone**  
- **Leaderboard** à activer uniquement si vous disposez du prop nécessaire  
  - https://github.com/glitchdetector/amir-leaderboard  

🛠️ Contributions & retours bienvenus !

---

## 🇩🇪 DEUTSCH

### Funktionen
- Nur für **qb-core**  
- Verwendet nur **qb-target** (keine ox_target-Unterstützung)  
- **Benachrichtigungssystem** unterstützt **okokNotify**, **ox_lib** oder **rtx_notify**  
- **Automatische Erkennung des Kraftstoffsystems** (LegacyFuel, cdn-fuel, ox_fuel oder okokGasStation)  
- **Checkpoint-Sphären** & **Poly-Zone** für Ziellinie/Anti-Cheat  
- **Fahrerpositions-HUD** in Echtzeit  
- Erstellen / Beitreten von benutzerdefinierten Lobbys  
- Auswahl von Streckentyp & Rundenzahl  
- Fahrzeugwahl pro Spieler  
- Countdown mit Sound und GTA-Style-Scaleform  
- Rundentracking  
- Endplatzierungs-Bildschirm mit Zeiten  
- Lobby-Verwaltung (Start, Verlassen, Schließen)  
- Vollständiger Client-Server-Ablauf (Race Lifecycle)  
- Saubere Trennung mit ox_lib, lokalisierte Texte  

### In Arbeit
- **Live Fahrerpositions-Anzeige & Feinabstimmung**  
- Optionale **“Raceway Leaderboard Display”** Integration von Glitchdetector  

### Hinweise
- Ein Teil des Codes ist original; wesentliche Teile wurden von DrCannabis ersetzt oder neu geschrieben  
- Konfiguration noch in Arbeit  
- Props (Streckenbarrieren, Hindernisse) nur für „Short_Track“ & „Drift_Track“ teilweise platziert  
- Passen Sie Streckenlayout und **Checkpoints** in `config.lua` an  
- Unterstützt **Sphere** und **Poly-Zone** als Ziellinien-Trigger  
- **Leaderboard** nur aktivieren, wenn das benötigte Prop vorhanden ist  
  - https://github.com/glitchdetector/amir-leaderboard  

🛠️ Beiträge & Feedback willkommen!

---

# rox_speedway
# UltimateTransit
