"""Run the callback against private TLS SLB and direct-Core HTTP servers."""
import http.server
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading
import unittest
from urllib.parse import parse_qs, urlsplit

MODULE = Path(__file__).resolve().parents[1] / 'usr/lib/jelastic/modules/vcs.module'


class CallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='je77294-callback-')
        cls.root = Path(cls.temp.name)
        cls.requests, cls.core_requests, cls.sni = [], [], []

        def handler(destination):
            class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    destination.append((self.headers.get('Host'), self.path))
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b'{"result":0}')
                def log_message(self, *_):
                    pass
            return Handler

        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
            '-subj', '/CN=app.test.invalid', '-addext', 'subjectAltName=DNS:app.test.invalid',
            '-keyout', str(cls.root / 'key.pem'), '-out', str(cls.root / 'cert.pem')],
            check=True, capture_output=True)
        cls.edge = http.server.ThreadingHTTPServer(('127.0.0.1', 443), handler(cls.requests))
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cls.root / 'cert.pem', cls.root / 'key.pem')
        context.set_servername_callback(lambda sock, name, ctx: cls.sni.append(name))
        cls.edge.socket = context.wrap_socket(cls.edge.socket, server_side=True)
        cls.core = http.server.ThreadingHTTPServer(('127.0.0.2', 80), handler(cls.core_requests))
        for server in [cls.edge, cls.core]:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        cls.curl = cls.root / 'curl'
        cls.curl.write_text('#!/bin/bash\nexec curl --noproxy "*" --max-time 3 '
                            '--resolve app.test.invalid:443:127.0.0.1 '
                            f'--cacert "{cls.root}/cert.pem" "$@"\n')
        cls.curl.chmod(0o755)

    @classmethod
    def tearDownClass(cls):
        for server in [cls.edge, cls.core]:
            server.shutdown()
            server.server_close()
        cls.temp.cleanup()

    def setUp(self):
        self.requests.clear()
        self.core_requests.clear()
        self.sni.clear()

    def invoke(self, last='', discovery='domain=test.invalid; CORE_ADDR=127.0.0.2; return 0'):
        script = r'''
inherit() { :; }
include() { :; }
PROGRAM=: AWK=awk DATA_OWNER=jelastic
source "$MODULE"
getLastRepoCommit() { printf new-revision; }
getInfraAddresses() { DISCOVERY; }
writeProjectConfig() { :; }
error() { printf '%s\n' "$*" >&2; }
CURL="$TEST_CURL"
JEM_CALLS_LOG="$TEST_LOG"
LAST_DEPLOYED_COMMIT="$LAST"
doCallProjectUpdate demo
'''.replace('DISCOVERY', discovery)
        env = dict(os.environ, MODULE=str(MODULE), TEST_CURL=str(self.curl),
                   TEST_LOG=str(self.root / 'callback.log'), LAST=last)
        return subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True, timeout=10)

    def test_builddeploy_uses_slb_domain_public_path_and_tls_identity(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.core_requests, [], 'Callback bypassed SLB and contacted Core directly')
        self.assertEqual(len(self.requests), 1)
        host, target = self.requests[0]
        self.assertEqual(host, 'app.test.invalid')
        self.assertEqual(self.sni, ['app.test.invalid'])
        self.assertEqual(urlsplit(target).path, '/1.0/env/build/rest/builddeploy')
        self.assertEqual(parse_qs(urlsplit(target).query),
                         {'appid': ['01234567890123456789012345678901'], 'projectName': ['demo']})

    def test_unchanged_revision_does_not_call_api(self):
        result = self.invoke(last='new-revision')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests, [])
        self.assertEqual(self.core_requests, [])

    def test_discovery_failure_does_not_use_cached_core_address(self):
        result = self.invoke(discovery='CORE_ADDR=127.0.0.2; domain=; return 1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.core_requests, [])
        self.assertEqual(self.requests, [])

    def test_slb_transport_failure_is_reported_without_direct_fallback(self):
        working = self.curl.read_text()
        self.curl.write_text(working.replace('443:127.0.0.1', '443:127.0.0.3'))
        try:
            result = self.invoke()
        finally:
            self.curl.write_text(working)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.core_requests, [])


if __name__ == '__main__':
    unittest.main()
