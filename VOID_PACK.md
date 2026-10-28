# VOID · Pack iniziale

Due resource indipendenti con lo stesso stile minimal monocromatico:

- `void_loadscreen`: caricamento, musica e introduzione alla community; standalone.
- `void_characters`: identity e multicharacter; adattatori ESX, QBCore e Qbox.

## Installazione del pack

Estrai lo ZIP: le due cartelle devono trovarsi in `resources/[void]/`, mantenendo i nomi originali. Conserva e adatta i tuoi file `config.lua` quando aggiorni un'installazione già personalizzata.

Il preset del multicharacter è ESX + ox_inventory + illenium-appearance. Installa prima framework e relative dipendenze, importa `void_characters/sql/schema.sql` nel loro database e segui i passaggi della [guida Characters](void_characters/README.md), inclusa la configurazione ESX e la disattivazione del vecchio selettore. Disattiva anche qualsiasi altra loading screen.

```cfg
set onesync on
setr inventory:framework "esx"

ensure void_loadscreen
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure illenium-appearance
ensure void_characters
```

Personalizza `void_loadscreen/config.lua` per branding, musica, consigli, regole e link reali del server. Personalizza `void_characters/config.lua` per slot, identità, aspetto e spawn. Una nuova connessione è necessaria per provare la loading screen.

Characters 0.1.1 segnala alla loadscreen quando il selettore è pronto. La versione precedente chiude comunque la loading screen con le native FiveM, ma senza la dissolvenza coordinata. Aggiorna entrambe le resource per utilizzare la nuova transizione.

Se vuoi solo la loadscreen, installa soltanto `void_loadscreen`: non richiede framework, ox_lib, database o Characters. Per altri selettori usa la modalità di chiusura appropriata descritta nella [guida Loadscreen](void_loadscreen/README.md).

## Download

- [Solo loadscreen](https://github.com/GiaMMark/GiaMMark/raw/refs/heads/void-characters/downloads/void_loadscreen.zip)
- [Solo Characters aggiornato](https://github.com/GiaMMark/GiaMMark/raw/refs/heads/void-characters/downloads/void_characters.zip)
- [Pack con entrambe le resource e questa guida](https://github.com/GiaMMark/GiaMMark/raw/refs/heads/void-characters/downloads/void_pack.zip)

Gli ZIP contengono codice, configurazione, documentazione e asset locali. I test Lua e Chromium verificano logica e interfaccia con API FiveM simulate; non sostituiscono il collaudo con il tuo FXServer, database e versioni dei framework.
