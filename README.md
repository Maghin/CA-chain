# Autorité de certification SSL, autorité intermédiaire et certificats HTTPS
source : https://jamielinux.com/docs/openssl-certificate-authority/

# Create the root pair
Acting as a certificate authority (CA) means dealing with cryptographic pairs of private keys and public certificates. The very first cryptographic pair we’ll create is the root pair. This consists of the root key (ca.key.pem) and root certificate (ca.cert.pem). This pair forms the identity of your CA.

Typically, the root CA does not sign server or client certificates directly. The root CA is only ever used to create one or more intermediate CAs, which are trusted by the root CA to sign certificates on their behalf. This is best practice. It allows the root key to be kept offline and unused as much as possible, as any compromise of the root key is disastrous.

Note

It’s best practice to create the root pair in a secure environment. Ideally, this should be on a fully encrypted, air gapped computer that is permanently isolated from the Internet. Remove the wireless card and fill the ethernet port with glue.
## Prepare the directory
Choose a directory (/root/ca) to store all keys and certificates.
```
# mkdir /root/ca
```
Create the directory structure. The index.txt and serial files act as a flat file database to keep track of signed certificates.
```
# cd /root/ca
# mkdir certs crl newcerts private
# chmod 700 private
# touch index.txt
# echo 1000 > serial
```
## Prepare the configuration file
You must create a configuration file for OpenSSL to use. Copy the root CA configuration file from the Appendix to /root/ca/openssl.cnf.

The ```[ ca ]``` section is mandatory. Here we tell OpenSSL to use the options from the [ CA_default ] section.
```
[ ca ]
# `man ca`
default_ca = CA_default
```
The [ CA_default ] section contains a range of defaults. Make sure you declare the directory you chose earlier (/root/ca).
```
[ CA_default ]
# Directory and file locations.
dir               = /root/ca
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The root key and root certificate.
private_key       = $dir/private/ca.key.pem
certificate       = $dir/certs/ca.cert.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict
```
We’ll apply policy_strict for all root CA signatures, as the root CA is only being used to create intermediate CAs.
```
[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
```
We’ll apply policy_loose for all intermediate CA signatures, as the intermediate CA is signing server and client certificates that may come from a variety of third-parties.
```
[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the `ca` man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
```
Options from the [ req ] section are applied when creating certificates or certificate signing requests.
```
[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca
```
The [ req_distinguished_name ] section declares the information normally required in a certificate signing request. You can optionally specify some defaults.
```
[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = GB
stateOrProvinceName_default     = England
localityName_default            =
0.organizationName_default      = Alice Ltd
#organizationalUnitName_default =
#emailAddress_default           =
```
The next few sections are extensions that can be applied when signing certificates. For example, passing the -extensions v3_ca command-line argument will apply the options set in [ v3_ca ].

We’ll apply the v3_ca extension when we create the root certificate.
```
[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```
We’ll apply the v3_ca_intermediate extension when we create the intermediate certificate. pathlen:0 ensures that there can be no further certificate authorities below the intermediate CA.
```
[ v3_intermediate_ca ]
# Extensions for a typical intermediate CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```
We’ll apply the usr_cert extension when signing client certificates, such as those used for remote user authentication.
```
[ usr_cert ]
# Extensions for client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
```
We’ll apply the server_cert extension when signing server certificates, such as those used for web servers.
```
[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
```
The crl_ext extension is automatically applied when creating certificate revocation lists.
```
[ crl_ext ]
# Extension for CRLs (`man x509v3_config`).
authorityKeyIdentifier=keyid:always
```
We’ll apply the ocsp extension when signing the Online Certificate Status Protocol (OCSP) certificate.
```
[ ocsp ]
# Extension for OCSP signing certificates (`man ocsp`).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```
## Create the root key

Create the root key (ca.key.pem) and keep it absolutely secure. Anyone in possession of the root key can issue trusted certificates. Encrypt the root key with AES 256-bit encryption and a strong password.

Note

