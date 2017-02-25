#!/bin/bash

# generate intermediate ca key
openssl genrsa -aes256 \
      -out intermediate/private/intermediate.key.pem 4096
chmod 400 intermediate/private/intermediate.key.pem

# generate intermediate certificate signing request
openssl req -config intermediate/openssl.cnf -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -out intermediate/csr/intermediate.csr.pem

# sign intermediate CSR with CA key
openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem
chmod 444 intermediate/certs/intermediate.cert.pem

# view intermediate CA certificate
openssl x509 -noout -text \
      -in intermediate/certs/intermediate.cert.pem

# verify intermediate CA certificate
openssl verify -CAfile certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem

# create cert chainfile
cat intermediate/certs/intermediate.cert.pem \
      certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem
chmod 444 intermediate/certs/ca-chain.cert.pem

exit 0
