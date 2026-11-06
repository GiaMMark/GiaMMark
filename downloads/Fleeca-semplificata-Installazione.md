# Fleeca — accesso semplificato

[Scarica lo ZIP](projectx-fleecabankrobbery-tstudio-semplificata.zip).

## Modifiche

- `Config.DisableEmployeePuzzle = true`: puzzle dei dipendenti disattivato.
- Il passo `Vault` usa `utk_fingerprint:Start(4, 6, 2)`, con gli stessi parametri dello scanner originale.
- Aggiornate etichette del caveau e indicazioni dopo il tastierino interno.
- Il fallimento del minigioco resta un fallimento: nessuna apertura automatica.

Sono modificati soltanto `config/config.lua` e `opensource/client/client.lua`. I file protetti da escrow e `.fxap` sono identici all'originale. Nello ZIP è inclusa anche una guida di installazione.

## Installazione

1. Conserva una copia della risorsa attuale e delle tue personalizzazioni.
2. Termina le rapine attive e arresta `projectx-fleecabankrobbery-tstudio`.
3. Estrai lo ZIP e sostituisci nella risorsa esistente `config/config.lua` e `opensource/client/client.lua`. Se hai personalizzazioni successive al pacchetto fornito, confrontale prima di sostituire i file.
4. Mantieni il nome della cartella `projectx-fleecabankrobbery-tstudio`, la licenza e tutte le dipendenze originali, inclusi `projectx-bridge`, `ox_lib`, `0r-pack1` e i minigiochi già utilizzati. Avvia `utk_fingerprint` prima della risorsa: ora serve anche per il caveau.
5. Riavvia `projectx-fleecabankrobbery-tstudio` e avvia una rapina nuova.

Lo ZIP contiene la risorsa completa; per aggiornare la stessa versione già installata sono sufficienti i due file indicati. Evita di avviare una seconda copia della risorsa.

## Verifiche eseguite

- Sintassi Lua dei due file modificati.
- Confronto delle callback `Vault` e `Fingerprint` in Lua 5.4: stesso minigioco e stessi parametri nei quattro casi di dipendenza presente/assente e risultato positivo/negativo.
- Integrità dello ZIP e confronto dei file con il pacchetto originale.

Non è stato eseguito un server FiveM. La progressione principale è protetta da escrow: l'opzione di configurazione è esposta dalla risorsa originale, ma il suo effetto completo deve essere verificato in gioco. L'indicazione dal tastierino al fusibile presume che il puzzle disattivato permetta quel passaggio.

## Prova sul server

1. Avvia una rapina nuova e controlla che non sia richiesto il puzzle dei dipendenti.
2. Completa le interazioni disponibili fino al caveau e controlla che la guida corrisponda alla progressione effettiva.
3. Alla porta grande verifica che compaia lo stesso gioco delle impronte dello scanner.
4. Prova un fallimento: la porta deve rimanere chiusa. Poi prova un successo e controlla l'apertura anche con un secondo giocatore.
5. Controlla console/F8, reset della banca e avvio di una nuova rapina.

La pubblicazione su GitHub non installa né avvia la risorsa sul tuo server.