Use 4096 bits for all root and intermediate certificate authority keys. You’ll still be able to sign server and client certificates of a shorter length.
```
# cd /root/ca
# openssl genrsa -aes256 -out private/ca.key.pem 4096
```
Enter pass phrase for ca.key.pem: secretpassword
Verifying - Enter pass phrase for ca.key.pem: secretpassword
```
# chmod 400 private/ca.key.pem
```
## Create the root certificate
Use the root key (ca.key.pem) to create a root certificate (ca.cert.pem). Give the root certificate a long expiry date, such as twenty years. Once the root certificate expires, all certificates signed by the CA become invalid.

Warning

Whenever you use the req tool, you must specify a configuration file to use with the -config option, otherwise OpenSSL will default to /etc/pki/tls/openssl.cnf.
```
# cd /root/ca
# openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem

Enter pass phrase for ca.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:GB
State or Province Name []:England
Locality Name []:
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Certificate Authority
Common Name []:Alice Ltd Root CA
Email Address []:

# chmod 444 certs/ca.cert.pem
```
## Verify the root certificate
```
# openssl x509 -noout -text -in certs/ca.cert.pem
```
The output shows:

    the Signature Algorithm used
    the dates of certificate Validity
    the Public-Key bit length
    the Issuer, which is the entity that signed the certificate
    the Subject, which refers to the certificate itself

The Issuer and Subject are identical as the certificate is self-signed. Note that all root certificates are self-signed.
```
Signature Algorithm: sha256WithRSAEncryption
    Issuer: C=GB, ST=England,
            O=Alice Ltd, OU=Alice Ltd Certificate Authority,
            CN=Alice Ltd Root CA
    Validity
        Not Before: Apr 11 12:22:58 2015 GMT
        Not After : Apr  6 12:22:58 2035 GMT
    Subject: C=GB, ST=England,
             O=Alice Ltd, OU=Alice Ltd Certificate Authority,
             CN=Alice Ltd Root CA
    Subject Public Key Info:
        Public Key Algorithm: rsaEncryption
            Public-Key: (4096 bit)
```
The output also shows the X509v3 extensions. We applied the v3_ca extension, so the options from [ v3_ca ] should be reflected in the output.
```
X509v3 extensions:
    X509v3 Subject Key Identifier:
        38:58:29:2F:6B:57:79:4F:39:FD:32:35:60:74:92:60:6E:E8:2A:31
    X509v3 Authority Key Identifier:
        keyid:38:58:29:2F:6B:57:79:4F:39:FD:32:35:60:74:92:60:6E:E8:2A:31

    X509v3 Basic Constraints: critical
        CA:TRUE
    X509v3 Key Usage: critical
        Digital Signature, Certificate Sign, CRL Sign
```
#Create the intermediate pair
An intermediate certificate authority (CA) is an entity that can sign certificates on behalf of the root CA. The root CA signs the intermediate certificate, forming a chain of trust.

The purpose of using an intermediate CA is primarily for security. The root key can be kept offline and used as infrequently as possible. If the intermediate key is compromised, the root CA can revoke the intermediate certificate and create a new intermediate cryptographic pair.
## Prepare the directory

The root CA files are kept in /root/ca. Choose a different directory (/root/ca/intermediate) to store the intermediate CA files.
```
# mkdir /root/ca/intermediate
```
Create the same directory structure used for the root CA files. It’s convenient to also create a csr directory to hold certificate signing requests.
```
# cd /root/ca/intermediate
# mkdir certs crl csr newcerts private
# chmod 700 private
# touch index.txt
# echo 1000 > serial
```
Add a crlnumber file to the intermediate CA directory tree. crlnumber is used to keep track of certificate revocation lists.
```
# echo 1000 > /root/ca/intermediate/crlnumber
```
Copy the intermediate CA configuration file from the Appendix to /root/ca/intermediate/openssl.cnf. Five options have been changed compared to the root CA configuration file:
```
[ CA_default ]
dir             = /root/ca/intermediate
private_key     = $dir/private/intermediate.key.pem
certificate     = $dir/certs/intermediate.cert.pem
crl             = $dir/crl/intermediate.crl.pem
policy          = policy_loose
```
## Create the intermediate key
Create the intermediate key (intermediate.key.pem). Encrypt the intermediate key with AES 256-bit encryption and a strong password.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/intermediate.key.pem 4096

