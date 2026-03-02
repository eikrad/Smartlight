# Smart Licht

A local bridge and Garmin watch app for controlling **IKEA Dirigera** smart lights by room. Use the bridge to talk to your Dirigera Hub over the network, and optionally control lights from a Garmin watch (e.g. FR965, Fenix 7, Venu 2, Epix 2) via the companion app.

## What it does

- **Bridge server** – Flask REST API that connects to your IKEA Dirigera Hub and exposes room-based control (rooms, toggle, brightness, color, color temperature).
- **Room-based control** – Lights are grouped by the room names you set in the IKEA Home smart app; the API works with these rooms.
- **Garmin watch app** – Connect IQ app that talks to the bridge over your local network so you can switch rooms on/off, change brightness, and set color or color temperature from your wrist.

## Project structure

| Path | Description |
|------|-------------|
| `bridge.py` | Main bridge server: connects to Dirigera, serves HTTPS API on port 8080. |
| `scan.py` | Scans your local subnet for a Dirigera Hub (port 8443) to find its IP. |
| `debug_hub.py` | Small script to inspect hub connection and light objects (uses `config.json`). |
| `config.json` | Stores `HUB_IP` and `HUB_TOKEN` (created by bridge setup). **Do not commit real tokens.** |
| `SmartLightApp/` | Garmin Connect IQ watch app source (Monkey C). |

## Requirements

- Python 3
- IKEA Dirigera Hub and compatible smart lights, configured in the IKEA Home smart app (including room names)
- For the watch app: a supported Garmin device and Connect IQ SDK

### Python dependencies

- `dirigera` – IKEA Dirigera Hub API
- `flask` – HTTP server for the bridge

Install with:

```bash
pip install dirigera flask
```

For running tests:

```bash
pip install -r requirements-test.txt
```

## Setup

### 1. Find your Dirigera Hub (optional)

If you don’t know the hub’s IP, run the scanner (edit `SUBNET` in `scan.py` to match your network, e.g. `172.17.112`):

```bash
python scan.py
```

Use one of the printed IPs in the next step.

### 2. Configure the bridge

Run the interactive setup. You’ll need to press the **action button** on the bottom of the Dirigera Hub when prompted:

```bash
python bridge.py setup
```

This will ask for the hub IP, complete the OAuth-style flow, and write `HUB_IP` and `HUB_TOKEN` to `config.json`. (If you cloned the repo, you can use `config.example.json` as a reference; the real `config.json` is gitignored.)

### 3. Run the bridge

Start the HTTPS server (uses `cert.pem` and `key.pem` in the project directory):

```bash
python bridge.py
```

The server listens on **port 8080** (HTTPS). Endpoints:

- `GET /rooms` – List rooms with state (on/off, brightness, capabilities, etc.)
- `POST /rooms/<room_id>/toggle` – Toggle the room on or off
- `POST /rooms/<room_id>/brightness` – Body: `{"level": 0-100}`
- `POST /rooms/<room_id>/color` – Body: `{"hue": ..., "saturation": ...}`
- `POST /rooms/<room_id>/temperature` – Body: `{"temperature": ...}` (color temperature in Kelvin)

### 4. Garmin watch app (optional)

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and build/load the app from `SmartLightApp/` for your device.
2. In the app settings on the watch (or in the SDK simulator), set **bridge IP**, **port** (e.g. 8080), and whether to use **HTTPS** so the watch can reach your bridge on the same network.

Then you can open the app on the watch to see rooms, toggle lights, and adjust brightness/color/temperature.

## Testing

From the project root:

```bash
pytest
# or with coverage:
pytest --cov=bridge --cov=scan
```

## Security note



## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0). See the [LICENSE](LICENSE) file for the full text.
