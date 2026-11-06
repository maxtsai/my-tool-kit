#!/usr/bin/env python3

import subprocess
import re
import socket
import platform
import concurrent.futures

def get_local_ip():
    """取得本機在該網段中的 IP"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '127.0.0.1'
    finally:
        s.close()
    return local_ip

def ping_host(ip):
    """對單一 IP 發送一個 ping 封包以觸發 ARP 紀錄"""
    param = '-n' if platform.system().lower() == 'windows' else '-c'
    timeout_param = '-w' if platform.system().lower() == 'windows' else '-W'
    timeout_val = '50' if platform.system().lower() == 'windows' else '1'
    
    cmd = ['ping', param, '1', timeout_param, timeout_val, str(ip)]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def get_arp_table():
    """讀取 Linux 系統的 ARP 表格，回傳 {mac: ip} 的對應字典"""
    arp_table = {}
    try:
        output = subprocess.check_output('arp -a', shell=True, text=True, errors='ignore')
        # Linux arp -a 格式範例: ? (10.106.0.72) at d8:bb:c1:11:f6:e5 [ether] on eth1
        pattern = re.compile(r'\((?P<ip>[0-9\.]+)\)\s+at\s+(?P<mac>[0-9a-fA-F:]+)')
        for match in pattern.finditer(output):
            ip = match.group('ip')
            mac = match.group('mac').lower()
            arp_table[mac] = ip
    except Exception as e:
        print(f"讀取 ARP 表失敗: {e}")
    return arp_table

def find_ip_by_mac(target_mac):
    local_ip = get_local_ip()
    if local_ip == '127.0.0.1':
        print("無法自動偵測本機 IP，請確認網路連線。")
        return

    network_prefix = '.'.join(local_ip.split('.')[:3]) + '.'
    print(f"[*] 本機 IP: {local_ip}")
    print(f"[*] 正在掃描網段: {network_prefix}1 ~ {network_prefix}254 ...")

    target_mac_clean = target_mac.lower().strip()

    ips_to_ping = [f"{network_prefix}{i}" for i in range(1, 255)]

    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        executor.map(ping_host, ips_to_ping)

    print("[*] 掃描完成，正在查詢 ARP 表...")
    arp_table = get_arp_table()

    found_ip = arp_table.get(target_mac_clean)
    
    if found_ip:
        print(f"\n[+] 成功找到！")
        print(f"    MAC: {target_mac}")
        print(f"    IP : {found_ip}")
    else:
        print(f"\n[-] 未在 ARP 表中找到 MAC 為 {target_mac} 的裝置。")

if __name__ == '__main__':
    # 填入你要找的目標 MAC 位址
    TARGET_MAC = "d8:bb:c1:11:f6:e5" 
    find_ip_by_mac(TARGET_MAC)
