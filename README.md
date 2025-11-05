# 🏁 ROX_SPEEDWAY – Custom Race Lobby System  
_Originally based on [KOA_ROX_SPEEDWAY by MaxSuperTech](https://github.com/MaxSuperTech/max_rox_speedway)_

🔥 Multiplayer race system with dynamic lobbies, countdown, laps & vehicle selection!

## 🇺🇸 ENGLISH

### Features
- For **qb-core** only  
- Uses **qb-target** only (no ox_target support)  
- **Notification system** supports **okokNotify**, **ox_lib**, or **rtx_notify**  
- **Auto-detects fuel system** (LegacyFuel, cdn-fuel, ox_fuel, okokGasStation, or lc_fuel)  
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
- **Optional “Raceway Leaderboard Display” integration by Glitchdetector** Link below in Notes

### Work In Progress
- **Driver position ranking system & HUD refinements**
- **Pit Crew** NPC animation refinements
- **Finish setting coords for remaining tracks**

### Notes

**For now only the short track is fully setup**
**Race Start Delay:**
You can now configure the race start countdown delay in `config/config.lua`:

```lua
Config.RaceStartDelay = 10 -- Default countdown is 10 seconds
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
- **Détection automatique du système de carburant** (LegacyFuel, cdn-fuel, ox_fuel, okokGasStation ou lc_fuel)  
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
- **Intégration optionnelle de “Raceway Leaderboard Display” par Glitchdetector** Lien ci-dessous dans Remarques

### En cours
- **Affichage du classement des pilotes & améliorations HUD**  
- Améliorations des animations des PNJ de l'équipe de stand
- **Finir de définir les coordonnées pour les autres circuits**

### Remarques

**Pour l’instant, seul le circuit court est entièrement configuré**
**Délai de départ de la course :**
Vous pouvez maintenant configurer le délai du compte à rebours dans `config/config.lua` :

```lua
Config.RaceStartDelay = 10 -- Le compte à rebours par défaut est de 10 secondes
```

Les joueurs préfèrent généralement 10 secondes ou moins. Ajustez selon vos besoins pour votre serveur.

- [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)

### AMIR Leaderboard (optionnel)

Si vous utilisez l’affichage Raceway Leaderboard de Glitchdetector, cette ressource peut le piloter en direct avec le même ordre que le HUD.

- Repo : [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)
- Activez dans `config/config.lua` via `Config.Leaderboard.enabled = true`
- Le titre affiche le tour du leader comme `2/3`

Extrait de configuration :

```lua
Config.Leaderboard = {
  enabled = true,
  updateIntervalMs = 1000,   -- cadence d’envoi ; plus bas peut provoquer du scintillement
  toggleIntervalMs = 2000,   -- fréquence de bascule Noms <-> Temps
  viewMode = "toggle",       -- "toggle" ou "names" ("times" seul non supporté)
  timeMode = "total",        -- comment les temps sont calculés : "total" ou "lap"
}
```

Modes :

- names : affiche toujours les noms des joueurs (stable, mises à jour minimales)
- toggle : alterne entre Noms et Temps toutes les `toggleIntervalMs`
  - Les lignes Temps gardent le même ordre que le HUD et sont en millisecondes (AMIR formate en MM:SS)
  - `timeMode` contrôle si les temps sont le total de la course ou le temps du tour actuel

Commande runtime (hôte/admin) :

- En chat : `/lb names` ou `/lb toggle`
- Depuis la console serveur : `lb names <LobbyName>` ou `lb toggle <LobbyName>`

Évitement du scintillement :

- Le serveur n’envoie les mises à jour AMIR que lors de changements de contenu (ordre/titre de tour) ou lors d’une bascule, ce qui évite le clignotement du tableau.

🛠️ Contributions & retours bienvenus !

---


## 🇩🇪 DEUTSCH

### Funktionen
- Nur für **qb-core**  
- Verwendet nur **qb-target** (keine ox_target-Unterstützung)  
- **Benachrichtigungssystem** unterstützt **okokNotify**, **ox_lib** oder **rtx_notify**  
- **Automatische Erkennung des Kraftstoffsystems** (LegacyFuel, cdn-fuel, ox_fuel, okokGasStation oder lc_fuel)  
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
- **Optionale Integration der “Raceway Leaderboard Display” von Glitchdetector** Link unten in Hinweise

### In Arbeit
- **Fahrerpositions-Ranking & HUD-Verbesserungen**  
- Verbesserungen der Animationen der Boxencrew-NPCs
- **Zielkoordinaten für verbleibende Strecken festlegen**

### Hinweise

**Derzeit ist nur die Kurzstrecke vollständig eingerichtet**
**Rennstart-Verzögerung:**
Das Start-Countdown-Delay kann jetzt in `config/config.lua` konfiguriert werden:

```lua
Config.RaceStartDelay = 10 -- Standard-Countdown ist 10 Sekunden
```

Spieler bevorzugen meist 10 Sekunden oder weniger. Passe dies nach Bedarf für deinen Server an.

- [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)

### AMIR Leaderboard (optional)

Wenn du Glitchdetectors Raceway Leaderboard Display verwendest, kann dieses Script das Board live im selben HUD-Order steuern.

- Repo: [AMIR Leaderboard](https://github.com/glitchdetector/amir-leaderboard)
- Aktivierung in `config/config.lua` via `Config.Leaderboard.enabled = true`
- Titel zeigt die Runde des Leaders wie `2/3`

Konfigurationsauszug:

```lua
Config.Leaderboard = {
  enabled = true,
  updateIntervalMs = 1000,   -- Push-Intervall; niedriger kann Flackern verursachen
  toggleIntervalMs = 2000,   -- Wie oft zwischen Namen <-> Zeiten gewechselt wird
  viewMode = "toggle",       -- "toggle" oder "names" ("times" allein nicht unterstützt)
  timeMode = "total",        -- wie die Zeiten berechnet werden: "total" oder "lap"
}
```

Modi:

- names: zeigt immer Spielernamen (stabil, minimale Updates)
- toggle: wechselt alle `toggleIntervalMs` zwischen Namen und Zeiten
  - Zeiten behalten die HUD-Reihenfolge und sind in Millisekunden (AMIR formatiert zu MM:SS)
  - `timeMode` steuert, ob die Zeiten die gesamte bisherige Rennzeit oder die aktuelle Rundenzeit sind

Laufzeit-Override (Host/Admin):

- Im Chat: `/lb names` oder `/lb toggle`
- Von der Serverkonsole: `lb names <LobbyName>` oder `lb toggle <LobbyName>`

Flackervermeidung:

- Der Server sendet AMIR-Updates nur bei tatsächlichen Inhaltsänderungen (Reihenfolge/Rundentitel) oder wenn der Toggle wechselt, um Flackern zu vermeiden.

🛠️ Beiträge & Feedback willkommen!

---