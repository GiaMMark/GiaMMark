#!/usr/bin/env python3
"""Functional NUI tests. Requires Python playwright and Chromium.

python3 tests/nui.test.py [--chromium /path/to/chromium] [--base-url http://host:port]
Without --base-url, serve this resource's web/ directory on an ephemeral loopback port.
Environment equivalents: CHROMIUM_BIN, VOID_NUI_BASE_URL, VOID_NUI_SCREENSHOTS.
FiveM HTTPS callbacks are intercepted with realistic JSON fixtures, without a game server.
"""
from __future__ import annotations

import argparse
import copy
import functools
import json
import os
from pathlib import Path
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright, expect

RESOURCE = Path(__file__).resolve().parents[1]
CHARACTERS = [
    dict(id='char1', slot=1, firstname='Andrea', lastname='Moretti', dateofbirth='1998-04-12', sex='m', height=182, nationality='Italiana', job='Meccanico', cash=1250, bank=24800),
    dict(id='char2', slot=2, firstname='Sofia', lastname='De Luca', dateofbirth='2000-09-23', sex='f', height=169, nationality='Italiana', job='Disoccupata', cash=350, bank=5200, disabled=True),
    dict(id='char5', slot=5, firstname='Luca', lastname='Rossi', dateofbirth='1999-06-10', sex='m', height=175, nationality='Italiana', job='Medico', cash=500, bank=5000),
]


