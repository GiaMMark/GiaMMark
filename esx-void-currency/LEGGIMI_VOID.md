# Valuta Void — ESX 1.16.3 e ox_inventory

Questo pacchetto modifica la versione di `es_extended` che hai fornito e aggiunge
un adattatore a `ox_inventory`. Contanti e denaro sporco diventano un'unica moneta
visualizzata come **Void**. Il nome interno resta **money** per compatibilità con
negozi, stipendi e API ESX esistenti. La banca resta un saldo separato, senza
modificare il suo importo; i messaggi monetari ESX usano la valuta Void.

## Installazione a server spento

La conversione viene salvata dai normali salvataggi del server. Prima di installare,
esegui un backup del database e delle cartelle `es_extended` e `ox_inventory`.
La fusione non conserva la provenienza dei vecchi contanti e del denaro sporco:
per tornare ai due saldi originali serve il backup.

1. Ferma completamente il server. Sostituisci la cartella `es_extended` con quella
   inclusa, basata sul tuo allegato. Non serve importare alcun SQL per questa modifica.
2. Applica l'adattatore alla tua cartella **esistente** `ox_inventory`. Il pacchetto
   non contiene una copia sostitutiva di ox_inventory e non riscrive `data/items.lua`.

   **Su Windows:** estrai tutto lo ZIP, apri la cartella `ox_patch` e fai doppio
   clic su **`INSTALLA_VOID_WINDOWS.cmd`**. Incolla il percorso della cartella
   ox_inventory quando richiesto, senza il simbolo `>` del prompt. Non serve
   aprire la console interattiva Python. I file della cartella ox_patch devono
   restare insieme.

   In alternativa, con Python 3.10 o successivo, dalla cartella estratta del pacchetto:

   ```sh
   python3 ox_patch/apply-ox-patch.py /percorso/resources/ox_inventory
   ```

   Su Windows puoi usare `py -3` al posto di `python3`, passando il percorso reale
   della tua cartella ox_inventory fra virgolette se contiene spazi.
   L'installer conserva il manifest originale in
   `fxmanifest.lua.before-void-currency`, copia l'add-on e registra gli avvii.
   Puoi rieseguirlo: non duplica le istruzioni. Un add-on preesistente diverso
   o un manifest con dichiarazioni Void non riconosciute richiedono una revisione
   manuale, così non vengono sovrascritti file personalizzati.

   Senza Python: copia `ox_patch/void_currency.lua` dentro `ox_inventory` e
   aggiungi **alla fine** del suo `fxmanifest.lua`:

   ```lua
   client_script 'void_currency.lua'
   server_script 'void_currency.lua'
   void_currency '1.0.0'
   ```

3. Se hai già una riga `inventory:accounts` nel server.cfg, imposta l'elenco valuta
   a `money`:

   ```cfg
   set inventory:accounts ["money"]
   ```

4. Mantieni le dipendenze esistenti del tuo server. Avvia `es_extended` dopo
   `esx_lib` e `oxmysql`, e `ox_inventory` dopo `es_extended`. L'add-on gira dentro
   ox_inventory: non serve un nuovo comando `ensure void_currency`.
5. Aggiorna o disattiva le risorse di denaro sporco/riciclaggio. Le ricompense che
   devono pagare Void devono usare `money`, per esempio:

   ```lua
   xPlayer.addMoney(100, 'Ricompensa survival')
   -- oppure:
   xPlayer.addAccountMoney('money', 100, 'Ricompensa survival')
   ```

   Il vecchio account `black_money` è ritirato. Non viene aliasato a `money`:
   riciclare fra due nomi dello stesso saldo renderebbe errati gli accrediti e
   gli addebiti. Anche script, negozi, loot e ricette che creavano direttamente
   item `black_money` devono pagare/creare `money` dopo l'aggiornamento.
6. Avvia il server e prova il primo accesso con un personaggio di test.

## Conversione e dati esistenti

- Con ox_inventory, gli item negli slot sono la fonte del saldo. Ogni slot
  `black_money` diventa `money` mantenendo quantità, posizione e metadata.
  I vecchi conti JSON ESX, che possono essere copie sincronizzate, non vengono
  sommati una seconda volta. Esempio: 100 money + 40 black_money diventano 140 Void,
  anche se `users.accounts` contiene già 100 e 40.
- Al normale salvataggio i dati vengono memorizzati con il solo account `money`
  e gli item convertiti. Le riconnessioni non aggiungono di nuovo il vecchio saldo.
- Depositi, bagagliai, vani portaoggetti e loot caricati dal loader standard ox
  vengono convertiti quando si aprono/caricano; quantità, slot e metadata restano
  conservati e il peso viene ricalcolato per l'item money. Il successivo normale
  salvataggio del contenitore registra i nomi convertiti.
- La vecchia definizione dell'item `black_money` resta disponibile come supporto
  alla lettura dei contenitori precedenti. Non cancellarla da `data/items.lua`:
  il loader ox la deve riconoscere prima della conversione. Non è un secondo
  account spendibile né una destinazione per nuove ricompense.
- Con inventario ESX standard, il loader somma i due vecchi conti una volta e
  ritira `black_money`. La banca, inclusi eventuali saldi negativi, viene conservata.
- Dati corrotti, slot duplicati, quantità fuori limite o formati di inventario
  personalizzati non riconosciuti bloccano l'accesso prima della creazione del
  player, senza effettuare salvataggi parziali.

## Verifica in gioco

1. Con un personaggio di test contenente 100 money e 40 black_money, controlla
   che l'inventario mostri solo il tipo di moneta **Void**, per un totale di 140.
   Due stack conservati possono essere uniti normalmente dall'inventario.
2. Compra un oggetto, ricevi una ricompensa e trasferisci una parte dei Void.
   Esci, lascia completare il salvataggio e rientra: il totale non deve aumentare.
3. Controlla che oggetti, slot, metadata e saldo bancario siano conservati.
4. Apri un vecchio deposito con denaro sporco e verifica la conversione in Void.
5. Controlla le console: `ox-void-adapter-missing` indica che mancano le righe nel
   manifest; `ox-void-adapter-not-ready` indica che l'add-on non si è inizializzato.
   In questi casi controlla prima gli errori ox; non vengono sovrascritti i saldi.

L'adattatore richiede la struttura standard ox_inventory con i moduli
`modules.items.shared` e `modules.inventory.server`, `Inventory.Load` e
`Inventory.SlotWeight`. Un fork che cambia questi contratti richiede un adattamento.
Le interfacce di risorse esterne con nomi o simboli valuta scritti direttamente
nel loro codice devono essere aggiornate separatamente: l'add-on rinomina la
valuta nell'inventario ox e il core aggiorna le proprie etichette e notifiche.

## Sorgenti e licenza

La cartella es_extended include il sorgente completo della risorsa fornita,
con le modifiche Void. La licenza GPL-3.0 originale e le attribuzioni sono conservate.
I file modificati sono elencati in `MODIFICHE_VOID.txt`.
La verifica automatica usa simulazioni Lua dei flussi reali e test dell'installer;
non è stata eseguita una sessione FiveM con il tuo database.
