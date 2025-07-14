import os,subprocess,logging

CA_KEY = '/etc/ssl/private/ca.key'
CA_CERT = '/usr/local/share/ca-certificates/ca.crt'

def configure(ini):
    if not os.path.exists(CA_CERT):
        os.makedirs(os.path.dirname(CA_CERT), exist_ok=True)
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:4096',
            '-keyout', CA_KEY, '-out', CA_CERT, '-days', '3650',
            '-nodes', '-subj', '/C=JP/ST=Tokyo/O=WBRXCORP/CN=walbrix.com'
        ], check=True)
        subprocess.run(['update-ca-certificates'], check=True)
        logging.info(f"CA certificate {CA_CERT} created.")
