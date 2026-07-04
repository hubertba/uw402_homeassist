# UW402 Home Assistant Configuration

Dieses Repository verwaltet die Home-Assistant-Konfiguration der UW402-Installation.
Die produktive Instanz laeuft auf Home Assistant OS in einer Synology-VM; Deployments
erfolgen per SSH auf den Host-Alias `ha`.

## Inhalt

| Pfad | Zweck |
| --- | --- |
| `configuration.yaml` | Hauptkonfiguration mit REST- und Template-Sensoren |
| `dashboards/` | versionierte Lovelace-Dashboards |
| `automations.yaml` | Home-Assistant-Automationen |
| `scripts.yaml` | Home-Assistant-Scripts |
| `scenes.yaml` | Home-Assistant-Szenen |
| `knx.yaml` | aktive KNX-Konfiguration |
| `homeassistant/` | vorbereitete Package-YAMLs fuer Marstek/Venus-Sensoren |
| `blueprints/` | lokale Home-Assistant-Blueprints |
| `custom_components/` | lokal verwaltete Custom Components |
| `shell_commands/` | Generator-Scripte fuer lokale HTML-Galerien |
| `scripts/deploy.sh` | Deployment-Script fuer Sync, Config-Check und Neustart |
| `secrets.example.yaml` | Vorlage fuer benoetigte Secret-Keys |

## Aktive Konfiguration

Die Hauptkonfiguration nutzt `default_config` und bindet die Standarddateien
`automations.yaml`, `scripts.yaml` und `scenes.yaml` ein.

Aktiv ist ausserdem ein REST-Sensor fuer den Ecotracker:

- Endpoint: `http://10.0.1.150/v1/json`
- Scan-Intervall: 5 Sekunden
- Attribute: `power`, `energyCounterIn`, `energyCounterOut`

Darauf bauen mehrere Template-Sensoren auf:

| Sensor | Zweck |
| --- | --- |
| `sensor.quooker_total_energy_combined` | addiert die Energie beider Quooker-Geraete |
| `sensor.quooker_combined_power` | addiert die aktuelle Leistung beider Quooker-Geraete |
| `sensor.ecotracker_aktueller_verbrauch` | aktuelle Ecotracker-Leistung in Watt |
| `sensor.ecotracker_bezug` | Netzbezug aus `energyCounterIn` in kWh |
| `sensor.ecotracker_einspeisung` | Einspeisung aus `energyCounterOut` in kWh |
| `sensor.ecotracker_grid_power` | Ecotracker-Verbrauch minus Fronius/PV-Leistung |
| `sensor.hausverbrauch_aktuell` | aktueller Hausverbrauch aus PV, signed Netzleistung und Batteriefluss |
| `sensor.pumpmeup_charging_power` | berechnete Ladeleistung aus Strom, Spannung und Phasen |
| `sensor.internet_download_mbps` | aktueller Internet-Download aus dem UniFi/UWC-Durchsatz |
| `sensor.internet_upload_mbps` | aktueller Internet-Upload aus dem UniFi/UWC-Durchsatz |
| `sensor.internet_durchsatz_gesamt_mbps` | Summe aus aktuellem Download und Upload |

Der Hausverbrauch wird aktuell so berechnet:

```jinja
{% set pv = states('sensor.symo_8_2_3_m_1_ac_power') | float(0) %}
{% set grid = states('sensor.ecotracker_aktueller_verbrauch') | float(0) %}
{% set battery_out = states('sensor.marstek_venuse_3_0_power_out') | float(0) %}
{% set battery_in = states('sensor.marstek_venuse_3_0_power_in') | float(0) %}
{{ [0, (pv + grid + battery_out - battery_in)] | max | round(0) }}
```

## Dashboards

Die Dashboards sind als YAML-Dashboards versioniert:

```yaml
lovelace:
  dashboards:
    energy-flow:
      mode: yaml
      title: Energie
      icon: mdi:home-lightning-bolt
      show_in_sidebar: true
      filename: dashboards/energy.yaml
    energy-flo:
      mode: yaml
      title: EnergieFluss
      icon: mdi:chart-areaspline
      show_in_sidebar: true
      filename: dashboards/energy-flo.yaml
    camera-feeds:
      mode: yaml
      title: Kameras
      icon: mdi:cctv
      show_in_sidebar: true
      filename: dashboards/cameras.yaml
    internet-bandwidth:
      mode: yaml
      title: Internet
      icon: mdi:speedometer
      show_in_sidebar: true
      filename: dashboards/internet.yaml
```

`dashboards/energy.yaml` enthaelt zwei Views:

- `Energie`: Hausverbrauch, PV, Netzleistung, Batterie, Quooker und PumpMeUp
- `Diagnose`: Marstek/Venus-Status, CT-Werte, WLAN und Betriebsmodus

`dashboards/energy-flo.yaml` ist aus dem vorhandenen UI-Dashboard
`lovelace.energy_flo` aus `.storage` exportiert und als YAML umgewandelt.

`dashboards/cameras.yaml` enthaelt die Kamera-Ansichten:

- `Kameras`: DoorBird-Livefeed, DoorBird-Snapshots, Reolink-Snapshots und Driveway-Status
- `Bewegungsbilder`: HTML-Galerie der lokal gespeicherten Reolink-Snapshots
- `Videos`: HTML-Galerie der Reolink-Videos vom Synology-Share

`dashboards/internet.yaml` zeigt den aktuellen Internet-Durchsatz:

