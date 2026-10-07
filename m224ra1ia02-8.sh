#!/bin/bash

# Uso: sudo ./m04ra01ia02-8.sh jlsanchez M2iNX  no
# Uso: sudo ./m04ra01ia02-8.sh jlsanchez M2iNX  yes

HayError=1

if [ "$EUID" -ne 0 ]; then
      echo
      echo "❌ Este script debe ejecutarse como root con sudo delante...."
      echo "   -> Uso: sudo ./m04ra06ia01.sh jlsanchez M2iNX  yes/no"
      echo
      exit 1
fi

# Verificar que se pasaron exactamente 3 parámetros
if [ "$#" -ne 3 ]; then
    echo "❌ Error: Se requieren 3 parámetros: nomenclatura, grupo, enviar"
    exit 1
fi

# Asignar los parámetros
nomenclatura="$1"
#grupo="$2"
grupo=$(echo "$2" | tr '[:upper:]' '[:lower:]')
#enviar="$3"
enviar=$(echo "$3" | tr '[:upper:]' '[:lower:]')

# Validar grupo (2do parámetro)
case "$grupo" in
    m2in1|m2in2|m2in3)
        # válido
        ;;
    *)
        echo "❌ Error: El segundo parámetro (grupo) debe ser M2IN1, M2IN2 o M2IN3 (no sensible a mayúsculas)"
		exit 1
        ;;
esac

# Validar enviar (3er parámetro)
case "$enviar" in
    yes|no)
        # válido
        ;;
    *)
        echo "❌ Error: El tercer parámetro (enviar) debe ser 'Yes' o 'No' (no sensible a mayúsculas)"
		exit 1
        ;;
esac

#Requisitos
echo "Comprobando requisitos.... Ten paciencia"
sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y jq >/dev/null 2>&1

# Validar hostname
hostname_actual=$(hostname)
hostname_esperado="usrv-$nomenclatura"

if [ "$hostname_actual" != "$hostname_esperado" ]; then
    echo "❌ Error: El hostname actual es '$hostname_actual', pero se esperaba '$hostname_esperado'"
    HayError=0
fi

interfaz_principal=$(ip route | awk '/default/ {print $5}' | head -n 1)
interfaz_principal=$(echo "$interfaz_principal" | tr '[:upper:]' '[:lower:]')

if [ -z "$interfaz_principal" ]; then
    echo "❌ Error: No se pudo determinar la interfaz principal Departa."
    exit 1
    #HayError=0
fi

if [ "$interfaz_principal" == "departa" ]; then
    echo "✅ Interface princial Departa detectada"
else
    echo "❌ Interface principal se llama $interfaz_principal, y debe llamarse Departa"
    exit 1
fi

#static 
if ip route | grep default | grep -q "proto static"; then
    echo "✅ Todo bien: El ordenador está configurado con IP estática."
else
    echo "❌ Error: Servidor configurado por DHCP."
    HayError=0
    exit 1
fi


linea=$(ip addr show departa | grep -i inet)

# echo $linea

# Extraer la IP/máscara
ip_con_mascara=$(echo "$linea" | grep -oP 'inet \K[\d.]+/\d+')

# Separar IP y máscara
ip=${ip_con_mascara%/*}
mascara=${ip_con_mascara#*/}

# Mostrar resultados
echo "    Datos IP"
echo "================="
echo "IP: $ip"
echo "Máscara: $mascara"
echo "Gateway: $(ip route | awk '/default/ {print $3}' | head -n 1)"

# Extraer los tres primeros octetos de la IP
# primeros_octetos=$(echo "$ip" | cut -d '.' -f 1-2)
echo
if [[ "${ip:0:6}" == "10.0.1" ]]; then
   echo "✅ La IP $ip es correcdta"
else
   echo "❌ La IP no pertenece al rango de tu clase"
   echo "   M2IN1: 10.0.13.X"
   echo "   M2IN1: 10.0.14.X"
   echo "   M2IN1: 10.0.15.X"
   HayError=0
fi
echo
# Comprobaciones
if [[ "$mascara" == "20" ]]; then
    echo "✅ Máscara IP correcta."
else
    echo "❌ Error: IP o máscara no válidas"
    echo "   El valor correcto es /20 o 255.255.240.0"
    HayError=0
fi



# Dominio a comprobar
DOMINIO="salesians.cat"

