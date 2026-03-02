import socket
import concurrent.futures

# Your subnet based on your local IP (172.17.112.x)
SUBNET = "172.17.112" 

def check_ip(ip):
    # Dirigera usually listens on 8443 (HTTPS)
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

def scan():
    print(f"Scanning {SUBNET}.1 to {SUBNET}.254 for Dirigera Hub (Port 8443)...")
    found = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = [executor.submit(check_ip, f"{SUBNET}.{i}") for i in range(1, 255)]
        for future in concurrent.futures.as_completed(futures):
            ip = future.result()
            if ip:
                print(f"Potential Hub Found: {ip}")
                found.append(ip)
    
    if not found:
        print("No devices found on port 8443. Try checking your Router or App.")
    else:
        print("Try using one of the IPs above!")

if __name__ == "__main__":
    scan()
