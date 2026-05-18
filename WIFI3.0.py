import configparser
import os
import subprocess
import sys
import time
import webbrowser
import requests
import tkinter as tk
from tkinter import messagebox, ttk

# 加密依赖
try:
    from Crypto.Cipher import DES
    from Crypto.Util.Padding import pad
    import binascii
except ImportError:
    messagebox.showerror("缺少依赖", "请先运行：pip install pycryptodome")
    sys.exit(1)

CAMPUS_SSID = "NSU-SDN"
CONFIG_PATH = "../nsu_config.ini"

# ====== 运营商套餐映射 ======
ISP_PACKAGES = {
    "中国电信": "学生-电信-200M",
    "中国联通": "学生-联通-200M",
    "中国移动": "学生-移动-200M",
    # 如果有其他套餐，按实际添加
}

def generate_campus_password(username: str, raw_password: str) -> str:
    key_str = username[-4:] + username + "12345678"
    key_bytes = key_str.encode("utf-8")[:8].ljust(8, b"\x00")
    cipher = DES.new(key_bytes, DES.MODE_ECB)
    padded = pad(raw_password.encode("utf-8"), DES.block_size, style="pkcs7")
    encrypted = cipher.encrypt(padded)
    return binascii.hexlify(encrypted).decode("utf-8")


def is_wifi_connected(target_ssid: str) -> bool:
    try:
        result = subprocess.check_output(["netsh", "wlan", "show", "interfaces"], encoding="gbk", errors="ignore")
        for line in result.split("\n"):
            if "SSID" in line and "BSSID" not in line:
                current_ssid = line.split(":")[1].strip()
                return current_ssid == target_ssid
        return False
    except:
        return False

def connect_to_wifi(ssid: str) -> bool:
    if is_wifi_connected(ssid):
        return True
    try:
        result = subprocess.run(["netsh", "wlan", "connect", f"name={ssid}"], capture_output=True, text=True, timeout=15)
        if result.returncode == 0:
            for _ in range(10):
                time.sleep(1)
                if is_wifi_connected(ssid):
                    return True
        return False
    except:
        return False

def is_network_reachable() -> bool:
    try:
        requests.get("http://2.2.2.2/", timeout=3)
        return True
    except:
        return False

# ====== 登录核心（使用 isp 参数）======
def login_campus_net(username: str, raw_password: str, isp: str) -> bool:
    url = "http://2.2.2.2/Auth.ashx"
    encrypted_password = generate_campus_password(username, raw_password)
    package_name = ISP_PACKAGES.get(isp, "学生-电信-200M")  # 默认电信

    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Host": "2.2.2.2",
        "Accept": "application/json, text/plain, */*"
    }

    try:
        # 登录
        login_data = {"DoWhat": "Login", "remember": True, "username": username, "password": encrypted_password}
        res = requests.post(url, json=login_data, headers=headers, timeout=10)
        res_json = res.json()
        if not res_json.get("Result"):
            messagebox.showerror("失败", f"身份验证失败：{res_json.get('Message', '未知错误')}")
            return False

        # 上线（使用正确套餐）
        opennet_data = {"DoWhat": "OpenNet", "Package": package_name}
        open_res = requests.post(url, json=opennet_data, headers=headers, timeout=10)
        open_json = open_res.json()

        if open_json.get("Result") or "上线成功" in str(open_json):
            messagebox.showinfo("成功", "校园网登录并上线成功！")
            return True
        else:
            messagebox.showerror("失败", f"上线失败：{open_json.get('Message', open_json)}")
            return False

    except Exception as e:
        messagebox.showerror("错误", f"请求失败：{e}")
        return False

# ====== 配置管理 ======
def load_config():
    config = configparser.ConfigParser()
    if os.path.exists(CONFIG_PATH):
        config.read(CONFIG_PATH, encoding="utf-8")
        sec = config["CAMPUS"] if "CAMPUS" in config.sections() else {}
        return {
            "username": sec.get("username", ""),
            "password": sec.get("password", ""),
            "isp": sec.get("isp", "中国电信")  # 默认电信
        }
    return {"username": "", "password": "", "isp": "中国电信"}

