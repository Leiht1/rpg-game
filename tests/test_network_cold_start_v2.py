"""Cold bootstrap cannot hold login hostage; no production accounts or data."""
import concurrent.futures
import sys
import threading
import time
from types import SimpleNamespace
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/network'))
from test_network_server import ServerTests
from gameplay import Gameplay


class ColdStartTests(unittest.TestCase):
    setUp = ServerTests.setUp
    tearDown = ServerTests.tearDown
    api = ServerTests.api
    activate = ServerTests.activate
    world = ServerTests.world
    enter = ServerTests.enter
    both = ServerTests.both

    def test_movement_registers_before_waiting_for_state_lock(self):
        self.both()
        self.s.gameplay=SimpleNamespace(prepare=lambda world:None)
        with concurrent.futures.ThreadPoolExecutor(1) as pool:
            with self.s.lock:
                moving=pool.submit(self.api,'move',{'seq':1,'dx':0,'dy':0},self.t1)
                deadline=time.monotonic()+2
                while not self.s.pending_moves and time.monotonic()<deadline:
                    threading.Event().wait(.01)
                self.assertEqual(self.s.pending_moves,1,'queued movement must be visible to snapshot priority before authentication lock acquisition')
            self.assertTrue(moving.result(timeout=3)['ok'])
        self.assertEqual(self.s.pending_moves,0)

    def test_queued_action_runs_before_background_snapshot(self):
        self.both()
        self.s.gameplay=SimpleNamespace(prepare=lambda world:None)
        order=[]
        def committed(op, *args):
            order.append(op)
            return {'ok':True}
        with patch.object(self.s,'handle_locked',side_effect=committed):
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                with self.s.lock:
                    action=pool.submit(self.api,'game_command',{},self.t1)
                    deadline=time.monotonic()+2
                    while not self.s.pending_commands and time.monotonic()<deadline:
                        threading.Event().wait(.01)
                    self.assertEqual(self.s.pending_commands,1)
                    snapshot=pool.submit(self.api,'game_snapshot',{},self.t2)
                self.assertTrue(action.result(timeout=3)['ok'])
                self.assertTrue(snapshot.result(timeout=3)['ok'])
        self.assertEqual(order,['game_command','game_snapshot'])
        self.assertEqual(self.s.pending_commands,0)
        with self.assertRaises(Exception):self.api('game_command',{},'invalid-token')
        self.assertEqual(self.s.pending_commands,0,'failed authentication cannot leave the snapshot queue blocked')

    def test_new_world_save_failure_keeps_no_membership_or_cache(self):
        save=self.s.save
        with patch.object(self.s,'save',side_effect=OSError('test disk full')):
            with self.assertRaises(OSError):self.world()
        self.assertFalse(self.s.state['worlds'])
        self.assertFalse(self.s.account(self.t1)[0]['world_id'])
        self.assertFalse(self.s.nav_cache)
        self.assertFalse(hasattr(self.s.world_bootstrap,'value'))
        self.assertIn(self.world()['id'],self.s.state['worlds'])

    def test_login_during_new_world_generation(self):
        started, release = threading.Event(), threading.Event()
        def terrain(world):
            started.set()
            if not release.wait(12):raise TimeoutError('generation was never released')
            return self.nav(world)
        self.s.terrain_factory=terrain
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            creating=pool.submit(self.world)
            try:
                self.assertTrue(started.wait(2))
                login=pool.submit(self.api,'login',{'username':'playertwo','password':'Test-password-123'})
                self.assertTrue(login.result(timeout=2)['ok'])
                self.assertFalse(release.is_set())
            finally:release.set()
            self.assertIn(creating.result(timeout=3)['id'],self.s.state['worlds'])

    def test_login_completes_while_cold_bootstrap_is_still_blocked(self):
        self.both()
        self.s.config['gameplay_preview'] = True
        self.s.gameplay = Gameplay(self.config)
        started, release = threading.Event(), threading.Event()

        def cold(*unused):
            started.set()
            if not release.wait(12):
                raise TimeoutError('test bootstrap was never released')
            raise RuntimeError('intentional bootstrap failure')

        with patch('gameplay.GameHost', side_effect=cold):
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                boot = pool.submit(self.api, 'game_snapshot', {}, self.t1)
                try:
                    self.assertTrue(started.wait(2))
                    login = pool.submit(self.api, 'login', {'username':'playertwo', 'password':'Test-password-123'})
                    self.assertTrue(login.result(timeout=2)['ok'])
                    self.assertFalse(release.is_set())
                finally:
                    release.set()
                with self.assertRaisesRegex(RuntimeError, 'intentional'):
                    boot.result(timeout=3)
        self.assertEqual(self.s.gameplay.hosts, {})


del ServerTests

if __name__ == '__main__':
    unittest.main()
