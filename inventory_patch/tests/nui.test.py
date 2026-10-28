#!/usr/bin/env python3
"""Exercise the uploaded ox_inventory React UI with real NUI callback boundaries.

python3 inventory_nui_qa.py --resource /path/to/ox_inventory [--screenshots /tmp/output]
Native inventory/network persistence is simulated, never represented as FXServer testing.
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
    def log_message(self, *_args): pass

def run(resource, screenshots=None, chromium="/usr/bin/chromium"):
    locale=json.loads((resource/'locales/it.json').read_text())
    definitions={
      'water': {'label':'Acqua','weight':500,'stack':True,'close':False,'description':'Acqua potabile per sopravvivere.','usable':True},
      'bandage': {'label':'Benda','weight':100,'stack':True,'close':False,'description':'Una fasciatura pulita.','usable':True},
      'WEAPON_PISTOL': {'label':'Pistola','weight':1000,'stack':False,'close':False,'description':'Arma da fianco.','usable':True,'ammoName':'ammo-9'},
      'ammo-9': {'label':'9mm','weight':10,'stack':True},
    }
    player={'id':1,'type':'player','label':'SOPRAVVISSUTO TEST','slots':20,'maxWeight':30000,'items':[
      {'slot':1,'name':'water','count':6,'weight':3000,'metadata':{'description':'Acqua potabile per sopravvivere.'}},
      {'slot':2,'name':'bandage','count':4,'weight':400,'metadata':{'durability':75}},
      {'slot':3,'name':'WEAPON_PISTOL','count':1,'weight':1000,'metadata':{'serial':'VOID-QA-123','durability':83,'ammo':12,'components':[]}},
    ]}
    external={'id':'qa-drop','type':'drop','label':'TERRENO TEST','slots':15,'maxWeight':30000,'items':[
      {'slot':1,'name':'water','count':2,'weight':1000,'metadata':{}},
    ]}
    passed=[]
    handler=functools.partial(Quiet,directory=str(resource/'web/build'))
    server=ThreadingHTTPServer(('127.0.0.1',0),handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    base=f'http://127.0.0.1:{server.server_port}'
    try:
      with sync_playwright() as p:
        browser=p.chromium.launch(executable_path=chromium,headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':1920,'height':1080},device_scale_factor=1)
        errors=[];calls=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.add_init_script("window.invokeNative=()=>{}; window.GetParentResourceName=()=> 'ox_inventory';")
        def callback(route):
          action=urlparse(route.request.url).path.strip('/')
          data=route.request.post_data_json
          calls.append((action,data))
          result=definitions.get(data,{}) if action=='getItemData' else True
          route.fulfill(status=200,content_type='application/json',body=json.dumps(result))
        page.route('https://ox_inventory/**',callback)
        page.goto(base+'/index.html')
        page.wait_for_function("document.querySelector('.app-wrapper') !== null")
        expect(page.locator('.inventory-wrapper')).to_have_count(0)
        assert page.evaluate("getComputedStyle(document.body).backgroundColor")=='rgba(0, 0, 0, 0)'
        passed.append('closed UI is transparent')
        def send(action,data=None):
          page.evaluate("m=>window.postMessage(m,'*')",{'action':action,'data':data})
        def setup():
          send('setupInventory',{'leftInventory':copy.deepcopy(player),'rightInventory':copy.deepcopy(external)})
          expect(page.locator('.inventory-wrapper')).to_be_visible()
          expect(page.locator('[data-void-role="player"]')).to_be_visible()
          page.wait_for_timeout(100)
        def wait_call(action,minimum=1):
          end=time.monotonic()+3
          while len([x for x in calls if x[0]==action])<minimum:
            assert time.monotonic()<end,f'Missing callback {action}'
            page.wait_for_timeout(20)
          return [x[1] for x in calls if x[0]==action][-1]
        def slot(role,index):return page.locator(f'[data-void-role="{role}"] .inventory-slot').nth(index)
        send('init',{'locale':locale,'items':definitions,'leftInventory':copy.deepcopy(player),'imagepath':base+'/images'})
        setup()
        player_box=page.locator('[data-void-role="player"]').bounding_box()
        external_box=page.locator('[data-void-role="external"]').bounding_box()
        assert external_box['x']<player_box['x'],'Vicinity/player visual semantics reversed'
        expect(page.locator('[data-void-role="player"]')).to_contain_text('SOPRAVVISSUTO TEST')
        expect(page.locator('[data-void-role="external"]')).to_contain_text('TERRENO TEST')
        passed.append('real player and vicinity grids keep identity while visually reordered')
        slot('player',0).hover()
        expect(page.locator('.tooltip-wrapper')).to_be_visible(timeout=3000)
        expect(page.locator('.tooltip-wrapper')).to_contain_text('Acqua potabile')
        page.mouse.move(0,0)
        passed.append('restored original metadata tooltip')
        slot('player',0).click(button='right')
        expect(page.locator('.context-menu-item').get_by_text('Usa',exact=True)).to_be_visible()
        page.locator('.context-menu-item').get_by_text('Usa',exact=True).click()
        assert wait_call('useItem')==1
        passed.append('original context use posts the exact owned slot')
        amount=page.locator('.inventory-control-input');amount.fill('2')
        slot('player',0).click(button='right')
        page.locator('.context-menu-item').get_by_text('Dai',exact=True).click()
        assert wait_call('giveItem')=={'slot':1,'count':2}
        passed.append('quantity reaches original give callback')
        setup();amount.fill('1')
        slot('player',1).click(button='right')
        page.locator('.context-menu-item').get_by_text('Butta',exact=True).click()
        moved=wait_call('swapItems')
        assert moved['fromSlot']==2 and moved['fromType']=='player' and moved['count']==1,moved
        passed.append('original drop uses server swap with exact slot and count')
        setup();amount.fill('2')
        before=len([x for x in calls if x[0]=='swapItems'])
        source=slot('player',0); target=slot('external',3)
        source_box=source.bounding_box();target_box=target.bounding_box()
        source.hover();page.mouse.down()
        page.mouse.move(source_box['x']+source_box['width']/2+10,source_box['y']+source_box['height']/2,steps=4)
        page.mouse.move(target_box['x']+target_box['width']/2,target_box['y']+target_box['height']/2,steps=15)
        page.mouse.up()
        moved=wait_call('swapItems',before+1)
        assert moved['fromSlot']==1 and moved['toSlot']==4 and moved['fromType']=='player' and moved['toType']=='drop' and moved['count']==2,moved
        passed.append('real React drag and drop reaches original swap callback')
        setup()
        send('refreshSlots',{'items':[{'inventory':'player','item':{'slot':1,'name':'water','count':3,'weight':1500,'metadata':{}}}]})
        expect(slot('player',0)).to_contain_text('3x')
        passed.append('server slot refresh preserves original rendering')
        for _ in range(4): setup()
        expect(page.locator('.void-pane-caption')).to_have_count(2)
        expect(page.locator('.void-survivor')).to_have_count(1)
        expect(page.locator('.void-inventory-chrome')).to_have_count(1)
        shop=copy.deepcopy(external);shop.update(type='shop',id='qa-shop',label='MERCANTE TEST')
        shop['items']=[{'slot':1,'name':'water','count':25,'weight':500,'price':20,'metadata':{}}]
        send('setupInventory',{'leftInventory':copy.deepcopy(player),'rightInventory':shop})
        expect(page.locator('[data-void-role="external"]')).to_contain_text('MERCANTE TEST')
        expect(page.locator('.void-pane-caption')).to_have_count(2)
        empty=copy.deepcopy(external);empty['items']=[]
        send('setupInventory',{'leftInventory':copy.deepcopy(player),'rightInventory':empty})
        expect(page.locator('[data-void-role="external"]')).to_contain_text('TERRENO TEST')
        expect(page.locator('[data-void-role="external"] .inventory-slot .item-slot-wrapper')).to_have_count(0)
        passed.append('repeated setup, shop and empty vicinity preserve original React without duplicate chrome')
        setup()
        if screenshots:
          screenshots.mkdir(parents=True,exist_ok=True)
          page.screenshot(path=str(screenshots/'desktop.png'),full_page=True)
        for width,height in [(1366,768),(1280,720)]:
          page.set_viewport_size({'width':width,'height':height});page.wait_for_timeout(100)
          for selector in ['[data-void-role="player"]','[data-void-role="external"]','.inventory-control']:
            box=page.locator(selector).bounding_box()
            assert box and box['x']>=-1 and box['x']+box['width']<=width+1,(selector,width,box)
          assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),'Horizontal overflow'
        passed.append('panels remain visible at 1920,1366 and1280 widths')
        page.get_by_role('button',name='Chiudi',exact=True).click()
        wait_call('exit')
        send('closeInventory')
        expect(page.locator('.inventory-wrapper')).to_have_count(0)
        expect(page.locator('.void-inventory-chrome')).to_be_hidden()
        assert page.evaluate("getComputedStyle(document.body).backgroundColor")=='rgba(0, 0, 0, 0)'
        passed.append('original exit callback and close remove all theme chrome')
        assert not errors,errors
        browser.close()
      print('PASS:',len(passed),'scenarios:', '; '.join(passed))
    finally:server.shutdown();server.server_close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resource',type=Path,required=True,help='Existing complete ox_inventory with the patch applied')
    parser.add_argument('--chromium',default='/usr/bin/chromium')
    parser.add_argument('--screenshots',type=Path)
    args=parser.parse_args();run(args.resource,args.screenshots,args.chromium)