Enter pass phrase for intermediate.key.pem: secretpassword
Verifying - Enter pass phrase for intermediate.key.pem: secretpassword

# chmod 400 intermediate/private/intermediate.key.pem
```
## Create the intermediate certificate
Use the intermediate key to create a certificate signing request (CSR). The details should generally match the root CA. The Common Name, however, must be different.

Warning

Make sure you specify the intermediate CA configuration file (intermediate/openssl.cnf).
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -out intermediate/csr/intermediate.csr.pem

Enter pass phrase for intermediate.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:GB
State or Province Name []:England
Locality Name []:
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Certificate Authority
Common Name []:Alice Ltd Intermediate CA
Email Address []:
```
To create an intermediate certificate, use the root CA with the v3_intermediate_ca extension to sign the intermediate CSR. The intermediate certificate should be valid for a shorter period than the root certificate. Ten years would be reasonable.

Warning

This time, specify the root CA configuration file (/root/ca/openssl.cnf).
```
# cd /root/ca
# openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem

Enter pass phrase for ca.key.pem: secretpassword
Sign the certificate? [y/n]: y

# chmod 444 intermediate/certs/intermediate.cert.pem
```
The index.txt file is where the OpenSSL ca tool stores the certificate database. Do not delete or edit this file by hand. It should now contain a line that refers to the intermediate certificate.
```
V 250408122707Z 1000 unknown ... /CN=Alice Ltd Intermediate CA
```
## Verify the intermediate certificate
As we did for the root certificate, check that the details of the intermediate certificate are correct.
```
# openssl x509 -noout -text \
      -in intermediate/certs/intermediate.cert.pem
```
Verify the intermediate certificate against the root certificate. An OK indicates that the chain of trust is intact.
```
# openssl verify -CAfile certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem

intermediate.cert.pem: OK
```
## Create the certificate chain file
When an application (eg, a web browser) tries to verify a certificate signed by the intermediate CA, it must also verify the intermediate certificate against the root certificate. To complete the chain of trust, create a CA certificate chain to present to the application.

To create the CA certificate chain, concatenate the intermediate and root certificates together. We will use this file later to verify certificates signed by the intermediate CA.
```
# cat intermediate/certs/intermediate.cert.pem \
      certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem
# chmod 444 intermediate/certs/ca-chain.cert.pem
```
Note

Our certificate chain file must include the root certificate because no client application knows about it yet. A better option, particularly if you’re administrating an intranet, is to install your root certificate on every client that needs to connect. In that case, the chain file need only contain your intermediate certificate.
# Sign server and client certificates
We will be signing certificates using our intermediate CA. You can use these signed certificates in a variety of situations, such as to secure connections to a web server or to authenticate clients connecting to a service.

Note

The steps below are from your perspective as the certificate authority. A third-party, however, can instead create their own private key and certificate signing request (CSR) without revealing their private key to you. They give you their CSR, and you give back a signed certificate. In that scenario, skip the genrsa and req commands.
## Create a key
Our root and intermediate pairs are 4096 bits. Server and client certificates normally expire after one year, so we can safely use 2048 bits instead.

Note

Although 4096 bits is slightly more secure than 2048 bits, it slows down TLS handshakes and significantly increases processor load during handshakes. For this reason, most websites use 2048-bit pairs.

