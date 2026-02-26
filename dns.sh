#!/bin/bash
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/mytcpip/urepo/refs/heads/main/urepo.sh)"
# Script interactivo para verificar resolución DNS

# -----------------------------
# Función para validar IPv4
# -----------------------------
validar_ipv4() {
    local ip=$1
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi

    IFS='.' read -r -a octetos <<< "$ip"
    for octeto in "${octetos[@]}"; do
        if (( octeto < 0 || octeto > 255 )); then
            return 1
        fi
    done
    return 0
}

# -----------------------------
# Función para validar dominio
# -----------------------------
validar_dominio() {
    local dominio=$1
    local regex="^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$"
    if [[ $dominio =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

# -----------------------------
# Función para verificar nslookup
# -----------------------------
verificar_nslookup() {
    local host=$1
    local dns=$2

    if nslookup "$host" "$dns" >/dev/null 2>&1; then
        echo "[OK] $host se resolvió correctamente usando $dns"
        return 0
    else
        echo "[ERROR] No se pudo resolver $host usando $dns"
        return 1
    fi
}

# -----------------------------
# Pedir IP y dominio por teclado
# -----------------------------
read -p "Introduce la IP del servidor DNS: " IP_DNS
while ! validar_ipv4 "$IP_DNS"; do
    echo "[ERROR] La IP '$IP_DNS' no es válida. Intenta nuevamente."
    read -p "Introduce la IP del servidor DNS: " IP_DNS
done

read -p "Introduce el dominio: " DOMINIO
while ! validar_dominio "$DOMINIO"; do
    echo "[ERROR] El dominio '$DOMINIO' no es válido. Intenta nuevamente."
    read -p "Introduce el dominio: " DOMINIO
done

# -----------------------------
# Verificaciones nslookup
# -----------------------------
echo -e "\nVerificando servidor DNS $IP_DNS...\n"

declare -A resultados

# Lista de hosts a verificar
hosts=("www.google.com" "www.$DOMINIO" "rdp.$DOMINIO")

for host in "${hosts[@]}"; do
    if verificar_nslookup "$host" "$IP_DNS"; then
        resultados["$host"]="OK"
    else
        resultados["$host"]="ERROR"
    fi
done

# -----------------------------
# Resumen final
# -----------------------------
echo -e "\nResumen final de resoluciones:"
for host in "${hosts[@]}"; do
    echo "$host : ${resultados[$host]}"
done
