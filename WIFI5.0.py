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
    except:
        pass
    return "未知"


def generate_password(username, raw_password):
    key_str = username[-4:] + username + "12345678"
    key = key_str.encode("utf-8")[:8].ljust(8, b"\x00")
    cipher = DES.new(key, DES.MODE_ECB)
    padded = pad(raw_password.encode("utf-8"), DES.block_size, style="pkcs7")
    encrypted = cipher.encrypt(padded)
    return binascii.hexlify(encrypted).decode("utf-8")


def offline_device(ip):
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
        f.write("last_phone_ip = \n")
    log(f"📝 已创建配置文件: {CONFIG_PATH}", "yellow")
    log("👉 请填写账号密码，并在首次运行时输入手机IP", "yellow")


def ping_ip(ip):
    """快速检测 IP 是否可达（不严格依赖）"""
    try:
        result = subprocess.run(
            ["ping", "-n", "1", "-w", "500", ip],
            capture_output=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        return result.returncode == 0
    except:
        return False


# === 主程序 ===
def main():
    log("🚀 开始执行 NSU 校园网自动登录脚本...", "yellow")

    # 检查并读取配置
    if not os.path.exists(CONFIG_PATH):
        create_default_config()
        return

    config = configparser.ConfigParser()
    try:
        config.read(CONFIG_PATH, encoding="utf-8")
    except Exception as e:
        log(f"❌ 配置文件读取失败: {e}", "red")
        return

    if "CAMPUS" not in config:
        create_default_config()
        return

    sec = config["CAMPUS"]
    username = sec.get("username", "").strip()
    password = sec.get("password", "").strip()
    isp = sec.get("isp", "中国电信").strip()
    last_phone_ip = sec.get("last_phone_ip", "").strip()

    if not username or not password:
        log("❌ 配置文件中 username 或 password 为空！", "red")
        return

    # 1. 连接 WiFi
    if not connect_wifi(CAMPUS_SSID):
        return

    # 2. 获取本机 IP
    local_ip = get_local_ip()
    log(f"💻 当前设备IP: {local_ip}", "yellow")

    phone_ip_to_kick = None

    # === 3. 处理手机 IP 逻辑 ===
    if last_phone_previously_saved := bool(last_phone_ip and last_phone_ip != local_ip):
        log(f"🔍 检测上次记录的手机IP: {last_phone_ip}", "yellow")
        if ping_ip(last_phone_ip):
            log(f"📱 手机设备在线: {last_phone_ip}", "yellow")
            choice = input("是否踢掉该设备？(y/n): ").strip().lower()
            if choice == 'y':
                phone_ip_to_kick = last_phone_ip
        else:
            log(f"📴 手机设备 {last_phone_ip} 当前不可达（可能休眠或断开）", "yellow")

        # 是否更新？
        if input("是否更新手机IP？(y/n): ").strip().lower() == 'y':
            new_ip = input("请输入新的手机IP（留空跳过）: ").strip()
            if new_ip and new_ip != local_ip:
                phone_ip_to_kick = new_ip
                config.set("CAMPUS", "last_phone_ip", new_ip)
                try:
                    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
                        config.write(f)
                    log("💾 新手机IP已保存到配置文件", "green")
                except Exception as e:
                    log(f"❌ 保存失败: {e}", "red")
            else:
                log("⏭️ 跳过更新", "yellow")
    else:
        # 首次使用：必须输入
        new_ip = input("请输入手机IP（留空跳过）: ").strip()
        if new_ip and new_ip != local_ip:
            phone_ip_to_kick = new_ip
            config.set("CAMPUS", "last_phone_ip", new_ip)
            try:
                with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
                    config.write(f)
                log("💾 手机IP已保存到配置文件", "green")
            except Exception as e:
                log(f"❌ 保存失败: {e}", "red")
        else:
            log("⏭️ 未设置手机IP，跳过踢人", "yellow")

    # === 4. 执行踢人 ===
    if phone_ip_to_kick:
        offline_device(phone_ip_to_kick)
        time.sleep(2)

    # === 5. 登录校园网 ===
    log("🔑 尝试登录校园网...", "yellow")
    success = login_campus(username, password, isp)
    if success:
        log("🎉 电脑已成功上线！", "green")
    else:
        log("💥 上线失败，请手动检查。", "red")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("\n👋 用户中断", "yellow")
    except Exception as e:
        log(f"🔥 程序异常: {e}", "red")