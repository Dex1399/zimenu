#!/bin/bash
# ZIVPN User Management System v2.1
# Repositorio: https://github.com/Dex1399/zimenu

# Configuración
CONFIG_FILE="/etc/zivpn/config.json"
USER_DB="/etc/zivpn/users.json"
LOG_FILE="/var/log/zivpn-users.log"
SERVICE_NAME="zivpn.service"
UNINSTALLER_URL="https://raw.githubusercontent.com/Dex1399/zimenu/main/uninstall.sh"

# Limpiar pantalla
clear_screen() {
    clear
    echo -e "\n\033[1;36m===== GESTIÓN DE USUARIOS ZIVPN =====\033[0m\n"
}

# Inicializar sistema
init_system() {
    [ ! -f "$USER_DB" ] && echo "[]" > "$USER_DB"
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    chmod 600 "$USER_DB" "$LOG_FILE"
}

# Registrar acciones
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Agregar usuario
add_user() {
    clear_screen
    echo -e "\033[1;34m[ AGREGAR USUARIO ]\033[0m\n"
    
    read -p "Contraseña del usuario: " password
    [ -z "$password" ] && return
    
    while true; do
        read -p "Días de validez: " days
        [[ "$days" =~ ^[0-9]+$ ]] && break
        echo "Error: Debe ser un número entero"
    done
    
    expiry_date=$(date -d "+${days} days" +%Y-%m-%d)
    
    # Agregar a config.json
    jq --arg pw "$password" '.auth.config += [$pw]' "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
    
    # Agregar a base de datos
    jq --arg pw "$password" --arg exp "$expiry_date" --arg days "$days" \
        '. += [{"password": $pw, "expiry": $exp, "days": $days}]' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    # Reiniciar servicio
    systemctl restart "$SERVICE_NAME" >/dev/null
    
    echo -e "\n\033[1;32m✓ Usuario agregado exitosamente!\033[0m"
    echo "Contraseña: $password"
    echo "Validez: $days días"
    echo "Expira: $expiry_date"
    log "Nuevo usuario: $password (Validez: $days días)"
    
    read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
}

# Listar usuarios
list_users() {
    clear_screen
    echo -e "\033[1;34m[ USUARIOS REGISTRADOS ]\033[0m\n"
    
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
        
        echo -e " • Contraseña: \033[1;33m$pass\033[0m"
        echo -e "   Días: $days | Expira: $expiry | Restantes: $days_left días | Estado: $status"
        echo "--------------------------------------------"
        ((total_users++))
    done < <(jq -c '.[]' "$USER_DB")
    
    echo -e "\n\033[1;36mResumen:\033[0m Total: $total_users | Activos: $active_users | Expirados: $((total_users - active_users))"
    
    read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
}

# Eliminar usuario
remove_user() {
    clear_screen
    echo -e "\033[1;34m[ ELIMINAR USUARIO ]\033[0m\n"
    
    echo "Usuarios disponibles:"
    jq -r '.[] | " • \(.password) (Expira: \(.expiry))"' "$USER_DB"
    
    echo -e "\n--------------------------------------------"
    read -p $'\nContraseña a eliminar: ' password
    [ -z "$password" ] && return
    
    # Eliminar de config.json
    jq --arg pw "$password" '.auth.config |= map(select(. != $pw))' "$CONFIG_FILE" > tmp.json
    mv tmp.json "$CONFIG_FILE"
    
    # Eliminar de base de datos
    jq --arg pw "$password" 'map(select(.password != $pw))' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    # Reiniciar servicio
    systemctl restart "$SERVICE_NAME" >/dev/null
    
    echo -e "\n\033[1;32m✓ Usuario eliminado exitosamente!\033[0m"
    log "Usuario eliminado: $password"
    
    read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
}

# Verificar expiraciones
check_expirations() {
    clear_screen
    echo -e "\033[1;34m[ VERIFICAR EXPIRACIONES ]\033[0m\n"
    
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
            
            log "Usuario expirado eliminado: $pass"
        fi
    done < <(jq -c '.[]' "$USER_DB")
    
    # Actualizar base de datos
    jq --arg now "$current_date" 'map(select(.expiry >= $now))' "$USER_DB" > tmp.json
    mv tmp.json "$USER_DB"
    
    if [ ${#expired_users[@]} -gt 0 ]; then
        systemctl restart "$SERVICE_NAME" >/dev/null
        echo -e "\033[1;31m✗ Usuarios expirados eliminados:\033[0m"
        for user in "${expired_users[@]}"; do
            echo " • $user"
        done
    else
        echo -e "\033[1;32m✓ No se encontraron usuarios expirados.\033[0m"
    fi
    
    read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
}

# Ver registro de actividad
view_log() {
    clear_screen
    echo -e "\033[1;34m[ REGISTRO DE ACTIVIDAD ]\033[0m\n"
    
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo "No hay registros de actividad."
    fi
    
    read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
}

# Desinstalar el sistema
uninstall_system() {
    clear_screen
    echo -e "\033[1;31m[ DESINSTALAR SISTEMA ]\033[0m\n"
    
    read -p "¿Está seguro que desea desinstalar el sistema de gestión? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[SsYy]$ ]]; then
        return
    fi
    
    echo -e "\nDescargando desinstalador..."
    temp_file=$(mktemp)
    wget -q "$UNINSTALLER_URL" -O "$temp_file"
    
    if [ $? -ne 0 ]; then
        echo -e "\n\033[1;31mError: No se pudo descargar el desinstalador\033[0m"
        read -n 1 -s -r -p $'\n\nPresione cualquier tecla para continuar...'
        return
    fi
    
    chmod +x "$temp_file"
    echo -e "\n\033[1;32m✓ Desinstalador descargado correctamente\033[0m"
    echo "Ejecutando desinstalación..."
    
    # Ejecutar desinstalador y salir
    exec "$temp_file"
}

# Menú principal
main_menu() {
    init_system
    
    while true; do
        clear_screen
        echo "1) Agregar nuevo usuario"
        echo "2) Listar usuarios existentes"
        echo "3) Eliminar usuario"
        echo "4) Verificar expiraciones ahora"
        echo "5) Ver registro de actividad"
        echo "6) Desinstalar sistema"
        echo "7) Salir"
        echo -n $'\nSeleccione una opción: '
        
        read choice
        case $choice in
            1) add_user ;;
            2) list_users ;;
            3) remove_user ;;
            4) check_expirations ;;
            5) view_log ;;
            6) uninstall_system ;;
            7) exit 0 ;;
            *) 
                echo -e "\n\033[1;31mOpción inválida!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Manejar argumentos CLI
case "$1" in
    --add) add_user ;;
    --list) list_users ;;
    --remove) remove_user ;;
    --check) check_expirations ;;
    --log) view_log ;;
    --uninstall) uninstall_system ;;
    *) main_menu ;;
esac