If you’re creating a cryptographic pair for use with a web server (eg, Apache), you’ll need to enter this password every time you restart the web server. You may want to omit the -aes256 option to create a key without a password.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/www.example.com.key.pem 2048
# chmod 400 intermediate/private/www.example.com.key.pem
```
## Create a certificate
Use the private key to create a certificate signing request (CSR). The CSR details don’t need to match the intermediate CA. For server certificates, the Common Name must be a fully qualified domain name (eg, www.example.com), whereas for client certificates it can be any unique identifier (eg, an e-mail address). Note that the Common Name cannot be the same as either your root or intermediate certificate.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/www.example.com.key.pem \
      -new -sha256 -out intermediate/csr/www.example.com.csr.pem

Enter pass phrase for www.example.com.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:www.example.com
Email Address []:
```
To create a certificate, use the intermediate CA to sign the CSR. If the certificate is going to be used on a server, use the server_cert extension. If the certificate is going to be used for user authentication, use the usr_cert extension. Certificates are usually given a validity of one year, though a CA will typically give a few days extra for convenience.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions server_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/www.example.com.csr.pem \
      -out intermediate/certs/www.example.com.cert.pem
# chmod 444 intermediate/certs/www.example.com.cert.pem
```
The intermediate/index.txt file should contain a line referring to this new certificate.
```
V 160420124233Z 1000 unknown ... /CN=www.example.com
```
## Verify the certificate
```
# openssl x509 -noout -text \
      -in intermediate/certs/www.example.com.cert.pem
```
The Issuer is the intermediate CA. The Subject refers to the certificate itself.
```
Signature Algorithm: sha256WithRSAEncryption
    Issuer: C=GB, ST=England,
            O=Alice Ltd, OU=Alice Ltd Certificate Authority,
            CN=Alice Ltd Intermediate CA
    Validity
        Not Before: Apr 11 12:42:33 2015 GMT
        Not After : Apr 20 12:42:33 2016 GMT
    Subject: C=US, ST=California, L=Mountain View,
             O=Alice Ltd, OU=Alice Ltd Web Services,
             CN=www.example.com
    Subject Public Key Info:
        Public Key Algorithm: rsaEncryption
            Public-Key: (2048 bit)
```
The output will also show the X509v3 extensions. When creating the certificate, you used either the server_cert or usr_cert extension. The options from the corresponding configuration section will be reflected in the output.
```
X509v3 extensions:
    X509v3 Basic Constraints:
        CA:FALSE
    Netscape Cert Type:
        SSL Server
    Netscape Comment:
        OpenSSL Generated Server Certificate
    X509v3 Subject Key Identifier:
        B1:B8:88:48:64:B7:45:52:21:CC:35:37:9E:24:50:EE:AD:58:02:B5
    X509v3 Authority Key Identifier:
        keyid:69:E8:EC:54:7F:25:23:60:E5:B6:E7:72:61:F1:D4:B9:21:D4:45:E9
        DirName:/C=GB/ST=England/O=Alice Ltd/OU=Alice Ltd Certificate Authority/CN=Alice Ltd Root CA
        serial:10:00

    X509v3 Key Usage: critical
        Digital Signature, Key Encipherment
    X509v3 Extended Key Usage:
        TLS Web Server Authentication
```
Use the CA certificate chain file we created earlier (ca-chain.cert.pem) to verify that the new certificate has a valid chain of trust.
```
# openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
      intermediate/certs/www.example.com.cert.pem

www.example.com.cert.pem: OK
```
## Deploy the certificate
You can now either deploy your new certificate to a server, or distribute the certificate to a client. When deploying to a server application (eg, Apache), you need to make the following files available:

- ca-chain.cert.pem
- www.example.com.key.pem
- www.example.com.cert.pem

If you’re signing a CSR from a third-party, you don’t have access to their private key so you only need to give them back the chain file (ca-chain.cert.pem) and the certificate (www.example.com.cert.pem).

# Certificate revocation lists
A certificate revocation list (CRL) provides a list of certificates that have been revoked. A client application, such as a web browser, can use a CRL to check a server’s authenticity. A server application, such as Apache or OpenVPN, can use a CRL to deny access to clients that are no longer trusted.

Publish the CRL at a publicly accessible location (eg, http://example.com/intermediate.crl.pem). Third-parties can fetch the CRL from this location to check whether any certificates they rely on have been revoked.

Note

Some applications vendors have deprecated CRLs and are instead using the Online Certificate Status Protocol (OCSP).
## Prepare the configuration file
When a certificate authority signs a certificate, it will normally encode the CRL location into the certificate. Add crlDistributionPoints to the appropriate sections. In our case, add it to the [ server_cert ] section.
```
[ server_cert ]
# ... snipped ...
crlDistributionPoints = URI:http://example.com/intermediate.crl.pem
```
## Create the CRL
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -gencrl -out intermediate/crl/intermediate.crl.pem
```
Note

