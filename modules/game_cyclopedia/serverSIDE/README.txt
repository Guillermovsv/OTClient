Cyclopedia -> Magical Archives: base spell damage
=================================================

The client side is done and needs nothing from you. The Magical Archives tab
sends extended opcode 220 the first time it opens:

    { "action": "spellDamage" }

and expects back:

    { "action": "spellDamage",
      "spells": [ { "id": 22, "min": 12, "max": 18, "kind": "damage" } ] }

"id" is the spell id (the value passed to spell:id() server side, which is what
gamelib/spells.lua stores as SpellInfo[...].id). "kind" is "damage" or
"healing". Spells missing from the list simply render without a damage row, so a
partial answer is fine.

These are BASE values: each spell's formula evaluated at the level and magic
level the spell itself requires. They are the same for every character and are
not what the logged in player would actually hit for. The client fetches them
once per session and labels the row "Base damage" / "Base healing".


Installing
----------

1. copy data/scripts/cyclopedia_spell_damage.lua into your server's data/scripts/
2. make sure the json lib is loaded, i.e. data/lib/lib.lua contains
       dofile('data/lib/json.lua')
3. reload scripts or restart the server


The catch
---------

Canary does not expose a spell's combat formula to Lua. The formula lives inside
the Combat object each spell script builds - either combat:setFormula(...) or the
CALLBACK_PARAM_LEVELMAGICVALUE callback - and there is no API to read it back
out. So the server cannot enumerate spell damage on its own.

The script therefore keeps a `formulas` table keyed by spell id, which you fill
in by copying the min/max expressions and the spell's level/magicLevel out of
your own spell scripts. It is a one-time copy per spell, and because unlisted
spells degrade gracefully you can do the ones that matter first.


Worth knowing
-------------

Because base damage is character independent, the server round trip is now
optional. The same numbers could be baked straight into
modules/gamelib/spells.lua as a static field, which would drop this script and
the opcode entirely.

Keeping it server side has one advantage: the values follow your datapack. Edit a
spell's formula, update the table here, and every client picks it up on next
login with no client update to ship. If your spell balance is stable, baking the
numbers into the client is simpler.
