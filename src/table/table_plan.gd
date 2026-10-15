extends RefCounted
class_name TablePlan

## TablePlan - what an episode decides when it is loaded: everything the table reads to show it,
## and nothing that changes while it plays. A part of [TableMedium].
##
## The episode as the panel handed it over and its reading parsed, the look, the seed, how the
## cards come and are shown, where the camera, the deck's shuffle and every card's place are, and
## the small repeatable differences a hand makes. [method TableMedium._ensure_doc] starts a fresh
## one for every new episode and it and [method TableMedium._build_episode] fill it in, drawing
## from one seeded stream in a fixed order - so the same episode is the same plan, and the order of
## those statements is part of the show.
##
## WHY IT IS ITS OWN OBJECT: the table is a pure function of (this, show time). What poses the
## cards, shuffles the deck and lights the room reads it and never writes it; what changes as the
## show plays (the deck's place now, the box, a search, the built meshes) stays with the medium.
## A part that only poses can be handed a plan instead of the whole medium (next/structure.md,
## step 7), and work that is a pure function of a plan and a time can be done early, late or on
## another thread and still land where it belongs.

var pay: Dictionary = {}           # the episode, as the panel handed it over (CardEpisode.document)
var parse: Dictionary = {}
var seed_value := 0
var look: Dictionary = {}
var staging: Dictionary = CardTable.STAGING.duplicate()   # how the cards come and are shown (CardTable.staging_of)
var cards_from := "deck"                 # where they come from: the reading's opening verb's, else the staging's
var alone := false                   # a drawn card with text on either face is held up alone
var cam_base := Transform3D.IDENTITY
var lamp_base := 1.6                 # the lamp's light before a candle takes the key from it
var mid := Vector3.ZERO            # where it is shuffled, in the middle of the table
var slots: Array = []              # per card: Transform3D where it lies in the spread
var jump_land := Vector3.ZERO
var deck_n := 0                    # how many cards the deck holds: a mesh each ([method TableMedium._deck_count])
var slot_jit: Array = []           # per deck slot: Vector3(x, z, yaw)
var lay_jit: Array = []            # per shown card: a small, repeatable placement difference
var ambient := {}                  # the room's own ambient, for a table with no light of its own
