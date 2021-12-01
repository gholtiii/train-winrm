#!/bin/bash

set -e

# Note the requirements for the UPN: In Windows Active Directory, a User Principal Name (UPN) is the name of a
# system user in an email address format.  A UPN (for example: john.doe@domain.com) consists of the user name
# (login name), separator (the @ symbol) and the domain name (UPN suffix)
USER_NAME=vagrant
UPN=$USER_NAME@localhost
SUBJECT="/CN=$USER_NAME"

BASE_PATH=`pwd`
USER_PATH=${BASE_PATH}/user.pem
KEY_PATH=${BASE_PATH}/key.pem
PFX_PATH=${BASE_PATH}/user.pfx

EXT_CONF_FILE=openssl.conf

KEY_FILE=$PRIVATE_DIR/cert.key

cat > $EXT_CONF_FILE <<EOF
distinguished_name  = req_distinguished_name
[req_distinguished_name]
[v3_req_client]
extendedKeyUsage = clientAuth
subjectAltName = otherName:1.3.6.1.4.1.311.20.2.3;UTF8:$UPN
EOF

export OPENSSL_CONF=$EXT_CONF_FILE

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out ${USER_PATH} -outform PEM -keyout ${KEY_PATH} -subj "$SUBJECT" -extensions v3_req_client 2>&1

openssl pkcs12 -export -in ${USER_PATH} -inkey ${KEY_PATH} -out ${PFX_PATH} -passout pass: 2>&1

THUMBPRINT=`openssl x509 -inform PEM -in "${USER_PATH}" -fingerprint -noout | \
sed -e 's/\://g' | sed -n 's/^.*=\(.*\)$/\1/p'`

echo "Certificate Thumbprint: $THUMBPRINT" > ${BASE_PATH}/THUMBPRINT
cat ${BASE_PATH}/THUMBPRINT
