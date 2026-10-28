#!/usr/bin/env python3
"""Exercise the supplied ox_inventory bundle plus the VOID LS-style layer.

Requires Python Playwright + Chromium; use --resource for a COMPLETE inventory
with this patch applied. Browser callbacks and native game status are fixtures.
No persistence, player permissions or GTA rendering is emulated by these tests.
"""
import argparse
import copy
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright, expect


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


SVG_ICONS = {
    'water': '<path d="M21 5h14v9l4 9v35H17V23l4-9Z" fill="#899383" stroke="#d8dccd"/><path d="M18 32h20v16H18Z" fill="#2d4146" stroke="#b6c4c3"/>',
    'bandage': '<path d="M9 22h39v22H9Z" fill="#adb9a0" stroke="#d7deca"/><path d="M25 25h8v6h6v7h-6v5h-8v-5h-6v-7h6Z" fill="#a94747"/>',
    'WEAPON_PISTOL': '<path d="m5 20 43-5 6 9-27 5-4 25-12-2 4-23-9 1Z" fill="#9c9c8b" stroke="#d3d4c9"/><path d="m14 33 12 2-3 14-11-2Z" fill="#2f3230"/>',
    'ammo-9': '<path d="M22 13c0-14 11-14 11 0v38H22Z" fill="#b1a474" stroke="#d6cda4"/><path d="M20 49h15v7H20Z" fill="#c9ba84"/>',
    'backpack': '<path d="M16 17h28l4 40H12Z" fill="#59634b" stroke="#b4bca4"/><path d="M21 17V7h18v10M18 34h24v18H18Z" stroke="#b4bca4" fill="none"/>',
}