def payload(characters):
    return dict(ok=True, characters=copy.deepcopy(characters), slots=3, allowDelete=True,
                deleteConfirmation='ELIMINA', brand=dict(name='VOID', tagline='NON SEGUIRE UNA STORIA. VIVI LA TUA.'),
                identity=dict(minNameLength=2, maxNameLength=16, minAge=18, maxAge=100,
                              minHeight=140, maxHeight=210, nationalities=['Italiana', 'Americana']))


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def run(base_url, chromium, screenshots=None):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=chromium, headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport=dict(width=1440, height=900), device_scale_factor=1)
        errors, calls = [], []
        fixture = dict(characters=copy.deepcopy(CHARACTERS), ready=0, select_pending=False, fail_list=False)
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.add_init_script("window.GetParentResourceName = () => 'void_characters';")

        def callback(route):
            action = urlparse(route.request.url).path.strip('/')
            data = route.request.post_data_json or {}
            calls.append((action, data))
            response = dict(ok=True)
            if action == 'ready':
                fixture['ready'] += 1
                # Simulate the UI starting before the client registered its callbacks.
                response = dict(ok=fixture['ready'] > 1, error='Callback non ancora pronta')
            elif action == 'list':
                response = dict(ok=False, error='Database temporaneamente indisponibile') if fixture['fail_list'] else payload(fixture['characters'])
            elif action == 'select':
                response = dict(ok=False, error='Personaggio già connesso')
            elif action == 'delete':
                assert data.get('confirmation') == 'ELIMINA', 'Delete sent without exact confirmation'
                assert data.get('id') != 'char2', 'Disabled character deletion attempted'
                fixture['characters'] = [item for item in fixture['characters'] if item['id'] != data['id']]
                response = payload(fixture['characters'])
            elif action == 'create':
                assert data['slot'] <= 3, 'Create attempted beyond server slot allowance'
                assert data['slot'] not in [item['slot'] for item in fixture['characters']], 'Occupied slot overwritten'
                assert isinstance(data['height'], int) and data['sex'] in ('m', 'f')
                fixture['characters'].append(dict(**data, id='created', job='Disoccupato', cash=500, bank=5000))
            elif action != 'preview':
                raise AssertionError(f'Unexpected callback {action}')
            route.fulfill(status=200, content_type='application/json', body=json.dumps(response),
                          headers={'Access-Control-Allow-Origin': '*'})

        page.route('https://void_characters/**', callback)
        page.goto(base_url + '/index.html')
        expect(page.locator('#app')).to_be_hidden()
        # Wait for the second ready request rather than relying on a fixed sleep.
        def wait_for_callback(action, minimum):
            deadline = time.monotonic() + 5
            while len([item for item in calls if item[0] == action]) < minimum:
                assert time.monotonic() < deadline, f'Timed out waiting for {action} callback {minimum}'
                page.wait_for_timeout(25)

        wait_for_callback('ready', 2)
        assert fixture['ready'] >= 2, 'Ready handshake did not retry after server rejection'

        def open_ui(data):
            page.evaluate("payload => window.postMessage({ action: 'open', payload }, '*')", data)
            expect(page.locator('#app')).to_be_visible()

        def count(action):
            return len([item for item in calls if item[0] == action])

        open_ui(payload(fixture['characters']))
        expect(page.locator('#character-list button')).to_have_count(5)
        expect(page.locator('#stage-name')).to_have_text('AndreaMoretti')
        page.wait_for_function("document.querySelector('#app').getAttribute('aria-busy') === 'false'")
        expect(page.get_by_role('button', name='Slot 4 non disponibile', exact=True)).to_be_disabled()
        expect(page.get_by_role('button', name='Personaggio sospeso: Sofia De Luca, slot 2', exact=True)).to_be_disabled()
        expect(page.get_by_role('button', name='Seleziona Luca Rossi, slot 5', exact=True)).to_be_enabled()
        wait_for_callback('preview', 1)
        assert any(action == 'preview' and data.get('id') == 'char1' for action, data in calls), 'Initial selection was not previewed'
        assert page.evaluate("getComputedStyle(document.body).backgroundColor") == 'rgba(0, 0, 0, 0)'
        assert page.locator('.preview-world').evaluate("node => getComputedStyle(node).display") == 'none', 'Preview monolith leaked into game UI'

        # Existing slot 5 remains usable after the configured allowance was reduced to 3.
        page.get_by_role('button', name='Seleziona Luca Rossi, slot 5', exact=True).click()
        expect(page.locator('#stage-name')).to_have_text('LucaRossi')
        wait_for_callback('preview', 2)
        assert any(action == 'preview' and data.get('id') == 'char5' for action, data in calls)

        # Two immediate button activations still issue one mutating request.
        selected_before = count('select')
        page.locator('#enter-button').evaluate("button => { button.click(); button.click(); }")
        expect(page.locator('#feedback')).to_contain_text('Personaggio già connesso')
        expect(page.locator('#loading-overlay')).to_be_hidden()
        assert count('select') == selected_before + 1, 'Double select submitted twice'

        page.locator('#delete-button').click()
        expect(page.locator('#confirm-delete')).to_be_disabled()
        page.locator('#delete-confirmation').fill('elimina')
        expect(page.locator('#confirm-delete')).to_be_disabled()
        page.locator('#delete-confirmation').fill('ELIMINA')
        deleted_before = count('delete')
        page.locator('#confirm-delete').evaluate("button => { button.click(); button.click(); }")
        expect(page.locator('#delete-dialog')).to_be_hidden()
        expect(page.locator('#character-list button')).to_have_count(3)
        assert count('delete') == deleted_before + 1, 'Double deletion submitted twice'
        expect(page.get_by_role('button', name='Personaggio sospeso: Sofia De Luca, slot 2', exact=True)).to_be_disabled()

        page.get_by_role('button', name='Crea un personaggio nello slot 3', exact=True).click()
        expect(page.locator('#firstname')).to_be_focused()
        for name, value in dict(firstname='Elena', lastname='Bianchi', dateofbirth='1999-06-10', height='175').items():
            page.locator('#' + name).fill(value)
        page.locator('#sex').select_option('f')
        page.locator('#nationality').select_option('Italiana')
        if screenshots:
            page.screenshot(path=str(screenshots / 'identity.png'), full_page=True)
        created_before = count('create')
        page.locator('#create-button').evaluate("button => { button.click(); button.click(); }")
        expect(page.locator('#loading-overlay')).to_be_visible()
        # Process the browser request before asserting the fixture and callback body.
        wait_for_callback('create', created_before + 1)
        assert count('create') == created_before + 1, 'Double creation submitted twice'
        created = [data for action, data in calls if action == 'create'][-1]
        assert created == dict(firstname='Elena', lastname='Bianchi', dateofbirth='1999-06-10', height=175, sex='f', nationality='Italiana', slot=3)
        page.evaluate("window.postMessage({action:'close'}, '*')")
        expect(page.locator('#app')).to_be_hidden()

        # Recover from a list failure through the actual NUI fetch contract.
        broken = payload([])
        broken.update(error='Archivio non disponibile')
        open_ui(broken)
        fixture['fail_list'] = True
        page.get_by_role('button', name='RIPROVA').click()
        expect(page.locator('#feedback')).to_contain_text('Database temporaneamente indisponibile')
        fixture['fail_list'] = False
        page.get_by_role('button', name='RIPROVA').click()
        expect(page.get_by_role('button', name='Seleziona Elena Bianchi, slot 3', exact=True)).to_be_visible()
        assert count('list') == 2
        if screenshots:
            page.screenshot(path=str(screenshots / 'desktop.png'), full_page=True)
        page.set_viewport_size(dict(width=390, height=844))
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'Mobile has horizontal overflow'
        if screenshots:
            page.screenshot(path=str(screenshots / 'mobile.png'), full_page=True)

        # All disabled characters stay occupied, never presented as creatable slots.
        blocked = copy.deepcopy(CHARACTERS[1])
        blocked['slot'] = 1
        open_ui(payload([blocked]) | {'slots': 1})
        expect(page.locator('#character-list button')).to_have_count(1)
        expect(page.locator('#character-list button')).to_be_disabled()
        expect(page.locator('#character-details')).to_be_hidden()
        assert not page.get_by_role('button', name='Crea un personaggio nello slot 1').count()

        # Runtime reinitialization can request another ready acknowledgement.
        page.evaluate("window.postMessage({action:'request-ready'}, '*')")
        wait_for_callback('ready', 3)
        assert fixture['ready'] >= 3
        assert not errors, f'JavaScript errors: {errors}'
        browser.close()
        print('PASS: NUI ready retry/reinitialization, initial preview, existing slots, admin locks, transparent game UI, select failure, duplicate prevention, delete response, create payload, list retry, mobile.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', default=os.environ.get('VOID_NUI_BASE_URL'))
    parser.add_argument('--chromium', default=os.environ.get('CHROMIUM_BIN', '/usr/bin/chromium'))
    parser.add_argument('--screenshots', default=os.environ.get('VOID_NUI_SCREENSHOTS'))
    args = parser.parse_args()
    screenshots = Path(args.screenshots).expanduser().resolve() if args.screenshots else None
    if screenshots:
        screenshots.mkdir(parents=True, exist_ok=True)
    server = None
    try:
        base_url = args.base_url
        if not base_url:
            server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(RESOURCE / 'web')))
            threading.Thread(target=server.serve_forever, daemon=True).start()
            base_url = 'http://127.0.0.1:' + str(server.server_port)
        run(base_url.rstrip('/'), args.chromium, screenshots)
    finally:
        if server:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
