'use strict';

(() => {
  const raw = window.VOID_INVENTORY && typeof window.VOID_INVENTORY === 'object' ? window.VOID_INVENTORY : {};
  const text = (value, fallback = '', max = 120) => typeof value === 'string' ? value.slice(0, max) : fallback;
  const labels = raw.labels && typeof raw.labels === 'object' ? raw.labels : {};
  const words = {
    vicinity: text(labels.vicinity, 'VICINANZE'), inventory: text(labels.inventory, 'DOTAZIONE PERSONALE'),
    quantity: text(labels.quantity, 'QUANTITÀ'), health: text(labels.health, 'SALUTE'), armor: text(labels.armor, 'ARMATURA'),
    weight: text(labels.weight, 'PESO'), containers: text(labels.containers, 'CONTENITORI'),
    preview: text(labels.preview, 'Anteprima personaggio disponibile in gioco'), close: text(labels.closeHint, 'ESC · CHIUDI')
  };
  if (typeof raw.accent === 'string' && /^#[a-f\d]{6}$/i.test(raw.accent)) document.documentElement.style.setProperty('--void-accent', raw.accent);
  const columns = Number.isInteger(raw.columns) ? Math.min(6, Math.max(3, raw.columns)) : 4;
  document.documentElement.style.setProperty('--void-player-columns', String(columns));
  const sections = (Array.isArray(raw.sections) ? raw.sections : [{label:'DOTAZIONE',start:1},{label:'TASCHE',start:13},{label:'CARICO',start:21}])
    .filter((s) => s && Number.isInteger(s.start) && s.start >= 1 && s.start <= 500)
    .map((s) => ({label:text(s.label,'SEZIONE',50),start:s.start})).sort((a,b) => a.start-b.start);
  const definitions = {};
  let player = {items:[],slots:0};
  let itemMap = new Map();
  let imagepath = 'nui://ox_inventory/web/images';
  let status = {};
  let scheduled = false;
  let dirty = true;
  let wasOpen = false;

  function element(tag, className, value) {
    const node = document.createElement(tag); node.className = className;
    if (value !== undefined) node.textContent = value;
    return node;
  }
  function number(value) { return typeof value === 'number' && Number.isFinite(value) ? value : null; }
  function weight(value) { const n=number(value); return n === null ? '—' : `${(n/1000).toLocaleString('it-IT',{maximumFractionDigits:1})} KG`; }
  function title(item) { return text(item?.metadata?.label,text(definitions[item?.name]?.label,text(item?.name,'Oggetto')),90); }
  function iconURL(item) {
    const explicit = item?.metadata?.imageurl;
    if (typeof explicit === 'string') {
      try { const u=new URL(explicit); if (['https:','http:','nui:'].includes(u.protocol)) return u.href; } catch (_) { /* Use ordinary item image. */ }
    }
    const resolved = definitions[item?.name]?.image;
    if (!item?.metadata?.image && typeof resolved === 'string') {
      try { const u=new URL(resolved); if (['https:','http:','nui:'].includes(u.protocol)) return u.href; } catch (_) { /* Definition still stores a filename. */ }
    }
    const name=text(item?.metadata?.image,text(resolved,text(item?.name,'')),200);
    if (!name || /[\\\u0000-\u001f]/.test(name) || name.split('/').includes('..')) return '';
    return `${imagepath.replace(/\/$/,'')}/${name.toLowerCase().endsWith('.png') ? name : `${name}.png`}`;
  }
  function image(item, className='void-item-image') {
    const img=element('img',className); img.alt=''; img.src=iconURL(item);
    img.addEventListener('error',()=>{img.hidden=true;});
    return img;
  }
  async function post(action,data) {
    if (typeof GetParentResourceName !== 'function') return null;
    try {
      const response=await fetch(`https://${GetParentResourceName()}/${action}`,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(data)});
      if (!response.ok) return null;
      return await response.json();
    } catch (_) { return null; }
  }
  function use(slot) {
    if (!itemMap.has(slot)) return;
    post('useItem',slot);
  }

  const chrome=element('div','void-inventory-chrome'); chrome.hidden=true;
  const brand=element('header','void-brand');
  const logo=element('img','void-logo');logo.alt=text(raw.brand,'VOID SURVIVAL',40);
  logo.src=/^assets\/[A-Za-z0-9_.-]+\.png$/i.test(raw.logo) ? raw.logo : 'assets/void-logo.png';
  logo.addEventListener('error',()=>{logo.hidden=true;});
  brand.append(logo,element('span','void-brand-label',text(raw.brand,'VOID SURVIVAL',40)));
  const closeHint=element('span','void-close-hint',words.close);
  const avatar=element('section','void-avatar-zone');avatar.setAttribute('aria-label','Personaggio');
  const fallback=element('div','void-preview-fallback');
  const outline=element('div','void-preview-outline');outline.setAttribute('aria-hidden','true');
  outline.innerHTML='<svg viewBox="0 0 180 340" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M90 17c-16 0-27 11-27 28 0 17 12 30 27 30s27-13 27-30c0-17-11-28-27-28Zm-25 66L41 96l-14 71-12 50 14 5 20-45 12-39 1 65-8 51 1 67 20 1 10-67 5-36 6 36 9 67 20-1 1-67-8-51 1-65 12 39 20 45 14-5-12-50-14-71-24-13-16 9-17-9Z"/></svg>';
  fallback.append(outline,element('span','void-preview-note',words.preview));
  const rotate=element('div','void-rotate-controls');
  for (const direction of [-1,1]) {
    const button=element('button','void-rotate',direction===-1?'‹':'›');button.type='button';
    button.setAttribute('aria-label',direction===-1?'Ruota personaggio a sinistra':'Ruota personaggio a destra');
    button.disabled=true;button.addEventListener('click',()=>{if(status.previewActive===true)post('voidPreviewRotate',{direction});});rotate.append(button);
  }
  avatar.append(fallback,rotate);
  const equipment=element('section','void-equipment');equipment.setAttribute('aria-label',words.containers);
  const stats=element('section','void-survivor-status');stats.setAttribute('aria-label','Condizioni del personaggio');
  for (const key of ['health','armor','weight']) {
    const row=element('div','void-status-row');row.dataset.stat=key;
    row.append(element('span','void-stat-label',words[key]),element('strong','void-stat-value','—'));
    const meter=element('span','void-stat-meter');meter.append(element('i',''));row.append(meter);stats.append(row);
  }
  const weapons=element('section','void-weapons');weapons.setAttribute('aria-label','Armi trasportate');
  const quickbar=element('section','void-quickbar');quickbar.setAttribute('aria-label','Barra rapida');
  const footnote=element('span','void-footnote','TASTO DESTRO · AZIONI OGGETTO');
  chrome.append(brand,closeHint,avatar,equipment,stats,weapons,quickbar,footnote);document.body.append(chrome);

  function updateStatus() {
    for (const key of ['health','armor']) {
      const value=number(status[key]);const row=stats.querySelector(`[data-stat="${key}"]`);
      row.querySelector('strong').textContent=value===null?'—':`${Math.round(Math.min(100,Math.max(0,value)))}/100`;
      row.querySelector('i').style.width=value===null?'0%':`${Math.min(100,Math.max(0,value))}%`;
    }
    const actualWeight=number(status.weight) ?? player.items.reduce((sum,item)=>sum+(number(item.weight)??0),0);
    const max=number(status.maxWeight) ?? number(player.maxWeight);
    const row=stats.querySelector('[data-stat="weight"]');
    row.querySelector('strong').textContent=`${weight(actualWeight)} / ${weight(max)}`;
    row.querySelector('i').style.width=max&&max>0?`${Math.min(100,Math.max(0,actualWeight/max*100))}%`:'0%';
    fallback.hidden=status.previewActive===true;
    rotate.querySelectorAll('button').forEach((button)=>{button.disabled=status.previewActive!==true;});
    quickbar.querySelectorAll('button').forEach((button)=>{button.classList.toggle('is-active',Number(button.dataset.voidSlot)===status.weaponSlot);});
    weapons.querySelectorAll('button').forEach((button)=>{button.classList.toggle('is-active',Number(button.dataset.voidSlot)===status.weaponSlot);});
  }
  function itemButton(item, className, label) {
    const button=element('button',className);button.type='button';button.dataset.voidSlot=String(item.slot);
    button.title=title(item);button.setAttribute('aria-label',`${label}: ${title(item)}`);
    button.append(image(item),element('span','void-card-label',title(item)));
    button.addEventListener('click',()=>use(item.slot));return button;
  }
  function renderItems() {
    if (!dirty) return;dirty=false;
    equipment.replaceChildren();
    const containers=player.items.filter((item)=>item?.metadata?.container).slice(0,8);
    // Empty categories describe the body; they never claim an item is equipped.
    {
      const symbols = [
        ['Testa','M5 22c0-11 3-17 11-17s11 6 11 17M3 22h26M15 5v14M9 23v4'],
        ['Occhi','M3 15h4m5-1h8m5 1h4M7 12c-6 0-6 11 0 11s6-11 0-11Zm18 0c-6 0-6 11 0 11s6-11 0-11Z'],
        ['Volto','M6 11c7-2 13-2 20 0l-2 13-8 4-8-4-2-13Zm2 4 8 3 8-3M10 21h12M6 14 2 9m24 5 4-5'],
        ['Collo','m10 4-4 8 5 13 5 4 5-4 5-13-4-8M11 5l-1 8 6 10 6-10-1-8M16 24v4'],
        ['Torso','m10 5-8 6 4 8 5-3v13h10V16l5 3 4-8-8-6c-2 5-10 5-12 0Z'],
        ['Gambe','M8 4h16l2 25h-9l-1-15-1 15H6L8 4Zm0 5h16M16 4v10'],
        ['Polso','M12 2h8l1 7m0 14-1 7h-8l-1-7M8 9h16v14H8V9Zm4 3h8v8h-8v-8Z'],
        ['Mani','M9 28 4 16c-1-3 2-4 3-2l3 4V6c0-3 4-3 4 0v8-10c0-3 4-3 4 0v10-8c0-3 4-3 4 0v10-6c0-3 4-3 4 0v11l-4 7H9Z']
      ];
      for (const [name,path] of symbols) {
        const cell=element('span','void-equipment-empty');cell.title=`${name} · nessun contenitore associato`;cell.setAttribute('aria-label',cell.title);
        const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 32 32');svg.setAttribute('aria-hidden','true');
        const shape=document.createElementNS('http://www.w3.org/2000/svg','path');shape.setAttribute('d',path);svg.append(shape);cell.append(svg);equipment.append(cell);
      }
    }
    for (const item of containers) equipment.append(itemButton(item,'void-equipment-slot','Apri contenitore'));
    weapons.replaceChildren();
    const weaponItems=player.items.filter((item)=>typeof item.name==='string'&&item.name.startsWith('WEAPON_')).slice(0,2);
    for (let index=0;index<2;index++) {
      const item=weaponItems[index];
      if (item) {const button=itemButton(item,'void-weapon-card','Usa arma');button.prepend(element('span','void-card-index',String(item.slot)));weapons.append(button);}
      else {const empty=element('div','void-weapon-card is-empty');empty.append(element('span','void-card-index','—'),element('span','void-empty-weapon','ARMA'));weapons.append(empty);}
    }
    quickbar.replaceChildren();
    const count=Math.min(10,Math.max(5,Number.isInteger(raw.quickSlots)?raw.quickSlots:10));
    for (let slot=1;slot<=count;slot++) {
      const item=itemMap.get(slot);const button=element('button','void-quickslot');button.type='button';button.dataset.voidSlot=String(slot);
      button.append(element('span','void-quick-key',slot===10?'0':String(slot)));
      if (item) {button.append(image(item));button.title=title(item);button.setAttribute('aria-label',`Slot rapido ${slot}: ${title(item)}`);button.addEventListener('click',()=>use(slot));}
      else {button.disabled=true;button.setAttribute('aria-label',`Slot rapido ${slot} vuoto`);}
      quickbar.append(button);
    }
    updateStatus();
  }
  function replacePlayer(value) {
    if (!value||typeof value!=='object') return;
    const previous=player;
    player={...previous,...value};
    const list=Array.isArray(value.items)?value.items:(value.items&&typeof value.items==='object'?Object.values(value.items):previous.items);
    player.items=list.filter((item)=>item&&Number.isInteger(item.slot)&&item.slot>0&&typeof item.name==='string'&&Number(item.count)>0);
    itemMap=new Map(player.items.map((item)=>[item.slot,item]));dirty=true;
  }
  function schedule() {if(!scheduled){scheduled=true;requestAnimationFrame(decorate);}}
  function decorate() {
    scheduled=false;
    const wrapper=document.querySelector('.inventory-wrapper');const open=Boolean(wrapper);
    chrome.hidden=!open;document.body.classList.toggle('void-inventory-open',open);
    if (!wrapper) {wasOpen=false;return;}
    if (!wasOpen) {wasOpen=true;post('voidStatus',{}).then((response)=>{if(response?.ok&&response.status){status=response.status;updateStatus();}});}
    const panes=[...wrapper.querySelectorAll(':scope > .inventory-grid-wrapper')];
    panes.forEach((pane,index)=>{
      const role=index===0?'player':'external';pane.dataset.voidRole=role;
      if (!pane.querySelector(':scope > .void-pane-caption')) {
        const caption=element('div','void-pane-caption',role==='player'?words.inventory:words.vicinity);pane.prepend(caption);
      }
      if (role==='external') {
        pane.querySelectorAll('.inventory-slot').forEach((slot)=>{slot.dataset.voidOccupied=String(Boolean(slot.querySelector('.item-slot-wrapper')));});
      }
      if (role==='player') {
        const slots=[...pane.querySelectorAll('.inventory-grid-container > .inventory-slot')];
        slots.forEach((slot,index)=>{
          const slotNumber=index+1;slot.removeAttribute('data-void-section');slot.removeAttribute('data-void-heading-row');
          for (const section of sections) {
            const rowStart=Math.floor((section.start-1)/columns)*columns+1;
            if (slotNumber===rowStart) slot.dataset.voidSection=section.label;
            if (slotNumber>=rowStart&&slotNumber<rowStart+columns) slot.dataset.voidHeadingRow='true';
          }
        });
      }
    });
    const input=wrapper.querySelector('.inventory-control-input');if(input){input.setAttribute('aria-label',words.quantity);input.placeholder=words.quantity;}
    renderItems();
  }
  new MutationObserver(schedule).observe(document.getElementById('root'),{childList:true,subtree:true});
  window.addEventListener('message',(event)=>{
    const message=event.data;if(!message||typeof message!=='object')return;
    const data=message.data;
    if(message.action==='init'&&data&&typeof data==='object'){
      if(data.items&&typeof data.items==='object')Object.assign(definitions,data.items);
      if(typeof data.imagepath==='string')imagepath=data.imagepath;
      replacePlayer(data.leftInventory);
    } else if(message.action==='setupInventory'&&data&&typeof data==='object'){
      replacePlayer(data.leftInventory);
    } else if(message.action==='refreshSlots'&&data&&Array.isArray(data.items)){
      for(const entry of data.items){
        if(!entry||!(entry.inventory==='player'||entry.inventory===player.id||String(entry.inventory)===String(player.id)))continue;
        const item=entry.item;if(!item||!Number.isInteger(item.slot))continue;
        if(item.name&&Number(item.count)>0)itemMap.set(item.slot,item);else itemMap.delete(item.slot);
      }
      player.items=[...itemMap.values()].sort((a,b)=>a.slot-b.slot);dirty=true;
    } else if(message.action==='void:status'&&data&&typeof data==='object'){
      status=data;updateStatus();
    }
    schedule();
  });
  decorate();
})();
