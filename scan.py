import socket
import concurrent.futures
import sys


def _local_subnet() -> str:
    """Detect the subnet of the primary outbound network interface."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return ".".join(local_ip.split(".")[:3])
    except OSError:
        return "192.168.1"


def check_ip(ip: str) -> str | None:
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        result = sock.connect_ex((ip, 8443))
        sock.close()
        if result == 0:
            return ip
    except OSError:
        pass
    return None


def scan(subnet: str | None = None) -> list[str]:
    subnet = subnet or _local_subnet()
    print(f"Scanning {subnet}.1 to {subnet}.254 for Dirigera Hub (port 8443)...")
    found = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = [executor.submit(check_ip, f"{subnet}.{i}") for i in range(1, 255)]
        for future in concurrent.futures.as_completed(futures):
            ip = future.result()
            if ip:
                print(f"Potential hub found: {ip}")
                found.append(ip)

    if not found:
        print("No devices found on port 8443. Check your router or the IKEA Home app.")
    else:
        print("Try using one of the IPs above!")
    return found


if __name__ == "__main__":
    subnet_arg = sys.argv[1] if len(sys.argv) > 1 else None
    scan(subnet_arg)
