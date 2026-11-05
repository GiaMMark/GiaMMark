"""Browser regression checks; run with python3 alphascript/tests/test_site.py."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import threading
import unittest
from playwright.sync_api import sync_playwright, expect

SITE = Path(os.environ.get('ALPHASCRIPT_SITE_ROOT', Path(__file__).resolve().parents[1]))

class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

class SiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(SITE)))
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}'
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width':390,'height':844}, locale='it-IT')
        self.page = self.context.new_page()
        self.errors = []
        self.page.on('pageerror', lambda error: self.errors.append(str(error)))

    def tearDown(self):
        self.context.close()

    def visit(self, path='/'):
        self.page.goto(self.base+path, wait_until='load')
        self.page.evaluate('document.fonts.ready')

    def test_contact_action_is_available_in_first_mobile_viewport(self):
        # A blocking intro or an oversized hero must not hide the primary action.
        self.visit()
        link = self.page.locator('.hero a[href="#contatti"]').first
        expect(link).to_be_visible()
        rect = link.bounding_box()
        self.assertLess(rect['y']+rect['height'], 844)
        self.assertTrue(link.evaluate('(el)=>{ const r=el.getBoundingClientRect(); return el.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)); }'))

    def test_mobile_menu_escape_restores_focus_and_closes_menu(self):
        self.visit()
        button = self.page.locator('.menu-toggle')
        expect(button).to_have_attribute('aria-label','Apri il menu')
        button.focus()
        self.page.keyboard.press('Enter')
        expect(button).to_have_attribute('aria-expanded','true')
        self.page.keyboard.press('Escape')
        expect(button).to_have_attribute('aria-expanded','false')
        expect(button).to_be_focused()
        self.assertNotIn('menu-open', self.page.locator('body').get_attribute('class') or '')

    def test_mobile_menu_link_closes_menu_and_reaches_contact(self):
        self.visit()
        button = self.page.locator('.menu-toggle')
        expect(button).to_have_attribute('aria-label','Apri il menu')
        button.click()
        self.page.locator('#main-nav a[href="#contatti"]').click()
        expect(button).to_have_attribute('aria-expanded','false')
        expect(self.page.locator('#contatti')).to_be_in_viewport()

    def test_native_faq_and_navigation_work_without_javascript(self):
        context = self.browser.new_context(java_script_enabled=False, viewport={'width':390,'height':844})
        try:
            page = context.new_page()
            page.goto(self.base, wait_until='load')
            expect(page.get_by_role('heading',level=1)).to_be_visible()
            page.locator('#main-nav a[href="#contatti"]').click()
            expect(page.locator('#contact-form')).to_be_in_viewport()
            summary = page.locator('details summary').first
            expect(summary).to_be_visible()
            summary.click()
            expect(summary.locator('..')).to_have_attribute('open','')
        finally:
            context.close()

    def test_layout_remains_usable_across_viewports(self):
        for width in [320,390,768,1024,1440,1920]:
            with self.subTest(width=width):
                self.page.set_viewport_size({'width':width,'height':900})
                self.visit()
                self.assertLessEqual(self.page.evaluate('document.documentElement.scrollWidth'),width)
                expect(self.page.locator('#contact-form input[name=email]')).to_be_visible()
                expect(self.page.locator('#contact-form button[type=submit]')).to_be_visible()
        self.assertEqual(self.errors,[])

    def test_reduced_motion_keeps_content_and_controls_immediately_available(self):
        self.page.emulate_media(reduced_motion='reduce')
        self.visit()
        link = self.page.locator('.hero a[href="#contatti"]').first
        expect(link).to_be_visible()
        self.assertTrue(link.evaluate('(el)=>{ const r=el.getBoundingClientRect(); return el.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)); }'))
        self.assertEqual(self.errors,[])

if __name__=='__main__':
    unittest.main(verbosity=2)
