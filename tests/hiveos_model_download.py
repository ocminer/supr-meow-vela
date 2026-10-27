#!/usr/bin/env python3
"""Exercise the actual mining-OS launchers with local HTTP fixtures and no GPU."""
import hashlib
import http.server
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

SOURCE = Path(__file__).resolve().parents[1]
MODEL = b'vela model download fixture\n'
SHA = hashlib.sha256(MODEL).hexdigest()
PRIMARY = 'https://vela.suprnova.cc/dl/sd-turbo-int.poisd'
MIRROR = 'https://www.suprnova.cc/dl/sd-turbo-int.poisd'
HF = 'https://huggingface.co/valereseach/vela-sd-turbo-int-v2/resolve/main/sd-turbo-int.poisd'
# HiveOS images based on Ubuntu 18.04 ship curl 7.58, which exits 2 on any
# option added later (e.g. --no-progress-meter, curl 7.67). The fixture curl
# rejects these the same way so launchers must stay compatible.
NEWER_CURL_OPTIONS = ['--no-progress-meter', '--retry-all-errors', '--fail-with-body',
                      '--parallel', '--retry-connrefused', '--output-dir', '--create-dirs-mode']


class DownloadTests(unittest.TestCase):
    LAUNCHER = 'hiveos/h-run.sh'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='vela-hiveos-download-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.requests = []
        self.routes = {'/primary': MODEL, '/mirror': MODEL, '/hf': MODEL, '/custom': MODEL}
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                owner.requests.append(self.path)
                data = owner.routes.get(self.path)
                self.send_response(200 if data is not None else 404)
                data = data if data is not None else b'not found'
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)
        self.base = 'http://127.0.0.1:' + str(self.server.server_port)
        self.script = self.root/'launcher.sh'
        self.script.write_text((SOURCE/self.LAUNCHER).read_text()
                               .replace('/app/supr-meow-vela', str(self.root/'supr-meow-vela')))
        (self.root/'h-manifest.conf').write_text(
            f'CUSTOM_CONFIG_FILENAME="{self.root}/unused.conf"\n'
            f'CUSTOM_LOG_BASENAME="{self.root}/miner"\n')
        miner = self.root/'supr-meow-vela'
        miner.write_text('#!/usr/bin/env bash\necho MINER_STARTED\n')
        miner.chmod(0o755)
        self.cache = self.root/'models'
        self.cache.mkdir()
        self.cached = self.cache/'sd-turbo-int.poisd'
        bindir = self.root/'bin'
        bindir.mkdir()
        # Redirect only the two built-in URLs to local fixtures. All transfers
        # still use the real curl and checksum tools, including HTTP failures.
        wrapper = bindir/'curl'
        wrapper.write_text('#!/usr/bin/env python3\nimport os,sys\n'
            f'mapping={json.dumps({PRIMARY:self.base+"/primary", MIRROR:self.base+"/mirror", HF:self.base+"/hf"})}\n'
            f'newer={NEWER_CURL_OPTIONS!r}\n'
            'bad=[a for a in sys.argv[1:] if a in newer]\n'
            'if bad: sys.stderr.write("curl: option "+bad[0]+": is unknown\\n"); sys.exit(2)\n'
            'args=[mapping.get(a,a) for a in sys.argv[1:]]\n'
            f'os.execv({shutil.which("curl")!r}, ["curl"]+args)\n')
        wrapper.chmod(0o755)
        self.env = {k:v for k,v in os.environ.items()
                    if not k.startswith('MODEL_') and k not in ['EXTRA_ARGS', 'TLS']}
        self.env.update(PATH=str(bindir)+os.pathsep+os.environ['PATH'],
                        POOL_URL='fixture:1', WALLET='fixture',
                        MODEL_DIR=str(self.cache), MODEL_SHA256=SHA)

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def launch(self, success=True, **env):
        result = subprocess.run(['bash', str(self.script)],
            env={**self.env, **env}, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=20)
        self.assertEqual(result.returncode == 0, success, result.stdout)
        self.assertEqual('MINER_STARTED' in result.stdout, success, result.stdout)
        self.assertFalse(list(self.cache.glob('*.part*')))
        return result

    def test_primary_success_never_fetches_mirror(self):
        self.launch()
        self.assertEqual(self.requests, ['/primary'])
        self.assertEqual(self.cached.read_bytes(), MODEL)

    def test_http_failure_uses_mirror(self):
        self.routes['/primary'] = None
        self.launch()
        self.assertEqual(self.requests, ['/primary', '/mirror'])
        self.assertEqual(self.cached.read_bytes(), MODEL)

    def test_bad_primary_checksum_uses_mirror(self):
        self.routes['/primary'] = b'corrupt data'
        self.launch()
        self.assertEqual(self.requests, ['/primary', '/mirror'])
        self.assertEqual(self.cached.read_bytes(), MODEL)

    def test_suprnova_failures_use_huggingface(self):
        self.routes.update({'/primary': None, '/mirror': b'wrong model'})
        self.launch()
        self.assertEqual(self.requests, ['/primary', '/mirror', '/hf'])
        self.assertEqual(self.cached.read_bytes(), MODEL)

    def test_all_sources_fail_without_cached_partial(self):
        self.routes.update({'/primary': None, '/mirror': b'wrong model', '/hf': None})
        self.launch(success=False)
        self.assertEqual(self.requests, ['/primary', '/mirror', '/hf'])
        self.assertFalse(self.cached.exists())

    def test_valid_cache_skips_network(self):
        self.cached.write_bytes(MODEL)
        self.launch()
        self.assertEqual(self.requests, [])

    def test_bad_cache_cannot_start_miner(self):
        self.cached.write_bytes(b'corrupt cache')
        self.launch(success=False)
        self.assertEqual(self.requests, [])
        self.assertEqual(self.cached.read_bytes(), b'corrupt cache')

    def test_explicit_local_model_skips_network(self):
        local = self.root/'local.poisd'
        local.write_bytes(MODEL)
        self.launch(MODEL_PATH=str(local))
        self.assertEqual(self.requests, [])

    def test_custom_url_does_not_add_builtin_mirror(self):
        self.routes['/custom'] = None
        self.launch(success=False, MODEL_URL=self.base+'/custom')
        self.assertEqual(self.requests, ['/custom'])

    def test_custom_url_accepts_explicit_fallback(self):
        self.routes['/custom'] = None
        self.launch(MODEL_URL=self.base+'/custom', MODEL_FALLBACK_URL=self.base+'/mirror')
        self.assertEqual(self.requests, ['/custom', '/mirror'])
        self.assertEqual((self.cache/'custom').read_bytes(), MODEL)

    def test_fallback_list_is_tried_in_order(self):
        self.routes.update({'/primary': None, '/custom': None})
        self.launch(MODEL_FALLBACK_URL=self.base+'/custom '+self.base+'/hf')
        self.assertEqual(self.requests, ['/primary', '/custom', '/hf'])

    def test_empty_fallback_disables_mirror(self):
        self.routes['/primary'] = None
        self.launch(success=False, MODEL_FALLBACK_URL='')
        self.assertEqual(self.requests, ['/primary'])


