import configparser
import os
import subprocess
import sys
import time
import requests
import json
import re
from datetime import datetime

# === 依赖检查 ===
try:
    from Crypto.Cipher import DES
    from Crypto.Util.Padding import pad
    import binascii
except ImportError:
    print("❌ 请先安装依赖: pip install pycryptodome")
    sys.exit(1)

# === 配置 ===
CAMPUS_SSID = "NSU-SDN"
CONFIG_PATH = "../nsu_config.ini"

ISP_PACKAGES = {
    "中国电信": "学生-电信-200M",
    "中国联通": "学生-联通-200M",
    "中国移动": "学生-移动-200M",
}


# === 工具函数 ===
def log(msg, color="white"):
    timestamp = datetime.now().strftime("[%H:%M:%S]")
    if color == "green":
        print(f"\033[92m{timestamp} {msg}\033[0m")
    elif color == "yellow":
        print(f"\033[93m{timestamp} {msg}\033[0m")
    elif color == "red":
        print(f"\033[91m{timestamp} {msg}\033[0m")
    else:
        print(f"{timestamp} {msg}")

def is_wifi_connected(ssid):
    try:
        result = subprocess.check_output(["netsh", "wlan", "show", "interfaces"], encoding="gbk", errors="ignore")
        for line in result.split("\n"):
            if "SSID" in line and "BSSID" not in line:
                current = line.split(":", 1)[1].strip()
                return current == ssid
        return False
    except:
        return False

def connect_wifi(ssid):
    if is_wifi_connected(ssid):
        log(f"✅ 已连接目标WiFi: {ssid}", "green")
        return True
    log(f"📡 正在连接 WiFi: {ssid}...", "yellow")
    try:
        subprocess.run(["netsh", "wlan", "connect", f"name={ssid}"], timeout=15, capture_output=True)
        for _ in range(10):
            time.sleep(1)
            if is_wifi_connected(ssid):
                log(f"✅ 成功连接到 {ssid}", "green")
                return True
        log("❌ 连接超时", "red")
        return False
    except Exception as e:
        log(f"❌ 连接失败: {e}", "red")
        return False

def get_local_ip():
    try:
        result = subprocess.check_output(["ipconfig"], encoding="gbk")
        for line in result.split("\n"):
            if "IPv4" in line or "IP地址" in line:
                ip_match = re.search(r"\d+\.\d+\.\d+\.\d+", line)
                if ip_match:
                    return ip_match.group()
    except Exception as e:
        log(f"获取IP失败: {e}", "red")
    return "未知"

def generate_password(username, raw_password):
    key_str = username[-4:] + username + "12345678"
    key = key_str.encode("utf-8")[:8].ljust(8, b"\x00")
    cipher = DES.new(key, DES.MODE_ECB)
    padded = pad(raw_password.encode("utf-8"), DES.block_size, style="pkcs7")
    encrypted = cipher.encrypt(padded)
    return binascii.hexlify(encrypted).decode("utf-8")

def offline_device(ip):
    """强制下线指定IP（使用 CloseNet 接口）"""
    url = "http://2.2.2.2/Auth.ashx"
    data = {"DoWhat": "CloseNet", "IP": ip}
    headers = {
        "Content-Type": "application/json",
        "Referer": "http://2.2.2.2/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    try:
        res = requests.post(url, json=data, headers=headers, timeout=10)
        res_json = res.json()
        if res_json.get("Result"):
            log(f"✅ 成功下线设备: {ip}", "green")
            return True
        else:
            log(f"❌ 下线失败: {res_json.get('Message', '未知错误')}", "red")
            return False
    except Exception as e:
        log(f"⚠️ 下线请求异常: {e}", "red")
        return False

def login_campus(username, password, isp):
    url = "http://2.2.2.2/Auth.ashx"
    pkg = ISP_PACKAGES.get(isp, "学生-电信-200M")
    enc_pass = generate_password(username, password)

    headers = {
        "Content-Type": "application/json",
        "Referer": "http://2.2.2.2/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }

    # Step 1: Login
    login_data = {"DoWhat": "Login", "remember": True, "username": username, "password": enc_pass}
    try:
        res = requests.post(url, json=login_data, headers=headers, timeout=10)
        res_json = res.json()
    except Exception as e:
        log(f"❌ 登录失败: {e}", "red")
        return False

    if not res_json.get("Result"):
        msg = res_json.get("Message", "未知错误")
        log(f"❌ 身份验证失败: {msg}", "red")
        return False

    # Step 2: OpenNet
    open_data = {"DoWhat": "OpenNet", "Package": pkg}
    try:
        open_res = requests.post(url, json=open_data, headers=headers, timeout=10)
        open_json = open_res.json()
    except Exception as e:
        log(f"❌ 上线失败: {e}", "red")
        return False

    if open_json.get("Result") or "成功" in str(open_json):
        log("🎉 校园网上线成功！", "green")
        return True
    else:
        msg = open_json.get("Message", "")
        log(f"❌ 上线失败: {msg}", "red")
        return False

def create_default_config():
    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
        f.write("[CAMPUS]\n")
        f.write("username = \n")
        f.write("password = \n")
        f.write("isp = 中国电信\n")
    log(f"📝 已创建配置文件: {CONFIG_PATH}", "yellow")
    log("👉 请用记事本打开并填写账号密码，然后重新运行程序。", "yellow")

# === 主程序 ===
def main():
    log("🚀 开始执行 NSU 校园网自动登录脚本...", "yellow")

    # 检查配置文件
    if not os.path.exists(CONFIG_PATH):
        create_default_config()
        return

    # 读取配置
    config = configparser.ConfigParser()
    try:
        config.read(CONFIG_PATH, encoding="utf-8")
        sec = config["CAMPUS"]
        username = sec["username"].strip()
        password = sec["password"].strip()
        isp = sec["isp"].strip()
        if not username or not password:
            log("❌ 配置文件中 username 或 password 为空！", "red")
            return
    except Exception as e:
        log(f"❌ 配置文件读取失败: {e}", "red")
        return

    # 1. 连接 WiFi
    if not connect_wifi(CAMPUS_SSID):
        log("无法连接校园网WiFi", "red")
        return

    # 2. 获取本地 IP
    local_ip = get_local_ip()
    log(f"💻 当前设备IP: {local_ip}", "yellow")

    # 3. 手动输入手机IP（因为系统可能不提供查询接口）
    print("\n📱 请输入需要踢掉的手机IP（如 10.219.25.199）")
    print("   如果不知道，可在手机连网后访问 http://2.2.2.2/ 查看")
    phone_ip = input("手机IP（留空则跳过）: ").strip()

    if phone_ip and phone_ip != local_ip:
        log(f"🔧 尝试下线手机设备: {phone_ip}", "yellow")
        offline_device(phone_ip)
        time.sleep(2)

    # 4. 尝试登录
    log("🔑 尝试登录校园网...", "yellow")
    success = login_campus(username, password, isp)
    if success:
        log("🎉 电脑已成功上线！手机应已断网。", "green")
    else:
        log("💥 上线失败，请检查账号或手动操作。", "red")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("\n👋 用户中断", "yellow")
    except Exception as e:
        log(f"🔥 程序异常: {e}", "red")