def save_config(username: str, password: str, isp: str):
    config = configparser.ConfigParser()
    config["CAMPUS"] = {
        "ssid": CAMPUS_SSID,
        "username": username,
        "password": password,
        "isp": isp
    }
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        config.write(f)
    messagebox.showinfo("成功", "账号信息已保存！")

# ====== GUI 界面 ======
class CampusApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("NSU校园网自动登录（多运营商版）")
        self.geometry("420x260")
        self.resizable(False, False)
        self.config_data = load_config()
        self._create_widgets()
        self.after(1000, self.auto_login_if_configured)

    def _create_widgets(self):
        ttk.Label(self, text="NSU校园网自动登录", font=("微软雅黑", 14, "bold")).pack(pady=10)

        # 学号
        frame1 = ttk.Frame(self)
        frame1.pack(fill="x", padx=30, pady=5)
        ttk.Label(frame1, text="学号：", width=10).pack(side="left")
        self.user_entry = ttk.Entry(frame1, width=30)
        self.user_entry.pack(side="left", padx=5)
        self.user_entry.insert(0, self.config_data["username"])

        # 密码
        frame2 = ttk.Frame(self)
        frame2.pack(fill="x", padx=30, pady=5)
        ttk.Label(frame2, text="密码：", width=10).pack(side="left")
        self.pass_entry = ttk.Entry(frame2, width=30, show="●")
        self.pass_entry.pack(side="left", padx=5)
        self.pass_entry.insert(0, self.config_data["password"])

        # 运营商选择
        frame3 = ttk.Frame(self)
        frame3.pack(fill="x", padx=30, pady=5)
        ttk.Label(frame3, text="运营商：", width=10).pack(side="left")
        self.isp_var = tk.StringVar(value=self.config_data["isp"])
        isp_combo = ttk.Combobox(frame3, textvariable=self.isp_var, values=list(ISP_PACKAGES.keys()), state="readonly", width=28)
        isp_combo.pack(side="left", padx=5)

        # 按钮
        btn_frame = ttk.Frame(self)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="保存", command=self.save_click).pack(side="left", padx=15)
        ttk.Button(btn_frame, text="登录", command=self.login_click).pack(side="left", padx=15)

    def auto_login_if_configured(self):
        u, p, i = self.config_data["username"], self.config_data["password"], self.config_data["isp"]
        if u and p:
            self._do_login(u, p, i)
        else:
            messagebox.showinfo("提示", "请先填写并保存你的学号、密码和运营商！")

    def _do_login(self, username: str, password: str, isp: str):
        if not connect_to_wifi(CAMPUS_SSID):
            messagebox.showerror("错误", f"无法连接到 {CAMPUS_SSID}\n请确保你曾手动连接并保存过该网络！")
            return

        for _ in range(10):
            if is_network_reachable():
                break
            time.sleep(1)
        else:
            messagebox.showwarning("警告", "网络未就绪，但仍尝试登录...")

        login_campus_net(username, password, isp)

    def save_click(self):
        u = self.user_entry.get().strip()
        p = self.pass_entry.get().strip()
        i = self.isp_var.get()
        if not (u and p and i):
            messagebox.showerror("错误", "学号、密码、运营商不能为空！")
            return
        save_config(u, p, i)
        self.config_data = load_config()

    def login_click(self):
        u = self.user_entry.get().strip()
        p = self.pass_entry.get().strip()
        i = self.isp_var.get()
        if not (u and p and i):
            messagebox.showerror("错误", "学号、密码、运营商不能为空！")
            return
        self._do_login(u, p, i)

# ====== 启动 ======
if __name__ == "__main__":
    if getattr(sys, 'frozen', False):
        import ctypes
        ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)
    app = CampusApp()
    app.mainloop()