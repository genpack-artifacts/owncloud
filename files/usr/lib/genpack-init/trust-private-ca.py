import os,subprocess,logging

CA_CERT = '/usr/local/share/ca-certificates/ca.crt'

def configure(ini):
    nssdb_dir = "/root/.pki/nssdb"
    if os.path.exists(nssdb_dir): return
    #else
    os.makedirs(nssdb_dir, exist_ok=True)
    subprocess.run([
        'certutil', '-d', f'sql:{nssdb_dir}', '-A', '-t', 'C,,', '-n', 'MyCA', '-i', CA_CERT
    ], check=True)
    logging.info(f'CA certificate added to NSS database for user root at {nssdb_dir}')
