#!/bin/env bash
# Forzar la detención del script ante cualquier fallo
set -e

echo "[*] Instalación de dependencias..."
sudo apt update && sudo apt install -y wget

echo "[*] Descarga de los drivers oficiales de Brother..."
wget -O brscan5-1.7.0-0.amd64.deb "https://support.brother.com/g/b/downloadend.aspx?c=mx&lang=es&prod=dcpt220_all&os=128&dlid=dlf104033_000&flang=4&type3=566"

echo "[*] Instalación del paquete local con apt..."
sudo apt install -y ./brscan5-1.7.0-0.amd64.deb

echo "[*] Instalación de la interfaz gráfica de escaneo..."
sudo apt install -y simple-scan

echo "[*] Verificación del hardware con SANE..."
sudo sane-find-scanner


