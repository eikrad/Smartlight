#!/bin/bash
# Führt alle Projekt-Checks aus: Python (pytest) + Garmin Watch-App (Kompilierung).
# Usage: ./run_tests.sh   oder   bash run_tests.sh

set -e
cd "$(dirname "$0")"
FAILED=0

echo "========== 1. Python-Tests (pytest) =========="
if [ -d "venv" ]; then
    source venv/bin/activate
fi
if python -m pytest tests/ -v; then
    echo "[OK] Python-Tests bestanden."
else
    echo "[FEHLER] Python-Tests fehlgeschlagen."
    FAILED=1
fi

echo ""
echo "========== 2. Garmin Watch-App (Kompilierung) =========="
SDK_HOME=$(find ~/.Garmin/ConnectIQ/Sdks/ -name "connectiq-sdk-lin-*" -type d 2>/dev/null | sort -r | head -n 1)
if [ -z "$SDK_HOME" ]; then
    echo "[ÜBERSPRUNGEN] Connect IQ SDK nicht gefunden – nur Python getestet."
elif [ ! -f "SmartLightApp/developer_key.der" ]; then
    echo "[ÜBERSPRUNGEN] developer_key.der fehlt in SmartLightApp/ – nur Python getestet."
else
    BIN="$SDK_HOME/bin"
    DEVICE="fenix7"
    (cd SmartLightApp && mkdir -p bin && "$BIN/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/SmartLightApp.prg -y developer_key.der) && echo "[OK] Watch-App kompiliert." || { echo "[FEHLER] Watch-App-Kompilierung fehlgeschlagen."; FAILED=1; }

    echo ""
    echo "========== 3. Garmin Unit-Tests (Build mit -t) =========="
    (cd SmartLightApp && "$BIN/monkeyc" -t -d "$DEVICE" -f monkey.jungle -o bin/SmartLightApp-test.prg -y developer_key.der) && echo "[OK] Test-Build kompiliert (Unit-Tests eingebunden)." || { echo "[FEHLER] Test-Build fehlgeschlagen."; FAILED=1; }
    echo "    (Tests ausführen: Simulator starten, dann: monkeydo bin/SmartLightApp-test.prg $DEVICE /t)"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo "========== Alle Checks bestanden. =========="
    exit 0
else
    echo "========== Mindestens ein Check fehlgeschlagen. =========="
    exit 1
fi
