#!/usr/bin/env python3
"""Functional loadscreen tests against Chromium and realistic FiveM engine messages.

From void_loadscreen: python3 tests/nui.test.py [--chromium /usr/bin/chromium]
Without --base-url, serves web/ on an ephemeral loopback port. Python playwright
and a Chromium installation are required only for development, not the resource.
The browser media boundary is mocked to test success and autoplay denial reliably.
"""
from __future__ import annotations

import argparse
import functools
import json
import os
from pathlib import Path
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

from playwright.sync_api import sync_playwright, expect

RESOURCE = Path(__file__).resolve().parents[1]


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def configuration():
    return {
        'brand': {'name': 'VOID TEST', 'eyebrow': 'TEST EXPERIENCE', 'tagline': 'Una nuova identità.', 'description': 'La tua storia.'},
        'appearance': {'accent': '#ededed', 'background': '#090909', 'animation': True},
        'tips': {'enabled': True, 'intervalMs': 9000, 'items': ['Prima indicazione.', 'Seconda indicazione.']},
        'music': {'enabled': True, 'autoplay': True, 'volume': .22, 'tracks': [
            {'src': 'media/void-ambient.ogg', 'title': 'SIGNAL ONE', 'artist': 'VOID'},
            {'src': 'media/void-ambient.ogg', 'title': 'SIGNAL TWO', 'artist': 'VOID'}]},
        'links': [{'label': 'DISCORD', 'url': 'https://discord.com/'}, {'label': 'UNSAFE', 'url': 'javascript:alert(1)'}],
        'rules': [{'title': 'Rispetto', 'text': 'Rispetta gli altri giocatori.'}],
        'labels': {'connecting': 'Connessione test', 'downloading': 'Download test', 'initializing': 'Avvio test',
                   'loadingMap': 'Mappa test', 'ready': 'Pronto test', 'waiting': 'Attesa test'},
        'playerName': '<img src=x onerror=alert(1)>',
        'diagnostics': False,
    }


MEDIA_MOCK = """
window.__media = { reject: true, plays: 0, pauses: 0, opened: [] };
Object.defineProperty(HTMLMediaElement.prototype, 'paused', { configurable: true, get() { return !this.__playing; } });
HTMLMediaElement.prototype.play = function() {
  window.__media.plays++;
  if (window.__media.reject) return Promise.reject(new DOMException('Autoplay disabled in test', 'NotAllowedError'));
  this.__playing = true;
  this.dispatchEvent(new Event('play'));
  this.dispatchEvent(new Event('playing'));
  return Promise.resolve();
};
HTMLMediaElement.prototype.pause = function() {
  window.__media.pauses++;
  this.__playing = false;
  this.dispatchEvent(new Event('pause'));
};
HTMLMediaElement.prototype.load = function() {};
window.invokeNative = (name, url) => window.__media.opened.push({ name, url });
"""


