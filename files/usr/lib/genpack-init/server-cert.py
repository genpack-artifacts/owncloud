import os,subprocess,logging

CA_KEY = '/etc/ssl/private/ca.key'
CA_CERT = '/usr/local/share/ca-certificates/ca.crt'

SERVER_KEY = '/etc/ssl/private/localhost.key'
SERVER_CERT = '/etc/ssl/certs/localhost.crt'

CN = "localhost"
ALT_NAMES = "DNS:localhost"
#ALT_NAMES = "DNS:localhost,DNS:othername.localhost"

def configure(ini):
    if os.path.exists(SERVER_CERT): return
    #else
    subprocess.run([
        'openssl', 'genrsa', '-out', SERVER_KEY, '2048'
    ], check=True)
    req = subprocess.run([
        'openssl', 'req', '-new', '-key', SERVER_KEY,
        '-subj', f'/CN={CN}',
        '-addext', f'subjectAltName={ALT_NAMES}'
    ], check=True, capture_output=True)
    csr = req.stdout

    subprocess.run([
        'openssl', 'x509', '-req', '-CA', CA_CERT, '-CAkey', CA_KEY,
        '-CAcreateserial', '-out', SERVER_CERT, '-days', '3650',
        '-copy_extensions', 'copy'
    ], check=True, input=csr)
    logging.info(f"Server certificate {SERVER_CERT} created.")