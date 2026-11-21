-- English texts (default). Other languages override single entries with SafeAddString.
local strings = {
    SI_BINDING_NAME_WAYSHRINEARROW_TOGGLE = "Show / hide wayshrine arrow",
    SI_BINDING_NAME_WAYSHRINEARROW_CYCLE_TARGET = "Switch target (all / unknown / known)",

    SI_WAYSHRINEARROW_KNOWN = "known",
    SI_WAYSHRINEARROW_UNKNOWN = "unknown",
    SI_WAYSHRINEARROW_UNNAMED = "Wayshrine",
    SI_WAYSHRINEARROW_DRAG_HINT = "Wayshrine arrow – drag to move",
    SI_WAYSHRINEARROW_METERS = "<<1>> m",
    SI_WAYSHRINEARROW_KILOMETERS = "<<1>> km",

    SI_WAYSHRINEARROW_TARGET_ALL = "Nearest wayshrine (known or unknown)",
    SI_WAYSHRINEARROW_TARGET_UNKNOWN = "Nearest unknown wayshrine",
    SI_WAYSHRINEARROW_TARGET_KNOWN = "Nearest known wayshrine",

    SI_WAYSHRINEARROW_MSG_ON = "Wayshrine arrow shown.",
    SI_WAYSHRINEARROW_MSG_OFF = "Wayshrine arrow hidden.",
    SI_WAYSHRINEARROW_MSG_LOCKED = "Wayshrine arrow locked.",
    SI_WAYSHRINEARROW_MSG_UNLOCKED = "Wayshrine arrow unlocked – drag it with the mouse, then lock it again (/wsarrow lock).",
    SI_WAYSHRINEARROW_MSG_TARGET = "Target: <<1>>",
    SI_WAYSHRINEARROW_MSG_RESET = "Position reset.",
    SI_WAYSHRINEARROW_MSG_HELP = "/wsarrow [on | off | lock | unlock | target | reset | debug | settings]",

    SI_WAYSHRINEARROW_OPT_ENABLED = "Show arrow",
    SI_WAYSHRINEARROW_OPT_TARGET = "Arrow points to",
    SI_WAYSHRINEARROW_OPT_TARGET_TT = "\"Unknown\" is handy for exploring: once you discover a wayshrine, the arrow turns to the next one.",
    SI_WAYSHRINEARROW_OPT_LOCKED = "Lock position",
    SI_WAYSHRINEARROW_OPT_LOCKED_TT = "Unlock to drag the arrow with the mouse (open the cursor with the '.' key or any menu that shows the HUD).",
    SI_WAYSHRINEARROW_OPT_RESET = "Reset position",
    SI_WAYSHRINEARROW_OPT_HEADER_DISPLAY = "Display",
    SI_WAYSHRINEARROW_OPT_SIZE = "Arrow size",
    SI_WAYSHRINEARROW_OPT_FONT_SIZE = "Text size",
    SI_WAYSHRINEARROW_OPT_ALPHA = "Opacity",
    SI_WAYSHRINEARROW_OPT_SHOW_NAME = "Show wayshrine name",
    SI_WAYSHRINEARROW_OPT_SHOW_STATUS = "Show status (known / unknown)",
    SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE = "Show distance",
    SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE_TT = "The distance is measured while you move. On a new map it appears after a few steps.",
    SI_WAYSHRINEARROW_OPT_KNOWN_COLOR = "Color for known wayshrines",
    SI_WAYSHRINEARROW_OPT_UNKNOWN_COLOR = "Color for unknown wayshrines",
    SI_WAYSHRINEARROW_OPT_HIDE_COMBAT = "Hide in combat",
    SI_WAYSHRINEARROW_OPT_HIDE_NEAR = "Hide when closer than (m)",
    SI_WAYSHRINEARROW_OPT_HIDE_NEAR_TT = "0 = never hide. Needs the distance, so it works after a few steps on a new map.",
    SI_WAYSHRINEARROW_OPT_INFO = "The arrow is hidden in delves, public and group dungeons, arenas, the Infinite Archive, trials, battlegrounds, houses and inside buildings entered through a door (inns, banks, shops ...).",
}

for id, text in pairs(strings) do
    ZO_CreateStringId(id, text)
    SafeAddVersion(id, 1)
end