echo "🔍 Comprobando resolución DNS para: $DOMINIO"

# Usar getent (consulta según nsswitch.conf, respetando /etc/resolv.conf)
if getent hosts "$DOMINIO" >/dev/null 2>&1; then
    ip2=$(getent hosts "$DOMINIO" | awk '{print $1}')
    echo "✅ Resolución DNS exitosa. IP: $ip2"
else
    echo "❌ No se pudo resolver el dominio $DOMINIO"
    HayError=0
fi

echo "🔍 Comprobando si IPv6 está deshabilitado..."

# Comprobar si está deshabilitado globalmente
global_disable=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
default_disable=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)

DOMINIO="salesians.cat"

echo "🔍 Comprobando resolución DNS para $DOMINIO..."
if ! getent hosts "$DOMINIO" >/dev/null 2>&1; then
    echo "❌ No se pudo resolver el dominio $DOMINIO (Fallo DNS)"
    HayError=0
else
    echo "✅ Resolución DNS exitosa"
fi

echo "🌐 Comprobando conectividad a $DOMINIO (ping)..."
if ping -c 2 -W 2 "$DOMINIO" >/dev/null 2>&1; then
    echo "✅ Conectividad a $DOMINIO confirmada (ping exitoso)"
else
    echo "❌ No hay conectividad con $DOMINIO (ping fallido)"
    HayError=0
fi

# Comprobar si alguna interfaz tiene una dirección IPv6 asignada
if ip -6 addr show | grep -q 'inet6'; then
    echo "❌ Se encontraron direcciones IPv6 activas en las interfaces:"
    ip -6 addr show | grep 'inet6' | sed 's/^/   /'
    HayError=0
else
    echo "✅ No hay direcciones IPv6 activas en las interfaces"
fi

echo
echo "Comprobando la instalación de los paquetes.... "
paquetes=("tree" "nmap" "mc" "htop" "curl" "wget" "ncdu" "bat" "figlet")

for pkg in "${paquetes[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "✅ $pkg está instalado"
    else
        echo "❌ $pkg NO está instalado"
	HayError=0
    fi
done

echo
echo "Comprobando que paquetes lolcat, sl y coway están desinstalados.... "
paquetes=("lolcat" "sl" "coway")

for pkg in "${paquetes[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "❌  $pkg está instalado"
        HayError=0
    else
        echo "✅ $pkg NO está instalado"
    fi
done

TextoEnviar="Grupo: [$grupo] Checker: [m04ra01ia02-8] Alumne: [$nomenclatura] Data:$(date)"

echo
if [ $HayError == 0 ]; then
    echo "❌ Hay errores de configuración. Revisa todo bien!!!"
    exit 1
fi

if [ $enviar == "no" ]; then
    echo
    echo "✅ No hay errores :-) Puedes enviar la validación especificando yes en el tercer parámetro"
else
    echo "✅ Enviando el checker a la plataforma de validación."
    osversion=$(lsb_release -ds 2>/dev/null || grep -oP '(?<=^PRETTY_NAME=")[^"]*' /etc/os-release 2>/dev/null || uname -sr)
    fecha=$(date "+%Y-%m-%d %H:%M:%S")
    id="M224RA1IA02-8"
    hoja="RA1-IA02"
    WEBHOOK_URL="https://script.google.com/macros/s/AKfycbyKn1Lc3tAaWCZSgycfQYMsYol00hAYZee3nhW_Uayq_v5OEfdoyp4NSa5VCALTxtAT/exec"
	bodyData=$(jq -n \
      --arg nomenclatura "$nomenclatura" \
      --arg curso "$grupo" \
      --arg texto "$osversion  ip:$ip  mask:$mascara" \
      --arg fecha "$fecha" \
      --arg id "$id" \
      --arg hoja "$hoja" \
    '{
         nomenclatura: $nomenclatura,
         curso: $curso,
         texto: $texto,
         fecha: $fecha,
         id: $id,
         hoja: $hoja
    }')

    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "$bodyData")
      
      echo

      # Google Apps Script responde con 302 al procesar correctamente el doPost()
      if [[ "$response" -eq 200 || "$response" -eq 302 ]]; then
         echo "✅ Mensaje enviado correctamente a Microsoft Teams (HTTP $response)"
      else
         echo "❌ Error al enviar el mensaje a Teams (HTTP $response)"
         echo "Código HTTP recibido: $response"
      fi
fi

