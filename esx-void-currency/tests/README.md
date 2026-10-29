Esegui dalla cartella esx-void-currency. I test Lua usano API ESX/ox simulate e richiedono Lua 5.3+ oppure Fengari.

python3 -m unittest discover -s tests -p test_installer.py
lua tests/currency_smoke.lua
lua tests/locale_smoke.lua
lua tests/ox_addon_smoke.lua
lua tests/override_smoke.lua
lua tests/containers_smoke.lua

Non avviano FiveM e non si collegano al database.