The CRL OPTIONS section of the ca man page contains more information on how to create CRLs.

You can check the contents of the CRL with the crl tool.
```
# openssl crl -in intermediate/crl/intermediate.crl.pem -noout -text
```
No certificates have been revoked yet, so the output will state No Revoked Certificates.

You should re-create the CRL at regular intervals. By default, the CRL expires after 30 days. This is controlled by the default_crl_days option in the [ CA_default ] section.
## Revoke a certificate
Let’s walk through an example. Alice is running the Apache web server and has a private folder of heart-meltingly cute kitten pictures. Alice wants to grant her friend, Bob, access to this collection.

Bob creates a private key and certificate signing request (CSR).
```
$ cd /home/bob
$ openssl genrsa -out bob@example.com.key.pem 2048
$ openssl req -new -key bob@example.com.key.pem \
      -out bob@example.com.csr.pem

You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name [XX]:US
State or Province Name []:California
Locality Name []:San Francisco
Organization Name []:Bob Ltd
Organizational Unit Name []:
Common Name []:bob@example.com
Email Address []:
```
Bob sends his CSR to Alice, who then signs it.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions usr_cert -notext -md sha256 \
      -in intermediate/csr/bob@example.com.csr.pem \
      -out intermediate/certs/bob@example.com.cert.pem

Sign the certificate? [y/n]: y
1 out of 1 certificate requests certified, commit? [y/n]: y

Alice verifies that the certificate is valid:

# openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
      intermediate/certs/bob@example.com.cert.pem

bob@example.com.cert.pem: OK
```
The index.txt file should contain a new entry.
```
V 160420124740Z 1001 unknown ... /CN=bob@example.com
```
Alice sends Bob the signed certificate. Bob installs the certificate in his web browser and is now able to access Alice’s kitten pictures. Hurray!

Sadly, it turns out that Bob is misbehaving. Bob has posted Alice’s kitten pictures to Hacker News, claiming that they’re his own and gaining huge popularity. Alice finds out and needs to revoke his access immediately.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -revoke intermediate/certs/bob@example.com.cert.pem

Enter pass phrase for intermediate.key.pem: secretpassword
Revoking Certificate 1001.
Data Base Updated
```
The line in index.txt that corresponds to Bob’s certificate now begins with the character R. This means the certificate has been revoked.
```
R 160420124740Z 150411125310Z 1001 unknown ... /CN=bob@example.com
```
After revoking Bob’s certificate, Alice must re-create the CRL.
## Server-side use of the CRL
For client certificates, it’s typically a server-side application (eg, Apache) that is doing the verification. This application needs to have local access to the CRL.

In Alice’s case, she can add the SSLCARevocationPath directive to her Apache configuration and copy the CRL to her web server. The next time that Bob connects to the web server, Apache will check his client certificate against the CRL and deny access.

Similarly, OpenVPN has a crl-verify directive so that it can block clients that have had their certificates revoked.
## Client-side use of the CRL
For server certificates, it’s typically a client-side application (eg, a web browser) that performs the verification. This application must have remote access to the CRL.

If a certificate was signed with an extension that includes crlDistributionPoints, a client-side application can read this information and fetch the CRL from the specified location.

The CRL distribution points are visible in the certificate X509v3 details.
```
# openssl x509 -in cute-kitten-pictures.example.com.cert.pem -noout -text

    X509v3 CRL Distribution Points:

        Full Name:
          URI:http://example.com/intermediate.crl.pem
```

