"""
Tests for bridge.py (Flask API and config helpers).
"""
import json
import pytest

import bridge


class TestLoadConfig:
    """Tests for load_config()."""

    def test_load_config_missing_file(self, temp_config_dir, monkeypatch):
        monkeypatch.setattr(bridge, "CONFIG_FILE", str(temp_config_dir))
        assert not temp_config_dir.exists()
        assert bridge.load_config() is None

    def test_load_config_valid_file(self, temp_config_dir, monkeypatch, config_content):
        monkeypatch.setattr(bridge, "CONFIG_FILE", str(temp_config_dir))
        temp_config_dir.write_text(json.dumps(config_content))
        result = bridge.load_config()
        assert result == config_content
        assert result["HUB_IP"] == "192.168.1.1"
        assert result["HUB_TOKEN"] == "test-token-123"


class TestSaveConfig:
    """Tests for save_config()."""

    def test_save_config_writes_file(self, temp_config_dir, monkeypatch):
        monkeypatch.setattr(bridge, "CONFIG_FILE", str(temp_config_dir))
        bridge.save_config("10.0.0.1", "my-token")
        assert temp_config_dir.exists()
        data = json.loads(temp_config_dir.read_text())
        assert data["HUB_IP"] == "10.0.0.1"
        assert data["HUB_TOKEN"] == "my-token"


class TestGetRooms:
    """Tests for GET /rooms."""

    def test_get_rooms_no_hub_returns_500(self, app_client):
        r = app_client.get("/rooms")
        assert r.status_code == 500
        data = r.get_json()
        assert "error" in data
        assert "not connected" in data["error"].lower()

    def test_get_rooms_with_hub_returns_200(self, client_with_hub):
        r = client_with_hub.get("/rooms")
        assert r.status_code == 200
        data = r.get_json()
        assert "rooms" in data
        assert isinstance(data["rooms"], list)

    def test_get_rooms_offline_room_marked(self, client_with_hub, mock_light_offline):
        # Only offline light in one room
        bridge.hub_interface.get_lights.return_value = [mock_light_offline]
        r = client_with_hub.get("/rooms")
        assert r.status_code == 200
        rooms = r.get_json()["rooms"]
        assert len(rooms) == 1
        assert rooms[0]["is_offline"] is True
        assert rooms[0]["is_on"] is False

    def test_get_rooms_skips_lights_without_room(self, client_with_hub, mock_light):
        mock_light.room = None
        bridge.hub_interface.get_lights.return_value = [mock_light]
        r = client_with_hub.get("/rooms")
        assert r.status_code == 200
        assert r.get_json()["rooms"] == []


class TestToggleRoom:
    """Tests for POST /rooms/<room_id>/toggle."""

    def test_toggle_no_hub_returns_500(self, app_client):
        r = app_client.post("/rooms/room-1/toggle")
        assert r.status_code == 500

    def test_toggle_room_not_found_returns_404(self, client_with_hub):
        bridge.hub_interface.get_lights.return_value = []
        r = client_with_hub.post("/rooms/nonexistent/toggle")
        assert r.status_code == 404
        assert "not found" in r.get_json()["error"].lower()

    def test_toggle_all_offline_returns_400(self, client_with_hub, mock_light_offline):
        mock_light_offline.room.id = "room-2"
        bridge.hub_interface.get_lights.return_value = [mock_light_offline]
        r = client_with_hub.post("/rooms/room-2/toggle")
        assert r.status_code == 400
        assert "offline" in r.get_json()["error"].lower()

    def test_toggle_success_returns_200(self, client_with_hub):
        r = client_with_hub.post("/rooms/room-1/toggle")
        assert r.status_code == 200
        data = r.get_json()
        assert data["success"] is True
        assert "new_state" in data


class TestSetBrightness:
    """Tests for POST /rooms/<room_id>/brightness."""

    def test_brightness_no_hub_returns_500(self, app_client):
        r = app_client.post(
            "/rooms/room-1/brightness",
            json={"level": 50},
            content_type="application/json",
        )
        assert r.status_code == 500

    def test_brightness_missing_level_returns_400(self, client_with_hub):
        r = client_with_hub.post(
            "/rooms/room-1/brightness",
            json={},
            content_type="application/json",
        )
        assert r.status_code == 400
        assert "level" in r.get_json()["error"].lower()

    def test_brightness_room_not_found_returns_404(self, client_with_hub):
        bridge.hub_interface.get_lights.return_value = []
        r = client_with_hub.post(
            "/rooms/room-99/brightness",
            json={"level": 50},
            content_type="application/json",
        )
        assert r.status_code == 404

    def test_brightness_all_offline_returns_400(self, client_with_hub, mock_light_offline):
        bridge.hub_interface.get_lights.return_value = [mock_light_offline]
        r = client_with_hub.post(
            "/rooms/room-2/brightness",
            json={"level": 50},
            content_type="application/json",
        )
        assert r.status_code == 400
        assert "offline" in r.get_json()["error"].lower()

    def test_brightness_success_rounds_to_10(self, client_with_hub):
        r = client_with_hub.post(
            "/rooms/room-1/brightness",
            json={"level": 47},
            content_type="application/json",
        )
        assert r.status_code == 200
        data = r.get_json()
        assert data["success"] is True
        assert data["level"] == 50  # Rounded to nearest 10

    def test_brightness_clamps_to_100(self, client_with_hub):
        r = client_with_hub.post(
            "/rooms/room-1/brightness",
            json={"level": 150},
            content_type="application/json",
        )
        assert r.status_code == 200
        assert r.get_json()["level"] == 100
