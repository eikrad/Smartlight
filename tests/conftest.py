"""
Pytest fixtures for Smart Licht tests.
"""
import importlib.util
import json
import os
import sys
import tempfile
from unittest.mock import MagicMock

import pytest

# #region agent log
_logpath = "/home/eike_f/Smart_licht/.cursor/debug-96e8be.log"
try:
    _spec = importlib.util.find_spec("dirigera")
    with open(_logpath, "a") as _f:
        _f.write(
            json.dumps(
                {
                    "sessionId": "96e8be",
                    "hypothesisId": "H6",
                    "message": "conftest before import bridge",
                    "data": {
                        "executable": sys.executable,
                        "virtual_env": os.environ.get("VIRTUAL_ENV"),
                        "path_len": len(sys.path),
                        "path_sample": sys.path[:3] if len(sys.path) >= 3 else sys.path,
                        "dirigera_found": _spec is not None,
                    },
                    "timestamp": __import__("time").time_ns() // 1_000_000,
                }
            )
            + "\n"
        )
except Exception as _e:
    with open(_logpath, "a") as _f:
        _f.write(
            json.dumps(
                {
                    "sessionId": "96e8be",
                    "hypothesisId": "H1",
                    "message": "conftest log error",
                    "data": {"error": str(_e)},
                    "timestamp": __import__("time").time_ns() // 1_000_000,
                }
            )
            + "\n"
        )
# #endregion

# Import app and bridge module for patching
import bridge


@pytest.fixture
def temp_config_dir(tmp_path):
    """Use a temporary directory for config file during tests."""
    config_path = tmp_path / "config.json"
    return config_path


@pytest.fixture
def app_client(temp_config_dir, monkeypatch):
    """Flask test client with bridge module using temp config."""
    monkeypatch.setattr(bridge, "CONFIG_FILE", str(temp_config_dir))
    monkeypatch.setattr(bridge, "hub_interface", None)
    return bridge.app.test_client()


@pytest.fixture
def mock_light():
    """Create a mock light object as returned by dirigera."""
    light = MagicMock()
    light.id = "light-1"
    light.is_reachable = True
    light.room = MagicMock()
    light.room.id = "room-1"
    light.room.name = "Wohnzimmer"
    light.room.color = "white"
    light.room.icon = "room"
    light.attributes = MagicMock()
    light.attributes.is_on = True
    light.attributes.light_level = 80
    light.attributes.color_hue = None
    light.attributes.color_temperature = 4000
    return light


@pytest.fixture
def mock_light_offline():
    """Mock light that is unreachable (no power)."""
    light = MagicMock()
    light.id = "light-offline"
    light.is_reachable = False
    light.room = MagicMock()
    light.room.id = "room-2"
    light.room.name = "Gang oben"
    light.room.color = "white"
    light.room.icon = "room"
    light.attributes = MagicMock()
    light.attributes.is_on = True  # Hub still says on, but unreachable
    light.attributes.light_level = 50
    return light


@pytest.fixture
def mock_hub(mock_light, mock_light_offline):
    """Mock dirigera Hub that returns a list of lights."""
    hub = MagicMock()
    hub.get_lights.return_value = [mock_light, mock_light_offline]
    return hub


@pytest.fixture
def client_with_hub(app_client, mock_hub, mock_light, mock_light_offline, monkeypatch):
    """Flask test client with hub_interface set to mock hub."""
    monkeypatch.setattr(bridge, "hub_interface", mock_hub)
    default_lights = [mock_light, mock_light_offline]
    mock_hub.get_lights.return_value = default_lights
    yield app_client
    # Reset so other tests get default behaviour
    mock_hub.get_lights.return_value = default_lights


@pytest.fixture
def config_content():
    """Valid config JSON content."""
    return {"HUB_IP": "192.168.1.1", "HUB_TOKEN": "test-token-123"}