def run(resource, screenshots=None, chromium='/usr/bin/chromium'):
    resource = resource.resolve()
    locale = json.loads((resource / 'locales/it.json').read_text())
    definitions = {
        'water': {'label': 'Acqua', 'weight': 500, 'stack': True, 'close': False, 'description': 'Acqua potabile per sopravvivere.', 'usable': True},
        'bandage': {'label': 'Benda', 'weight': 100, 'stack': True, 'close': False, 'description': 'Una fasciatura pulita.', 'usable': True},
        'WEAPON_PISTOL': {'label': 'Pistola', 'weight': 1000, 'stack': False, 'close': False, 'description': 'Arma da fianco.', 'usable': True, 'ammoName': 'ammo-9'},
        'ammo-9': {'label': '9mm', 'weight': 10, 'stack': True},
        'backpack': {'label': 'Zaino sportivo', 'weight': 600, 'stack': False, 'close': False, 'usable': True},
    }
    player = {'id': 1, 'type': 'player', 'label': 'SOPRAVVISSUTO TEST', 'slots': 32, 'maxWeight': 30000, 'items': [
        {'slot': 1, 'name': 'water', 'count': 6, 'weight': 3000, 'metadata': {'description': 'Acqua potabile per sopravvivere.'}},
        {'slot': 2, 'name': 'bandage', 'count': 4, 'weight': 400, 'metadata': {'durability': 75}},
        {'slot': 3, 'name': 'WEAPON_PISTOL', 'count': 1, 'weight': 1000, 'metadata': {'serial': 'VOID-QA-123', 'durability': 83, 'ammo': 12, 'components': []}},
        {'slot': 6, 'name': 'ammo-9', 'count': 24, 'weight': 240, 'metadata': {}},
        {'slot': 10, 'name': 'WEAPON_PISTOL', 'count': 1, 'weight': 1000, 'metadata': {'serial': 'VOID-QA-456', 'durability': 62, 'ammo': 6, 'components': []}},
        {'slot': 13, 'name': 'backpack', 'count': 1, 'weight': 600, 'metadata': {'container': 'qa-pack', 'size': [12, 12000]}},
    ]}
    external = {'id': 'qa-drop', 'type': 'drop', 'label': 'TERRENO TEST', 'slots': 35, 'maxWeight': 30000, 'items': [
        {'slot': 1, 'name': 'water', 'count': 2, 'weight': 1000, 'metadata': {}},
    ]}
    passed = []
    handler = functools.partial(Quiet, directory=str(resource / 'web/build'))
    server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f'http://127.0.0.1:{server.server_port}'
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=chromium, headless=True, args=['--no-sandbox'])
            page = browser.new_page(viewport={'width': 1920, 'height': 1080}, device_scale_factor=1)
            errors, calls, remote_requests = [], [], []
            page.on('pageerror', lambda e: errors.append(str(e)))
            page.add_init_script("window.invokeNative=()=>{}; window.GetParentResourceName=()=> 'ox_inventory';")

            def callback(route):
                action = urlparse(route.request.url).path.strip('/')
                data = route.request.post_data_json
                calls.append((action, data))
                result = definitions.get(data, {}) if action == 'getItemData' else True
                route.fulfill(status=200, content_type='application/json', body=json.dumps(result))

            def image(route):
                name = Path(urlparse(route.request.url).path).stem
                body = SVG_ICONS.get(name, '<path d="M12 12h34v42H12Z" fill="#77816b" stroke="#c6cfb6"/>')
                route.fulfill(status=200, content_type='image/svg+xml', body=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>')

            page.route('https://ox_inventory/**', callback)
            page.route('**/fixture/**', image)
            page.on('request', lambda req: remote_requests.append(req.url) if urlparse(req.url).scheme in ('http', 'https') and urlparse(req.url).hostname not in ('127.0.0.1', 'ox_inventory') else None)
            page.goto(base + '/index.html')
            page.wait_for_function("document.querySelector('.app-wrapper') !== null")
            expect(page.locator('.inventory-wrapper')).to_have_count(0)
            assert page.evaluate("getComputedStyle(document.body).backgroundColor") == 'rgba(0, 0, 0, 0)'
            passed.append('closed UI is transparent')

            def send(action, data=None):
                page.evaluate("m=>window.postMessage(m,'*')", {'action': action, 'data': data})

            def setup(right=None):
                send('setupInventory', {'leftInventory': copy.deepcopy(player), 'rightInventory': copy.deepcopy(external if right is None else right)})
                expect(page.locator('.inventory-wrapper')).to_be_visible()
                expect(page.locator('[data-void-role="player"]')).to_be_visible()
                page.wait_for_timeout(100)

            def wait_call(action, minimum=1):
                end = time.monotonic() + 3
                while len([x for x in calls if x[0] == action]) < minimum:
                    assert time.monotonic() < end, f'Missing callback {action}'
                    page.wait_for_timeout(20)
                return [x[1] for x in calls if x[0] == action][-1]

            def count(action):
                return len([x for x in calls if x[0] == action])

            def slot(role, index):
                return page.locator(f'[data-void-role="{role}"] .inventory-slot').nth(index)

            send('init', {'locale': locale, 'items': definitions, 'leftInventory': copy.deepcopy(player), 'imagepath': base + '/fixture'})
            setup()
            player_box = page.locator('[data-void-role="player"]').bounding_box()
            external_box = page.locator('[data-void-role="external"]').bounding_box()
            avatar_box = page.locator('.void-avatar-zone').bounding_box()
            assert avatar_box['x'] < player_box['x'] < external_box['x'], 'LS layout must place avatar, personal cargo, external grid from left to right'
            assert external_box['x'] >= 1920 * .60, external_box
            expect(page.locator('[data-void-role="player"] .inventory-slot')).to_have_count(32)
            expect(page.locator('[data-void-role="player"]')).to_contain_text('SOPRAVVISSUTO TEST')
            expect(page.locator('[data-void-role="external"]')).to_contain_text('TERRENO TEST')
            assert slot('external', 3).evaluate("node => getComputedStyle(node, '::before').display") == 'block', 'Empty external cells must display the reference cross marker'
            assert slot('external', 0).evaluate("node => getComputedStyle(node, '::before').display") == 'none', 'Occupied cells must not overlay the empty cross marker'
            passed.append('LS reference layout preserves native player and external inventory identity')

            slot('player', 0).hover()
            expect(page.locator('.tooltip-wrapper')).to_be_visible(timeout=3000)
            expect(page.locator('.tooltip-wrapper')).to_contain_text('Acqua potabile')
            page.mouse.move(0, 0)
            passed.append('original metadata tooltip remains visible')
            slot('player', 0).click(button='right')
            page.locator('.context-menu-item').get_by_text('Usa', exact=True).click()
            assert wait_call('useItem') == 1
            passed.append('original context use posts exact slot')

            amount = page.locator('.inventory-control-input')
            amount.fill('2')
            slot('player', 0).click(button='right')
            page.locator('.context-menu-item').get_by_text('Dai', exact=True).click()
            assert wait_call('giveItem') == {'slot': 1, 'count': 2}
            passed.append('original quantity reaches give callback')
            setup()
            amount.fill('1')
            slot('player', 1).click(button='right')
            page.locator('.context-menu-item').get_by_text('Butta', exact=True).click()
            moved = wait_call('swapItems')
            assert moved['fromSlot'] == 2 and moved['fromType'] == 'player' and moved['count'] == 1, moved
            passed.append('original drop uses authorized server swap shape')

            setup()
            amount.fill('2')
            before = count('swapItems')
            source, target = slot('player', 0), slot('external', 3)
            sb, tb = source.bounding_box(), target.bounding_box()
            source.hover()
            page.mouse.down()
            page.mouse.move(sb['x'] + sb['width'] / 2 + 10, sb['y'] + sb['height'] / 2, steps=4)
            page.mouse.move(tb['x'] + tb['width'] / 2, tb['y'] + tb['height'] / 2, steps=15)
            page.mouse.up()
            moved = wait_call('swapItems', before + 1)
            assert moved['fromSlot'] == 1 and moved['toSlot'] == 4 and moved['fromType'] == 'player' and moved['toType'] == 'drop' and moved['count'] == 2, moved
            passed.append('real React mouse drag and drop reaches unchanged swap callback')

            setup()
            send('refreshSlots', {'items': [{'inventory': 'player', 'item': {'slot': 1, 'name': 'water', 'count': 3, 'weight': 1500, 'metadata': {}}}]})
            expect(slot('player', 0)).to_contain_text('3x')
            passed.append('server refresh updates original grid')

            before = count('useItem')
            page.locator('.void-quickbar [data-void-slot="3"]').click()
            assert wait_call('useItem', before + 1) == 3
            before = count('useItem')
            page.locator('.void-quickbar [data-void-slot="10"]').click()
            assert wait_call('useItem', before + 1) == 10
            expect(page.locator('.void-quickbar [data-void-slot="4"]')).to_be_disabled()
            page.wait_for_function("[...document.querySelectorAll('.void-quickbar img')].every(img => img.complete && img.naturalWidth > 0)")
            passed.append('ten-slot quickbar uses actual source slots, images and disables empty entries')

            before = count('useItem')
            page.locator('.void-equipment [data-void-slot="13"]').click()
            assert wait_call('useItem', before + 1) == 13
            passed.append('owned container control delegates to native useItem')

            send('void:status', {'health': 87, 'armor': 35, 'weight': 6240, 'maxWeight': 30000, 'weaponSlot': 3, 'previewActive': False})
            expect(page.locator('.void-survivor-status')).to_contain_text('87')
            expect(page.locator('.void-survivor-status')).to_contain_text('35')
            passed.append('native status updates health and armor without simulated defaults')

            for _ in range(4):
                setup()
            expect(page.locator('.void-inventory-chrome')).to_have_count(1)
            expect(page.locator('.void-avatar-zone')).to_have_count(1)
            expect(page.locator('[data-void-role="player"] .inventory-slot')).to_have_count(32)
            shop = copy.deepcopy(external)
            shop.update(type='shop', id='qa-shop', label='MERCANTE TEST')
            shop['items'] = [{'slot': 1, 'name': 'water', 'count': 25, 'weight': 500, 'price': 20, 'metadata': {}}]
            setup(shop)
            expect(page.locator('[data-void-role="external"]')).to_contain_text('MERCANTE TEST')
            empty = copy.deepcopy(external)
            empty['items'] = []
            setup(empty)
            expect(page.locator('[data-void-role="external"] .inventory-slot .item-slot-wrapper')).to_have_count(0)
            container = copy.deepcopy(external)
            container.update(type='container', id='qa-pack', label='ZAINO APERTO')
            setup(container)
            expect(page.locator('[data-void-role="external"]')).to_contain_text('ZAINO APERTO')
            passed.append('repeated setup plus shop, empty vicinity and container stay synchronized without duplicate native slots')

            setup()
            send('refreshSlots', {'items': [{'inventory': 'player', 'item': {'slot': 3}}]})
            expect(page.locator('.void-quickbar [data-void-slot="3"]')).to_be_disabled()
            passed.append('removed items disappear from quickbar without ghost equipped entries')

            setup()
            send('void:status', {'health': 100, 'armor': 0, 'weight': 6240, 'maxWeight': 30000, 'weaponSlot': 3, 'previewActive': False})
            if screenshots:
                screenshots.mkdir(parents=True, exist_ok=True)
                page.add_style_tag(content='body{background:radial-gradient(ellipse at 18% 45%,#46595455,transparent 35%),linear-gradient(135deg,#293335,#181e21)!important}')
                page.screenshot(path=str(screenshots / 'desktop.png'), full_page=True)
                page.add_style_tag(content='body{background:transparent!important}')
            for width, height in [(1366, 768), (1280, 720)]:
                page.set_viewport_size({'width': width, 'height': height})
                page.wait_for_timeout(100)
                for selector in ['[data-void-role="player"]', '[data-void-role="external"]', '.inventory-control', '.void-quickbar']:
                    box = page.locator(selector).bounding_box()
                    assert box and box['x'] >= -1 and box['x'] + box['width'] <= width + 1, (selector, width, box)
                assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'Horizontal overflow'
            passed.append('LS panels and quickbar remain usable at 1920, 1366 and 1280 widths')

            page.get_by_role('button', name='Chiudi', exact=True).click()
            wait_call('exit')
            send('closeInventory')
            expect(page.locator('.inventory-wrapper')).to_have_count(0)
            expect(page.locator('.void-inventory-chrome')).to_be_hidden()
            assert page.evaluate("getComputedStyle(document.body).backgroundColor") == 'rgba(0, 0, 0, 0)'
            passed.append('native exit and close remove overlay and restore transparency')
            assert not errors, errors
            assert not remote_requests, f'Unexpected external requests: {remote_requests}'
            browser.close()
        print('PASS:', len(passed), 'scenarios:', '; '.join(passed))
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resource', type=Path, required=True, help='Complete existing ox_inventory with this patch applied')
    parser.add_argument('--chromium', default='/usr/bin/chromium')
    parser.add_argument('--screenshots', type=Path)
    args = parser.parse_args()
    run(args.resource, args.screenshots, args.chromium)
