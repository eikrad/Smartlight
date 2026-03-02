"""
Tests for scan.py (Hub discovery).
"""
from unittest.mock import patch, MagicMock

import pytest

import scan


class TestCheckIp:
    """Tests for check_ip()."""

    @patch("scan.socket.socket")
    def test_check_ip_returns_ip_when_port_open(self, mock_socket_class):
        mock_sock = MagicMock()
        mock_socket_class.return_value = mock_sock
        mock_sock.connect_ex.return_value = 0  # Success
        result = scan.check_ip("192.168.1.1")
        assert result == "192.168.1.1"
        mock_sock.connect_ex.assert_called_once_with(("192.168.1.1", 8443))

    @patch("scan.socket.socket")
    def test_check_ip_returns_none_when_port_closed(self, mock_socket_class):
        mock_sock = MagicMock()
        mock_socket_class.return_value = mock_sock
        mock_sock.connect_ex.return_value = 1  # Connection refused / not open
        result = scan.check_ip("192.168.1.99")
        assert result is None

    @patch("scan.socket.socket")
    def test_check_ip_returns_none_on_exception(self, mock_socket_class):
        mock_sock = MagicMock()
        mock_socket_class.return_value = mock_sock
        mock_sock.connect_ex.side_effect = OSError("Network error")
        result = scan.check_ip("192.168.1.1")
        assert result is None


class TestScan:
    """Tests for scan()."""

    @patch("scan.check_ip")
    def test_scan_finds_ips(self, mock_check_ip):
        mock_check_ip.side_effect = lambda ip: ip if "5" in ip else None  # Only .5 responds
        scan.scan()
        assert mock_check_ip.call_count == 254

    @patch("scan.check_ip")
    def test_scan_uses_subnet(self, mock_check_ip):
        mock_check_ip.return_value = None
        scan.scan()
        ips_called = [c[0][0] for c in mock_check_ip.call_args_list]
        assert "172.17.112.1" in ips_called
        assert "172.17.112.254" in ips_called
