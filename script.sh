#!/bin/bash
set -e

touch md5.sum

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Número de parámetros incorrecto. Ejemplo:"
  echo "$0 X1234567X 500001 2015"
  echo "$0 X1234567X 500001 2015 1"
  exit 1
fi

nie=$1
num=$2
year=$3
orden=$4

send_email() {

  # echo -e "$1" | ssmtp "miemail@gmail.com"
  echo -e "$1"
}


execute() {

curl --request GET \
  -s \
  --url https://sede.mjusticia.gob.es/eConsultas/inicioNacionalidad  \
  --cookie-jar nada.txt \
    >/dev/null


captcha=$(curl --request GET \
  -s \
  --url https://sede.mjusticia.gob.es/eConsultas/jcaptcha_image.action  \
  --cookie-jar nada.txt \
  --cookie nada.txt \
  --output - | \
convert \
  - \
  -fuzz 30% \
  +opaque "#0828cb" \
  -fill black \
  -threshold 45% \
  - | \
tesseract \
  - \
  stdout \
  -c tessedit_char_whitelist=abcdefghijklmnñopqrstuvwxyzáéíóú 2>/dev/null \
  | \
tr -d '\n')

for i in "${PIPESTATUS[@]}"; do
  if [[ $i -ne 0 ]]; then
    send_email "Error críticio en procesar el captcha"
    exit 1
  fi
done

# echo $captcha
#
# set -x

HTML=$(curl --request POST \
  -s \
  --url https://sede.mjusticia.gob.es/eConsultas/inicioNacionalidad  \
  -d "action%3AenviarDatosNacionalidad=Enviar&formuNac.codigoNieCompleto=$nie&formuNac.numOrden=$orden&formuNac.numero=$num&formuNac.yearSolicitud=$year&jCaptchaResponse=$captcha"  \
  --cookie-jar nada.txt \
  --cookie nada.txt)

rm nada.txt
}



execute
z=1
while echo "$HTML" | grep -qi "los siguientes errores"; do
  if [ $z -gt 20 ]; then
  	echo "Error. Más de 20 intentos sin resolver el captcha"
  	exit 1
  fi
  let z=$z+1
  echo "intento nº $z"
  execute
done

estado=$(echo "$HTML" | xmllint --html --xpath "//div[contains(@class, 'bloqueCampoTextoInformativo')]/p" - 2>/dev/null | sed -e 's/^[ \t]*//')
actual_md5=$(echo "$estado" | md5sum | awk '{print $1}')

# echo $actual_md5

if [[ ! $actual_md5 = $(cat md5.sum) ]]; then
    echo "BINGO"
    send_email "Subject: NACIONALIDAD\n\nAlgo ha cambiado... Revisa!.\nRaw Output:\n$estado"
    echo $actual_md5 > md5.sum
else
  echo "nop, nada..."
fi