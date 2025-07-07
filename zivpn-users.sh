#!/bin/bash
# ZIVPN User Management System
# Author: Zahid Islam
# Version: 2.0
# Description: Gestión de usuarios con expiración para ZIVPN UDP

# Configuración
CONFIG_FILE="/etc/zivpn/config.json"
USER_DB="/etc/zivpn/users.json"
LOG_FILE="/var/log/zivpn-users.log"
SERVICE_NAME="zivpn.service"

# Inicializar sistema
init_system() {
    # Crear base de datos si no existe
    [ ! -f "$USER_DB" ] && echo "[]" > "$USER_DB"
    
    # Crear archivo de log
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    
    # Asegurar permisos
    chmod 600 "$USER_DB" "$LOG_FILE"
}

# Registrar acciones
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Agregar usuario
add_user() {
    echo -e "\n\033[1;34m[ AGREGAR USUARIO ]\033[0m"
    
    read -p "Contraseña del usuario: " password
    [ -z "$password" ] && echo "Operación cancelada" && return
    
    while true; do
        read -p "Días de validez: " days
        [[ "$days" =~ ^[0-9]+$ ]] && break
        echo "Error: Debe ser un número entero"
    done
    
    expiry_date=$(date -d "+${days} days" +%Y-%m-%d)
    
    # Agregar a config.json
    if ! jq --arg pw "$password" '.auth.config += [$pw]' "$CONFIG_FILE" > tmp.json; then
        echo "Error: Falló al modificar config.json"
        return 1
    fi
    mv tmp.json "$CONFIG_FILE"
    
    # Agregar a base de datos
    jq --arg pw "$password" --arg exp "$expiry_date" --arg days "$days" \
        '. += [{"password": $pw, "expiry": $exp, "days": $days}]' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    # Reiniciar servicio
    systemctl restart "$SERVICE_NAME"
    
    echo -e "\n\033[1;32mUsuario agregado exitosamente!\033[0m"
    echo "Contraseña: $password"
    echo "Validez: $days días"
    echo "Expira: $expiry_date"
    log "Nuevo usuario: $password (Validez: $days días)"
}

# Listar usuarios
list_users() {
    echo -e "\n\033[1;34m[ USUARIOS REGISTRADOS ]\033[0m"
    
    current_date=$(date +%Y-%m-%d)
    total_users=0
    active_users=0
    
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        pass=$(jq -r '.password' <<< "$user")
        expiry=$(jq -r '.expiry' <<< "$user")
        days=$(jq -r '.days' <<< "$user")
        
        # Calcular días restantes
        expiry_sec=$(date -d "$expiry" +%s)
        today_sec=$(date -d "$current_date" +%s)
        days_left=$(( (expiry_sec - today_sec) / 86400 ))
        
        # Mostrar estado
        if [ "$days_left" -lt 0 ]; then
            status="\033[1;31mEXPIRADO\033[0m"
        else
            status="\033[1;32mACTIVO\033[0m"
            ((active_users++))
        fi
        
        echo -e "Contraseña: $pass | Días: $days | Expira: $expiry ($days_left días) | Estado: $status"
        ((total_users++))
    done < <(jq -c '.[]' "$USER_DB")
    
    echo -e "\nTotal usuarios: $total_users | Activos: $active_users"
}

# Eliminar usuario
remove_user() {
    echo -e "\n\033[1;34m[ ELIMINAR USUARIO ]\033[0m"
    
    list_users
    read -p "Contraseña a eliminar (dejar vacío para cancelar): " password
    [ -z "$password" ] && echo "Operación cancelada" && return
    
    # Eliminar de config.json
    if ! jq --arg pw "$password" '.auth.config |= map(select(. != $pw))' "$CONFIG_FILE" > tmp.json; then
        echo "Error: Falló al modificar config.json"
        return 1
    fi
    mv tmp.json "$CONFIG_FILE"
    
    # Eliminar de base de datos
    jq --arg pw "$password" 'map(select(.password != $pw))' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    # Reiniciar servicio
    systemctl restart "$SERVICE_NAME"
    
    echo -e "\n\033[1;32mUsuario eliminado exitosamente!\033[0m"
    log "Usuario eliminado: $password"
}

# Verificar expiraciones
check_expirations() {
    current_date=$(date +%Y-%m-%d)
    expired_users=()
    
    while IFS= read -r user; do
        pass=$(jq -r '.password' <<< "$user")
        expiry=$(jq -r '.expiry' <<< "$user")
        
        if [[ "$current_date" > "$expiry" ]]; then
            expired_users+=("$pass")
            
            # Eliminar de config.json
            jq --arg pw "$pass" '.auth.config |= map(select(. != $pw))' "$CONFIG_FILE" > tmp.json
            mv tmp.json "$CONFIG_FILE"
            
            # Registrar log
            log "Usuario expirado eliminado: $pass"
        fi
    done < <(jq -c '.[]' "$USER_DB")
    
    # Actualizar base de datos
    jq --arg now "$current_date" 'map(select(.expiry >= $now))' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    # Reiniciar servicio si hubo cambios
    if [ ${#expired_users[@]} -gt 0 ]; then
        systemctl restart "$SERVICE_NAME"
        echo "Usuarios expirados eliminados: ${expired_users[*]}"
        log "Reinicio de servicio después de eliminar expirados"
    fi
}

# Menú principal
main_menu() {
    init_system
    
    while true; do
        echo -e "\n\033[1;36m===== GESTIÓN DE USUARIOS ZIVPN =====\033[0m"
        echo "1) Agregar nuevo usuario"
        echo "2) Listar usuarios existentes"
        echo "3) Eliminar usuario"
        echo "4) Verificar expiraciones ahora"
        echo "5) Ver registro de actividad"
        echo "6) Salir"
        echo -n "Seleccione una opción: "
        
        read choice
        case $choice in
            1) add_user ;;
            2) list_users ;;
            3) remove_user ;;
            4) check_expirations ;;
            5) [ -f "$LOG_FILE" ] && cat "$LOG_FILE" || echo "No hay registros" ;;
            6) exit 0 ;;
            *) echo "Opción inválida!" ;;
        esac
    done
}

# Manejar argumentos CLI
case "$1" in
    --add)
        add_user
        ;;
    --list)
        list_users
        ;;
    --remove)
        remove_user
        ;;
    --check)
        check_expirations
        ;;
    --log)
        [ -f "$LOG_FILE" ] && cat "$LOG_FILE" || echo "No hay registros"
        ;;
    *)
        main_menu
        ;;
esac
