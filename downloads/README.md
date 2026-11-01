# Log Discord per ox_inventory

[Scarica lo ZIP con i soli file modificati](./ox_inventory_solo_log.zip?raw=true)

1. Estrai lo ZIP nella posizione della risorsa `ox_inventory` esistente e sovrascrivi i file inclusi. Conserva gli altri file della risorsa.
2. Nel tuo `server.cfg`, prima della riga che avvia `ox_inventory`, aggiungi:

   ```cfg
   set inventory:discordWebhook "INSERISCI_QUI_IL_TUO_WEBHOOK_DISCORD"
   ```

3. Riavvia la risorsa `ox_inventory`.

Il webhook si configura solo sul server: usa `set`, senza replicarlo ai client. Non pubblicare il tuo `server.cfg` con il token.

Lo ZIP contiene 10 file server modificati soltanto per aggiungere i log e il nuovo modulo `modules/audit/server.lua`. Sono coperti inventari, trasferimenti, oggetti, armi, negozi, comandi amministrativi, vestiti, zaini, armature, crafting, combinazioni, depositi e tentativi di exploit rilevati.

Il logger accoda gli invii e gestisce retry e limiti Discord. La coda resta in memoria (massimo 10000 eventi); i dettagli molto lunghi vengono abbreviati. I test con runtime Lua simulato sono passati; avvio e consegna Discord vanno verificati sul server FiveM.
