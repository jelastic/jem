"""Real curl/TLS through the owning Hcore route to a private BuildDeploy API."""
import http.server
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from urllib.parse import parse_qs, urlsplit

MODULE = Path(__file__).resolve().parents[1] / 'usr/lib/jelastic/modules/vcs.module'
PLATFORM = Path(os.environ.get('JE_PLATFORM_SOURCE', '/work/jelastic'))
HCORE = PLATFORM / 'dockers/infra/hcore-stage1/etc/jelastic/erb/usr/local/openresty/nginx/conf/conf.d/virtual_hivext.conf'


class CallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='je77294-callback-')
        cls.root = Path(cls.temp.name)
        cls.api_requests, cls.direct_requests, cls.fallback_requests = [], [], []
        cls.response_code, cls.response_body = 200, b'{"result":0}'

        def handler(destination, role):
            class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    destination.append((self.headers.get('Host'), self.path))
                    self.send_response(cls.response_code if role == 'api' else 404 if role == 'fallback' else 200)
                    self.end_headers()
                    self.wfile.write(cls.response_body if role == 'api' else b'{"result":0}')
                def log_message(self, *_):
                    pass
            return Handler

        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
            '-subj', '/CN=app.test.invalid', '-addext', 'subjectAltName=DNS:app.test.invalid',
            '-keyout', str(cls.root / 'key.pem'), '-out', str(cls.root / 'cert.pem')],
            check=True, capture_output=True)
        cls.servers = []
        for address, requests, role in [(('127.0.0.1', 18080), cls.api_requests, 'api'),
                                       (('127.0.0.2', 80), cls.direct_requests, 'direct'),
                                       (('127.0.0.1', 18081), cls.fallback_requests, 'fallback')]:
            server = http.server.ThreadingHTTPServer(address, handler(requests, role))
            threading.Thread(target=server.serve_forever, daemon=True).start()
            cls.servers.append(server)

        # Execute the production regex/proxy_pass rather than imitate routing.
        source = HCORE.read_text()
        start = source.index('    location ~ ^/1.0/environment/(.*) {')
        route = source[start:source.index('\n    }', start) + len('\n    }')]
        config = cls.root / 'nginx.conf'
        config.write_text(f'''
pid {cls.root}/nginx.pid;
error_log {cls.root}/nginx-error.log;
events {{ worker_connections 64; }}
http {{
    log_format probe '$http_host|$ssl_server_name|$request_uri';
    access_log {cls.root}/edge.log probe;
    server {{
        listen 127.0.0.1:443 ssl;
        ssl_certificate {cls.root}/cert.pem;
        ssl_certificate_key {cls.root}/key.pem;
        set $jelastic_ups 127.0.0.1:18080;
{route}
        location / {{ proxy_pass http://127.0.0.1:18081; }}
    }}
}}
''')
        cls.process = subprocess.Popen(['nginx', '-c', str(config), '-p', str(cls.root), '-g', 'daemon off;'],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            if cls.process.poll() is not None:
                raise RuntimeError((cls.root / 'nginx-error.log').read_text())
            try:
                socket.create_connection(('127.0.0.1', 443), timeout=.1).close()
                break
            except OSError:
                time.sleep(.02)
        else:
            raise RuntimeError('Private routing proxy did not start')
        cls.curl = cls.root / 'curl'
        cls.curl.write_text('#!/bin/bash\nexec curl --noproxy "*" --max-time 3 '
                            '--resolve app.test.invalid:443:127.0.0.1 '
                            f'--cacert "{cls.root}/cert.pem" "$@"\n')
        cls.curl.chmod(0o755)

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        cls.process.wait(timeout=10)
        for server in cls.servers:
            server.shutdown()
            server.server_close()
        cls.temp.cleanup()

    def setUp(self):
        self.reset_case()

    def reset_case(self):
        self.api_requests.clear()
        self.direct_requests.clear()
        self.fallback_requests.clear()
        self.__class__.response_code, self.__class__.response_body = 200, b'{"result":0}'
        (self.root / 'edge.log').write_text('')
        (self.root / 'state').unlink(missing_ok=True)

    def invoke(self, last=None, discovery='domain=test.invalid; CORE_ADDR=127.0.0.2; return 0'):
        if last is None:
            last = (self.root / 'state').read_text().strip() if (self.root / 'state').exists() else ''
        script = r'''
inherit() { :; }
include() { :; }
PROGRAM=: AWK=awk DATA_OWNER=jelastic
source "$MODULE"
getLastRepoCommit() { printf new-revision; }
getInfraAddresses() { DISCOVERY; }
writeProjectConfig() { printf '%s\n' "$LAST_DEPLOYED_COMMIT" >"$TEST_STATE"; }
error() { printf '%s\n' "$*" >&2; }
CURL="$TEST_CURL"
JQ=jq
JEM_CALLS_LOG="$TEST_LOG"
LAST_DEPLOYED_COMMIT="$LAST"
doCallProjectUpdate demo
'''.replace('DISCOVERY', discovery)
        env = dict(os.environ, MODULE=str(MODULE), TEST_CURL=str(self.curl),
                   TEST_LOG=str(self.root / 'callback.log'), TEST_STATE=str(self.root / 'state'), LAST=last)
        return subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True, timeout=10)

    def test_builddeploy_uses_slb_tls_and_real_environment_proxy_route(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.direct_requests, [], 'Callback contacted Core directly')
        self.assertEqual(self.fallback_requests, [], 'Callback fell through to the users upstream')
        self.assertEqual(len(self.api_requests), 1)
        _, target = self.api_requests[0]
        self.assertEqual(urlsplit(target).path, '/JElastic/environment/build/rest/builddeploy')
        self.assertEqual(parse_qs(urlsplit(target).query),
                         {'appid': ['01234567890123456789012345678901'], 'projectName': ['demo']})
        host, sni, uri = (self.root / 'edge.log').read_text().strip().split('|')
        self.assertEqual((host, sni), ('app.test.invalid', 'app.test.invalid'))
        self.assertEqual(urlsplit(uri).path, '/1.0/environment/build/rest/builddeploy')

    def test_unchanged_revision_does_not_call_api(self):
        self.assertEqual(self.invoke(last='new-revision').returncode, 0)
        self.assertEqual(self.api_requests + self.direct_requests + self.fallback_requests, [])

    def test_discovery_failure_does_not_use_cached_core_address(self):
        self.assertNotEqual(self.invoke(discovery='CORE_ADDR=127.0.0.2; domain=; return 1').returncode, 0)
        self.assertEqual(self.api_requests + self.direct_requests + self.fallback_requests, [])

    def test_slb_transport_failure_is_reported_without_direct_fallback(self):
        working = self.curl.read_text()
        self.curl.write_text(working.replace('443:127.0.0.1', '443:127.0.0.3'))
        try:
            result = self.invoke()
        finally:
            self.curl.write_text(working)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'state').exists())
        self.assertEqual(self.direct_requests, [])

    def assert_failed_revision_retries(self):
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / 'state').exists())
        self.__class__.response_code, self.__class__.response_body = 200, b'{"result":0}'
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(len(self.api_requests), 2)
        self.assertEqual((self.root / 'state').read_text().strip(), 'new-revision')
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(len(self.api_requests), 2)

    def test_http_errors_do_not_mark_revision_and_retry_same_commit(self):
        for status in [403, 502]:
            with self.subTest(status=status):
                self.reset_case()
                self.__class__.response_code = status
                self.assert_failed_revision_retries()

    def test_api_errors_or_invalid_json_do_not_mark_revision_and_retry_same_commit(self):
        for body in [b'{"result":1234}', b'not-json', b'{"nested":{"result":0},"result":1}',
                     b'{"result":0}{"result":0}']:
            with self.subTest(body=body):
                self.reset_case()
                self.__class__.response_body = body
                self.assert_failed_revision_retries()

    def test_numeric_or_string_api_success_is_accepted(self):
        self.__class__.response_body = b'{"result":"0"}'
        self.assertEqual(self.invoke().returncode, 0)
        self.assertTrue((self.root / 'state').exists())


if __name__ == '__main__':
    unittest.main()
