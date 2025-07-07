#!/bin/bash
# Desinstalador del Sistema de Gestión ZIVPN-Users
# Autor: Zahid Islam

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

# Mostrar banner
echo -e "${YELLOW}"
echo "================================================"
echo "  DESINSTALADOR DEL SISTEMA DE GESTIÓN ZIVPN-USERS"
echo "================================================"
echo -e "${NC}"

# Confirmación
echo -e "${RED}ADVERTENCIA: Esto eliminará completamente el sistema de gestión de usuarios.${NC}"
read -p "¿Estás seguro de que deseas continuar? [s/N]: " confirm

if [[ ! "$confirm" =~ ^[SsYy]$ ]]; then
    echo -e "${GREEN}Desinstalación cancelada.${NC}"
    exit 0
fi

# 1. Eliminar el script principal
echo -e "${BLUE}[1/4] Eliminando el script de gestión...${NC}"
INSTALL_PATH="/usr/local/bin/zivpn-users"
if [ -f "$INSTALL_PATH" ]; then
    rm -f "$INSTALL_PATH"
    echo -e "  ${GREEN}Script eliminado: ${INSTALL_PATH}${NC}"
else
    echo -e "  ${YELLOW}El script no se encontró en ${INSTALL_PATH}${NC}"
fi

# 2. Eliminar el cron job
echo -e "${BLUE}[2/4] Eliminando tarea programada...${NC}"
CRON_FILE="/etc/cron.d/zivpn-expiry"
if [ -f "$CRON_FILE" ]; then
    rm -f "$CRON_FILE"
    echo -e "  ${GREEN}Cron job eliminado: ${CRON_FILE}${NC}"
else
    echo -e "  ${YELLOW}El archivo cron no se encontró en ${CRON_FILE}${NC}"
fi

# 3. Eliminar archivo de log (opcional)
echo -e "${BLUE}[3/4] ¿Desea eliminar el archivo de registro?${NC}"
read -p "  Eliminar /var/log/zivpn-users.log? [s/N]: " log_choice
if [[ "$log_choice" =~ ^[SsYy]$ ]]; then
    LOG_FILE="/var/log/zivpn-users.log"
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        echo -e "  ${GREEN}Archivo de log eliminado.${NC}"
    else
        echo -e "  ${YELLOW}El archivo de log no se encontró.${NC}"
    fi
else
    echo -e "  ${GREEN}Conservando el archivo de log.${NC}"
fi

# 4. Eliminar base de datos de usuarios (opcional)
echo -e "${BLUE}[4/4] ¿Desea eliminar la base de datos de usuarios?${NC}"
echo -e "  ${YELLOW}ADVERTENCIA: Esto eliminará todos los registros de usuarios y expiraciones.${NC}"
read -p "  Eliminar /etc/zivpn/users.json? [s/N]: " db_choice
if [[ "$db_choice" =~ ^[SsYy]$ ]]; then
    USER_DB="/etc/zivpn/users.json"
    if [ -f "$USER_DB" ]; then
        rm -f "$USER_DB"
        echo -e "  ${GREEN}Base de datos de usuarios eliminada.${NC}"
        
        # Restaurar configuración original
        jq '.auth.config = ["zi"]' /etc/zivpn/config.json > tmp.json && mv tmp.json /etc/zivpn/config.json
        systemctl restart zivpn.service
        echo -e "  ${GREEN}Configuración restaurada a contraseña predeterminada 'zi'.${NC}"
    else
        echo -e "  ${YELLOW}La base de datos no se encontró.${NC}"
    fi
else
    echo -e "  ${GREEN}Conservando la base de datos de usuarios.${NC}"
fi

echo -e "\n${GREEN}Desinstalación completada!${NC}"
echo -e "${YELLOW}El sistema de gestión de usuarios ha sido eliminado.${NC}"