- Download, Upload und Gesamt-Durchsatz als Gauges
- aktuelle Rohwerte `sensor.uwc_download_throughput` und `sensor.uwc_upload_throughput`
- Verlauf fuer 60 Minuten, 24 Stunden und 7 Tage

## Reolink / Kameras

Die Reolink-Driveway-Kamera ist eine batteriebetriebene Argus PT Ultra. Direkt
in Home Assistant liefert sie zwar Status-, AI- und Snapshot-Entitaeten, aber
keinen stabilen Livestream wie eine PoE-/ONVIF-Kamera.

Aktive Snapshot-Entitaeten:

- `camera.driveway_snapshots_fluent`
- `camera.driveway_snapshots_clear`

Die Automation `reolink_driveway_motion_snapshot` reagiert auf:

- `binary_sensor.driveway_motion`
- `binary_sensor.driveway_person`
- `binary_sensor.driveway_vehicle`

Sie speichert bei Erkennung ein Bild nach:

```text
/config/www/snapshots/driveway_<typ>_YYYYMMDD_HHMMSS.jpg
```

Die Automation laeuft nur, wenn:

- `sensor.driveway_battery` groesser als 20 Prozent ist
- `switch.driveway_privacy_mode` aus ist

Nach dem Snapshot wird `shell_command.generate_snapshot_gallery` ausgefuehrt.
Das Script `shell_commands/generate_snapshot_gallery.sh` erzeugt:

```text
/config/www/snapshots/index.html
```

Die Galerie ist im Dashboard unter `/camera-feeds/snapshots` eingebettet und
behaelt maximal 200 Bilder bzw. Bilder der letzten 14 Tage.

## Reolink-Videos auf Synology

Reolink speichert Videos per FTP auf die Synology. Der SMB-Share ist auf dem
Home-Assistant-Host read-only eingebunden:

```text
//10.0.1.70/video -> /homeassistant/www/reolink-videos
```

Der Mount ist Host-Konfiguration und wird nicht im Git-Repo verwaltet. Die
Zugangsdaten liegen auf dem Home-Assistant-Host; echte Passwoerter werden im
README nicht dokumentiert.

Das Script `shell_commands/generate_reolink_video_gallery.sh` liest den
gemounteten Share und erzeugt:

```text
/config/www/reolink-video-gallery/index.html
```

Unterstuetzte Video-Endungen:

- `.mp4`
- `.avi`
- `.mov`
- `.mkv`
- `.m4v`
- `.webm`
- `.ts`

Die Automation `reolink_video_gallery_refresh` aktualisiert die Videogalerie
alle 5 Minuten. Im Kamera-Dashboard ist sie unter `/camera-feeds/videos`
eingebettet.

## Marstek / Venus

Die Integration `custom_components/marstek_local_api` ist lokal im Repository
enthalten. Sie stammt aus `jaapp/ha-marstek-local-api` und stellt Sensoren fuer
Marstek Venus E bereit.

Im Ordner `homeassistant/` liegen zusaetzliche Package-Vorlagen:

- `marstek_venus_power_flow.yaml`
- `marstek_venus_battery_energy.yaml`

Diese Dateien sind derzeit als Vorlage kommentiert. In `configuration.yaml` ist
auch die Package-Einbindung noch auskommentiert:

```yaml
#homeassistant:
#  packages: !include_dir_named homeassistant/
```

Zum Aktivieren muessen die benoetigten Blöcke einkommentiert und die Entity-IDs
gegen die produktiven Sensoren in Home Assistant geprueft werden.

## Custom Components

Dieses Repo verwaltet aktuell zwei lokale Custom Components:

- `custom_components/marstek_local_api`
- `custom_components/codex_cli`

HACS selbst wird absichtlich nicht versioniert. Es kann auf der Home-Assistant-
Instanz wieder installiert bzw. aktualisiert werden und erzeugt sehr viele
Frontend-Dateien.

## Deployment

Vor einem Deployment kann ein Dry-Run ausgefuehrt werden:

```bash
scripts/deploy.sh --dry-run
```

Das eigentliche Deployment:

```bash
scripts/deploy.sh
```

Das Script macht:

1. `rsync` der lokalen Konfiguration nach `ha:/homeassistant/`
2. `ha core check`
3. `ha core restart`

Optionen:

```bash
scripts/deploy.sh --no-check
scripts/deploy.sh --no-restart
REMOTE=ha REMOTE_DIR=/homeassistant scripts/deploy.sh
```

Beim Sync werden Runtime-Daten, echte Secrets, Datenbanken, Logs, HACS-Bundles,
Python-Caches und dieses Git-Repo ausgeschlossen.

## Secrets und Runtime-Daten

`secrets.yaml` wird nicht versioniert. Neue benoetigte Keys sollten in
`secrets.example.yaml` dokumentiert werden, ohne echte Werte zu committen.

Ausgeschlossen sind ausserdem:

- `.storage/`
- Recorder-Datenbanken `home-assistant_v2.db*`
- Logs
- `.cache/`, `.cloud/`, `deps/`, `tts/`
- HACS-Frontend-Dateien

## Git-Workflow

Typischer Ablauf:

```bash
git status
git add .
git commit -m "Describe change"
git push
scripts/deploy.sh
```

Nach Aenderungen an Template-Sensoren reicht in vielen Faellen auch ein Reload
der Template-Entitaeten in Home Assistant. Das Deploy-Script startet Home
Assistant bewusst neu, damit auch strukturelle YAML-Aenderungen sicher geladen
werden.
