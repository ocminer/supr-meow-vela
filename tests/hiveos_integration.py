#!/usr/bin/env python3
"""Hive custom-miner callback contract, with a CPU-only miner/telemetry fixture.

Hive sources h-config/h-stats with $0 belonging to its caller, and executes
h-run from the installed miner directory. No live Hive account/GPU is needed.
"""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[1]


class HiveIntegration(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory(prefix='vela-hive-integration-')
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.package = self.root/'miners/custom/supr-meow-vela'
        self.package.mkdir(parents=True)
        self.agent = self.root/'bin/agent'
        self.agent.parent.mkdir()
        for path in (SOURCE/'hiveos').glob('*'):
            shutil.copy2(path, self.package/path.name)
        manifest = self.package/'h-manifest.conf'
        manifest.write_text(manifest.read_text()
            .replace('/hive/miners/custom/supr-meow-vela', str(self.package))
            .replace('/var/log/miner/supr-meow-vela', str(self.root/'logs')))
        self.logbase = self.root/'logs/supr-meow-vela'
        self.statsfile = self.logbase.with_suffix('.stats.json')
        self.conf = self.package/'supr-meow-vela.conf'
        self.model = self.root/'cached-model.poisd'
        self.model.write_bytes(b'checked fixture model\n')
        self.env = {k:v for k,v in os.environ.items() if not k.startswith(('CUSTOM_', 'MODEL_'))}
        self.env.update(CUSTOM_URL='stratum+tcp://pool.example:7601',
                        CUSTOM_TEMPLATE='wallet.worker', CUSTOM_PASS='x',
                        CUSTOM_USER_CONFIG=f'MODEL_PATH={shlex.quote(str(self.model))}\n'
                        f'MODEL_SHA256={hashlib.sha256(self.model.read_bytes()).hexdigest()}')
        self.miner = self.package/'supr-meow-vela'
        self.miner.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
            'print("ARGS="+json.dumps(sys.argv[1:]))\n'
            'sys.exit(int(os.environ.get("FAKE_EXIT", "0")))\n')
        self.miner.chmod(0o755)

    def configure(self, **env):
        self.agent.write_text(f'. {shlex.quote(str(self.package/"h-manifest.conf"))}\n'
                              f'. {shlex.quote(str(self.package/"h-config.sh"))}\n')
        return subprocess.run(['bash', str(self.agent)], env={**self.env, **env},
                              text=True, capture_output=True, timeout=5)

    def snapshot(self, **kwargs):
        value = {'schema':1, 'timestamp':int(time.time()), 'pid':os.getpid(),
                 'version':'0.1.10', 'uptime':1234, 'total_inf_s':80.7,
                 'shares':{'accepted':12,'rejected':2,'stale':1},
                 'devices':[{'index':3,'inf_s':52.3,'temp':62,'fan':None,'bus_number':10},
                            {'index':1,'inf_s':28.4,'temp':71,'fan':80,'bus_number':3}]}
        value.update(kwargs)
        self.statsfile.parent.mkdir(exist_ok=True)
        self.statsfile.write_text(json.dumps(value))
        return value

    def stats(self):
        # $0 is an agent elsewhere, not the miner script. Preserve caller locals.
        self.agent.write_text(f'cd {shlex.quote(str(self.root))}\n'
            'temp=caller-temp; fan=caller-fan\n'
            f'. {shlex.quote(str(self.package/"h-stats.sh"))}\n'
            'jq -nc --argjson stats "$stats" --arg khs "$khs" --arg cwd "$PWD" '
            '--arg temp "$temp" --arg fan "$fan" \'{$stats,$khs,$cwd,$temp,$fan}\'\n')
        result = subprocess.run(['bash', str(self.agent)], env=self.env, text=True,
                                capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        data = json.loads(result.stdout)  # also rejects debug output from the callback
        self.assertEqual(data['cwd'], str(self.root))
        self.assertEqual((data['temp'],data['fan']), ('caller-temp','caller-fan'))
        return data

    def test_rate_units_uptime_shares_and_selected_gpu_mapping(self):
        self.snapshot()
        data = self.stats()
        self.assertAlmostEqual(float(data['khs']), .0807)
        self.assertEqual(data['stats'], {'hs':[52.3,28.4], 'hs_units':'hs', 'temp':[62,71],
            'fan':[None,80], 'bus_numbers':[10,3], 'uptime':1234, 'ver':'0.1.11',
            'ar':[12,3], 'algo':'vela-poi'})

    def test_eight_gpu_snapshot_is_complete(self):
        self.snapshot(devices=[{'index':i,'inf_s':28.4+i,'temp':60+i,'fan':None,'bus_number':16+i} for i in range(8)])
        data = self.stats()
        self.assertEqual(data['stats']['bus_numbers'], list(range(16,24)))
        self.assertEqual(len(data['stats']['hs']), 8)
        self.assertAlmostEqual(float(data['khs']), sum(28.4+i for i in range(8))/1000)

    def test_missing_stats_is_zero(self):
        data = self.stats()
        self.assertEqual(data['khs'], '0')
        self.assertEqual(data['stats']['hs'], [])
        self.assertEqual(data['stats']['ver'], '0.1.11')

    def test_stale_future_dead_or_incomplete_stats_is_zero(self):
        for change in [{'timestamp':int(time.time())-61}, {'timestamp':int(time.time())+20},
                       {'pid':2147483647}, {'devices':[]}, {'uptime':-1}, {'schema':2}]:
            with self.subTest(change=change):
                self.snapshot(**change)
                data = self.stats()
                self.assertEqual(data['khs'], '0')
                self.assertEqual(data['stats']['hs'], [])
                self.assertEqual(data['stats']['ver'], '0.1.11')

    def test_bad_json_and_unavailable_telemetry_do_not_break_agent(self):
        self.snapshot()
        self.statsfile.write_text('{"incomplete":')
        self.assertEqual(self.stats()['stats']['hs'], [])
        self.snapshot(devices=[{'index':0,'inf_s':28.4,'temp':None,'fan':None,'bus_number':None}])
        self.assertEqual(self.stats()['stats']['fan'], [None])

    def test_flight_sheet_quoting_and_first_pool(self):
        wallet = 'wallet."worker$cash`literal`'
        password = "s'ecret \\ $value"
        result = self.configure(CUSTOM_TEMPLATE=wallet, CUSTOM_PASS=password,
                                CUSTOM_URL='pool.example:7601\r\nfallback.example:7601')
        self.assertEqual(result.returncode,0,result.stderr)
        result = subprocess.run(['bash','-c','. "$1"; printf "%s\\0%s\\0%s" "$POOL_URL" "$WALLET" "$PASSWORD"',
                                 'fixture',str(self.conf)],capture_output=True,timeout=5)
        self.assertEqual(result.stdout.split(b'\0'),[b'pool.example:7601',wallet.encode(),password.encode()])

    def test_invalid_configuration_does_not_replace_last_good(self):
        self.assertEqual(self.configure().returncode,0)
        before = self.conf.read_bytes()
        for extra in ['--batch 4', 'BATCH="unterminated']:
            result = self.configure(CUSTOM_USER_CONFIG=extra)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('extra config', result.stderr)
            self.assertEqual(self.conf.read_bytes(),before)

    def test_missing_flight_sheet_fields_fail(self):
        self.assertNotEqual(self.configure(CUSTOM_TEMPLATE='').returncode,0)
        self.assertNotEqual(self.configure(CUSTOM_URL='').returncode,0)

    def launch(self, **env):
        return subprocess.run(['bash',str(self.package/'h-run.sh')],env={**self.env,**env},
                              cwd=self.root,text=True,capture_output=True,timeout=10)

    def test_clean_install_launch_and_tls_url(self):
        self.assertEqual(self.configure(CUSTOM_URL='stratum+ssl://pool.example:7604').returncode,0)
        self.assertFalse(self.logbase.parent.exists())
        result = self.launch()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('HiveOS package 0.1.11', result.stdout)
        self.assertTrue(self.logbase.with_suffix('.log').exists())
        args = json.loads(next(line[5:] for line in result.stdout.splitlines() if line.startswith('ARGS=')))
        self.assertIn('--tls',args)
        self.assertEqual(args[args.index('--stats-file')+1],str(self.statsfile))
        self.assertEqual(args[args.index('--model')+1],str(self.model))

    def test_miner_failure_is_not_masked_by_tee_and_stale_stats_removed(self):
        self.assertEqual(self.configure().returncode,0)
        self.snapshot()
        result = self.launch(FAKE_EXIT='17')
        self.assertEqual(result.returncode,17,result.stderr)
        self.assertFalse(self.statsfile.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
