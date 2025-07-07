#!/bin/bash
# Instalador del Sistema de Gestión ZIVPN-Users
# Repositorio: https://github.com/Dex1399/zimenu

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Debes ejecutar este script como root${NC}"
    exit 1
fi

# URL del script en GitHub
SCRIPT_URL="https://raw.githubusercontent.com/Dex1399/zimenu/main/zivpn-users.sh"

# Mostrar banner
echo -e "${YELLOW}"
echo "================================================"
echo "  INSTALADOR DEL SISTEMA DE GESTIÓN ZIVPN-USERS"
echo "================================================"
echo -e "${NC}"

# 1. Instalar dependencias
echo -e "${BLUE}[1/4] Instalando dependencias...${NC}"
if ! command -v jq &> /dev/null; then
    apt-get update > /dev/null
    apt-get install -y jq > /dev/null
    echo -e "  ${GREEN}jq instalado${NC}"
else
    echo -e "  ${GREEN}jq ya está instalado${NC}"
fi

# 2. Descargar el script
echo -e "${BLUE}[2/4] Descargando el sistema de gestión...${NC}"
INSTALL_PATH="/usr/local/bin/zivpn-users"
wget -q "$SCRIPT_URL" -O "$INSTALL_PATH"

if [ $? -ne 0 ]; then
    echo -e "  ${RED}Error: No se pudo descargar el script${NC}"
    exit 1
fi

# Dar permisos de ejecución
chmod +x "$INSTALL_PATH"
echo -e "  ${GREEN}Script descargado en ${INSTALL_PATH}${NC}"

# 3. Configurar cron job para expiraciones automáticas
echo -e "${BLUE}[3/4] Configurando verificación automática diaria...${NC}"
CRON_JOB="0 0 * * * root $INSTALL_PATH --check"
CRON_FILE="/etc/cron.d/zivpn-expiry"

echo "$CRON_JOB" > "$CRON_FILE"
chmod 644 "$CRON_FILE"

echo -e "  ${GREEN}Cron job configurado: ${CRON_FILE}${NC}"

# 4. Crear archivo de log
echo -e "${BLUE}[4/4] Configurando sistema de registro...${NC}"
LOG_FILE="/var/log/zivpn-users.log"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

echo -e "  ${GREEN}Archivo de log creado: ${LOG_FILE}${NC}"

# Instalación completada
echo -e "\n${GREEN}Instalación completada con éxito!${NC}"
echo -e "${YELLOW}Puedes comenzar a usar el sistema con:${NC}"
echo -e "  sudo zivpn-users"

# Mostrar menú de ayuda
echo -e "\n${BLUE}COMANDOS DISPONIBLES:${NC}"
echo -e "  ${GREEN}zivpn-users${NC}          - Menú interactivo principal"
echo -e "  ${GREEN}zivpn-users --add${NC}     - Agregar nuevo usuario"
echo -e "  ${GREEN}zivpn-users --list${NC}    - Listar usuarios existentes"
echo -e "  ${GREEN}zivpn-users --remove${NC}  - Eliminar usuario"
echo -e "  ${GREEN}zivpn-users --check${NC}   - Verificar expiraciones manualmente"
echo -e "  ${GREEN}zivpn-users --log${NC}     - Ver registro de actividades"

echo -e "\n${YELLOW}Nota: El sistema verificará automáticamente usuarios expirados cada día a medianoche${NC}"
