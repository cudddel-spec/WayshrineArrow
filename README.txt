WayshrineArrow 0.1.0
====================

AI disclosure: The code of this addon was written with the help of an AI
assistant (Claude by Anthropic). The author reviewed it, tested it in-game
and is responsible for it.

--- English ---

A small, movable arrow on your HUD points in a straight line to the nearest
wayshrine of the map you are on - known or unknown. Made for players who like
to travel on foot, explore a map anew or just want more immersion.

- Target: nearest wayshrine, nearest unknown wayshrine or nearest known one
  (setting, keybind or /wsarrow target)
- Optional below the arrow: name, status (known / unknown) and distance
- Separate colors for known and unknown wayshrines
- Hidden in delves, public and group dungeons, arenas, the Infinite Archive,
  trials, battlegrounds, houses and inside buildings (inns, banks, shops ...);
  optionally in combat or close to the target
- Settings with LibAddonMenu-2.0 (optional)

Commands: /wsarrow [on | off | lock | unlock | target | reset | account | character | debug | settings]
Settings are separate for each server and account; "/wsarrow character" gives
the current character its own settings, "/wsarrow account" switches back.
In the settings menu you can copy the settings of another character.
Move the arrow: /wsarrow unlock, drag it with the mouse, /wsarrow lock.

The distance is measured from your own movement, so on a map you have not
walked on yet it appears after a few steps.

Buildings are recognized by their door. If a character logs in inside a
building for the very first time, the arrow is shown until you walk out and
in once; after that it is remembered, also across logins.

--- Deutsch ---

Ein kleiner, verschiebbarer Pfeil im HUD zeigt in Luftlinie zum nächsten
Wegschrein der aktuellen Karte - bekannt oder unbekannt. Gedacht für alle, die
gern zu Fuß unterwegs sind, eine Karte neu erkunden oder einfach mehr
Immersion möchten.

- Ziel: nächster Wegschrein, nächster unbekannter oder nächster bekannter
  (Einstellung, Tastenbelegung oder /wsarrow target)
- Wahlweise unter dem Pfeil: Name, Status (bekannt / unbekannt) und Entfernung
- Eigene Farben für bekannte und unbekannte Wegschreine
- Keine Anzeige in Gewölben, öffentlichen Verliesen, Gruppenverliesen, Arenen,
  dem Endlosen Archiv, Prüfungen, Schlachtfeldern, Häusern und in Gebäuden
  (Gasthäuser, Banken, Läden ...); wahlweise auch im Kampf oder nahe am Ziel
- Einstellungen mit LibAddonMenu-2.0 (optional)

Befehle: /wsarrow [on | off | lock | unlock | target | reset | account | character | debug | settings]
Einstellungen sind je Server und Account getrennt; "/wsarrow character" gibt dem
aktuellen Charakter eigene Einstellungen, "/wsarrow account" schaltet zurück.
Im Einstellungsmenü kannst du die Einstellungen eines anderen Charakters übernehmen.
Pfeil verschieben: /wsarrow unlock, mit der Maus ziehen, /wsarrow lock.

Die Entfernung wird aus deiner eigenen Bewegung vermessen; auf einer Karte,
auf der du noch nicht gelaufen bist, erscheint sie nach ein paar Schritten.

Gebäude werden an ihrer Tür erkannt. Loggt sich ein Charakter zum allerersten
Mal in einem Gebäude ein, bleibt der Pfeil sichtbar, bis du einmal hinaus- und
wieder hineingehst; danach merkt sich das Addon das, auch über Logins hinweg.