class MmposDownloadTests(DownloadTests):
    LAUNCHER = 'mmpos/mmpos-run.sh'

    def test_bad_cache_cannot_start_miner(self):
        self.cached.write_bytes(b'corrupt cache')
        self.launch(success=False)
        self.assertEqual(self.requests, [])


class SmosDownloadTests(MmposDownloadTests):
    LAUNCHER = 'smos/smos-run.sh'


class DockerDownloadTests(MmposDownloadTests):
    LAUNCHER = 'docker/entrypoint.sh'


class LauncherCurlCompatibility(unittest.TestCase):
    def test_launchers_avoid_newer_curl_options(self):
        for rel in ['hiveos/h-run.sh', 'mmpos/mmpos-run.sh', 'smos/smos-run.sh', 'docker/entrypoint.sh']:
            text = (SOURCE/rel).read_text()
            for opt in NEWER_CURL_OPTIONS:
                self.assertNotIn(opt, text, rel)

    def test_every_launcher_lists_all_mirrors(self):
        for rel in ['hiveos/h-run.sh', 'mmpos/mmpos-run.sh', 'smos/smos-run.sh', 'docker/entrypoint.sh',
                    'windows/start.ps1']:
            text = (SOURCE/rel).read_text()
            for url in [PRIMARY, MIRROR, HF]:
                self.assertIn(url, text, rel)


if __name__ == '__main__':
    unittest.main(verbosity=2)