def run(base_url, chromium, screenshots=None):
    passed = []
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=chromium, headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1440, 'height': 900}, device_scale_factor=1)
        errors = []
        page.on('pageerror', lambda err: errors.append(str(err)))
        page.add_init_script(MEDIA_MOCK)
        page.add_init_script('window.nuiHandoverData = ' + json.dumps({'void_loadscreen': configuration()}) + ';')
        page.goto(base_url + '/index.html')
        expect(page.locator('#brand-name')).to_have_text('VOID TEST')
        expect(page.locator('#progress-value')).to_contain_text('0')
        assert page.locator('img[onerror]').count() == 0, 'Handover data became HTML'
        passed.append('configuration handover and safe text rendering')

        def engine(event):
            page.evaluate('(data) => window.postMessage(data, "*")', event)

        engine({'eventName': 'loadProgress', 'loadFraction': .425})
        expect(page.locator('#progress-value')).to_contain_text('42')
        engine({'eventName': 'loadProgress', 'loadFraction': .12})
        expect(page.locator('#progress-value')).to_contain_text('42')
        engine({'eventName': 'loadProgress', 'loadFraction': 'invalid'})
        engine({'eventName': 'loadProgress', 'loadFraction': -10})
        expect(page.locator('#progress-value')).to_contain_text('42')
        page.evaluate("window.postMessage({eventName:'loadProgress',loadFraction:NaN}, '*')")
        expect(page.locator('#progress-value')).to_contain_text('42')
        # Tips and decorative animation must never fabricate loading progress.
        page.wait_for_timeout(4100)
        expect(page.locator('#progress-value')).to_contain_text('42')
        passed.append('actual, monotonic, validated engine progress')

        engine({'eventName': 'startInitFunction', 'type': 'INIT_SESSION'})
        expect(page.locator('#loading-status')).to_have_text('Avvio test')
        engine({'eventName': 'performMapLoadFunction'})
        expect(page.locator('#loading-status')).to_have_text('Mappa test')
        engine({'eventName': 'loadProgress', 'loadFraction': 9})
        expect(page.locator('#progress-value')).to_contain_text('100')
        expect(page.locator('#loading-status')).to_have_text('Attesa test')
        engine({'eventName': 'onDataFileEntry'})
        expect(page.locator('#loading-status')).to_have_text('Attesa test')
        passed.append('engine stages and 100 percent waiting state')

        # Autoplay failure is an expected browser policy, not an unrecoverable error.
        assert page.evaluate('window.__media.plays') >= 1
        page.evaluate('window.__media.reject = false')
        page.locator('#music-toggle').click()
        assert page.evaluate('window.__media.plays') >= 2
        page.locator('#music-volume').evaluate("node => { node.value = '47'; }")
        page.locator('#music-volume').dispatch_event('input')
        assert abs(page.locator('audio').evaluate('(node) => node.volume') - .47) < .01
        page.locator('#music-mute').click()
        assert page.locator('audio').evaluate('(node) => node.muted'), 'Mute did not reach media element'
        page.locator('#music-mute').click()
        assert not page.locator('audio').evaluate('(node) => node.muted')
        page.evaluate('document.activeElement?.blur()')
        page.keyboard.press('Space')
        assert page.evaluate('window.__media.pauses') >= 1
        assert page.locator('audio').evaluate('(node) => node.paused')
        stored = page.evaluate("JSON.parse(localStorage.getItem('void_loadscreen.audio'))")
        assert abs(stored['volume'] - .47) < .01 and stored['muted'] is False
        passed.append('autoplay denial, explicit audio start, volume and mute')

        expect(page.locator('#playlist-controls')).to_be_visible()
        page.locator('#music-next').click()
        expect(page.locator('#music-title')).to_have_text('SIGNAL TWO')
        assert page.locator('audio').evaluate('(node) => node.paused'), 'Track navigation resumed intentionally paused audio'
        page.locator('#music-prev').click()
        expect(page.locator('#music-title')).to_have_text('SIGNAL ONE')
        page.locator('#music-toggle').click()
        page.locator('audio').dispatch_event('ended')
        expect(page.locator('#music-title')).to_have_text('SIGNAL TWO')
        assert not page.locator('audio').evaluate('(node) => node.loop'), 'Playlist must advance rather than loop first track'
        passed.append('playlist navigation, pause preservation and automatic next track')

        assert page.locator('#links').get_by_text('UNSAFE', exact=True).count() == 0, 'Unsafe URL is visible'
        page.locator('#links').get_by_text('DISCORD', exact=True).click()
        assert page.evaluate('window.__media.opened') == [{'name': 'openUrl', 'url': 'https://discord.com/'}]
        page.locator('#rules-button').click()
        expect(page.locator('#rules-dialog')).to_be_visible()
        expect(page.locator('#rules-dialog')).to_contain_text('Rispetta gli altri giocatori.')
        page.keyboard.press('Escape')
        expect(page.locator('#rules-dialog')).to_be_hidden()
        passed.append('safe native links and accessible rules modal')

        if screenshots:
            page.screenshot(path=str(screenshots / 'desktop.png'), full_page=True)
        page.set_viewport_size({'width': 390, 'height': 844})
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'Mobile overflow'
        if screenshots:
            page.screenshot(path=str(screenshots / 'mobile.png'), full_page=True)
        passed.append('desktop and mobile layout')

        single = configuration()
        single['music'].update(autoplay=False, tracks=single['music']['tracks'][:1])
        engine({'eventName': 'void:config', 'config': single})
        expect(page.locator('#playlist-controls')).to_be_hidden()
        assert page.locator('audio').evaluate('(node) => node.loop'), 'A single track must loop'
        assert abs(page.locator('audio').evaluate('(node) => node.volume') - .47) < .01
        passed.append('single-track mode and user audio preference preserved after hydration')

        updated = configuration()
        updated['music'].update(enabled=False, tracks=[])
        updated['tips']['enabled'] = False
        updated['appearance']['animation'] = False
        engine({'eventName': 'void:config', 'config': updated})
        expect(page.locator('#music-player')).to_be_hidden()
        expect(page.locator('#tips')).to_be_hidden()
        assert page.locator('body').evaluate("node => node.classList.contains('no-animation')")
        assert page.locator('audio').evaluate('(node) => node.paused')
        stored_before_shutdown = page.evaluate("localStorage.getItem('void_loadscreen.audio')")
        engine({'eventName': 'void:shutdown', 'durationMs': 0})
        assert page.locator('audio').evaluate('(node) => node.paused')
        expect(page.locator('#loading-status')).to_have_text('Pronto test')
        assert page.locator('body').evaluate("node => getComputedStyle(node).backgroundColor") == 'rgba(0, 0, 0, 0)'
        assert page.evaluate("localStorage.getItem('void_loadscreen.audio')") == stored_before_shutdown
        passed.append('zero-track configuration and immediate transparent shutdown')
        assert not errors, f'JavaScript errors: {errors}'

        context = browser.new_context(viewport={'width': 1366, 'height': 768}, reduced_motion='reduce')
        limited = context.new_page()
        limited_errors = []
        limited.on('pageerror', lambda err: limited_errors.append(str(err)))
        limited.add_init_script(MEDIA_MOCK)
        limited.add_init_script("Object.defineProperty(window, 'localStorage', {get() {throw new DOMException('Storage blocked', 'SecurityError');}});")
        limited_config = configuration()
        limited_config['music']['autoplay'] = False
        limited.add_init_script('window.nuiHandoverData = ' + json.dumps({'void_loadscreen': limited_config}) + ';')
        limited.goto(base_url + '/index.html')
        expect(limited.locator('#brand-name')).to_have_text('VOID TEST')
        assert limited.locator('.orb-core').evaluate("node => parseFloat(getComputedStyle(node).animationDuration) <= .01"), 'Reduced motion preference ignored'
        limited.evaluate('window.__media.reject = false')
        limited.locator('#music-toggle').click()
        limited.locator('#music-mute').click()
        limited.locator('#music-volume').evaluate("node => {node.value='55'; node.dispatchEvent(new Event('input'));}")
        assert not limited_errors, f'Storage-denied errors: {limited_errors}'
        limited.evaluate("window.postMessage({eventName:'void:shutdown',durationMs:350}, '*')")
        expect(limited.locator('#screen')).to_have_class('leaving')
        limited.wait_for_timeout(450)
        assert limited.locator('audio').evaluate('(node) => node.paused'), 'Fade did not finish audio playback'
        assert limited.locator('body').evaluate("node => getComputedStyle(node).backgroundColor") == 'rgba(0, 0, 0, 0)'
        assert not limited_errors, f'JavaScript errors during reduced-motion shutdown: {limited_errors}'
        passed.append('storage denied, reduced motion and timed audio/visual shutdown')
        context.close()

        # Validate the bundled artifact through the real media decoder as well;
        # earlier mocks deliberately exercise browser-policy denial deterministically.
        actual_context = browser.new_context(reduced_motion='reduce')
        actual = actual_context.new_page()
        actual_errors = []
        actual.on('pageerror', lambda err: actual_errors.append(str(err)))
        actual_config = configuration()
        actual_config['music'].update(autoplay=False, volume=.1, tracks=actual_config['music']['tracks'][:1])
        actual.add_init_script('window.nuiHandoverData = ' + json.dumps({'void_loadscreen': actual_config}) + ';')
        actual.goto(base_url + '/index.html')
        actual.locator('#music-toggle').click()
        actual.wait_for_function("document.querySelector('#audio').readyState >= 2 && Number.isFinite(document.querySelector('#audio').duration)", timeout=15000)
        actual.wait_for_function("document.querySelector('#audio').currentTime > .15", timeout=10000)
        duration = actual.locator('audio').evaluate('(node) => node.duration')
        # This test server intentionally has no byte-range support; Chromium may
        # estimate OGG duration before the final granule is demuxed. Artifact
        # duration is checked separately with ffprobe; real decoding/playback is
        # established here by readiness, advancing time and no media error.
        assert duration > 0, f'Invalid bundled soundtrack duration: {duration}'
        assert actual.locator('audio').evaluate('(node) => !node.paused && !node.error'), 'Bundled OGG failed to play'
        assert not actual_errors, f'Real audio playback errors: {actual_errors}'
        passed.append('bundled ambient OGG decodes and actually advances playback')
        actual_context.close()
        browser.close()
    print(f'PASS: {len(passed)} browser scenarios: ' + '; '.join(passed) + '.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', default=os.environ.get('VOID_LOADSCREEN_BASE_URL'))
    parser.add_argument('--chromium', default=os.environ.get('CHROMIUM_BIN', '/usr/bin/chromium'))
    parser.add_argument('--screenshots', default=os.environ.get('VOID_LOADSCREEN_SCREENSHOTS'))
    args = parser.parse_args()
    shots = Path(args.screenshots).expanduser().resolve() if args.screenshots else None
    if shots:
        shots.mkdir(parents=True, exist_ok=True)
    server = None
    try:
        url = args.base_url
        if not url:
            server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(RESOURCE / 'web')))
            threading.Thread(target=server.serve_forever, daemon=True).start()
            url = 'http://127.0.0.1:' + str(server.server_port)
        run(url.rstrip('/'), args.chromium, shots)
    finally:
        if server:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
