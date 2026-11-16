---
title: The Night Shift
desk:
  top: a heavy dark wooden desk
  phones: [AISLE, VAN, COUGH]
  rings: 4
terminal:
  title: COUNCIL
  width: 60
  keys:
    x: menu
    l: log
    r: record-*
---

<!-- speaker: Control -->

<!-- note: The desk at rest. -->

<!-- hesitation: 2 -->

<!-- ping: his room | 200, 0.6 -->

<!-- hesitation: 1.5 -->

<!-- ping: the hall | 90, 2 -->

He is in the hall.

<!-- moving -->

He is up and walking, past the doors, past the laundry room, toward the end of the hall where the stairs go down.

<!-- ping: the stairwell | 180, 3 -->

<!-- moving -->

Oh, no.

```terminal
> council
panel: menu = MENU | OPERATOR: CONTROL | NIGHT 1
  1  SUBJECTS          2  LOG
keys: X MENU
wait: 1.5
> 1
panel: matches = SUBJECTS | 1 MATCH
  1  SUBJECT
> open 1
panel: record-1 = RECORD | SUBJECT 1 OF 1 | PAGE 1 OF 1
NAME ........ SUBJECT
STATUS ...... CONTAINED
PLATE ....... <!-- redact: XKC 4417 -->
keys: L LOG, X MENU
```

There he is. He does not go out at this hour.

<!-- lift: mug -->

Cold.

<!-- call: AISLE -->

<!-- speaker: Aisle -->

Hello?

<!-- speaker: Control -->

Go to the store.

<!-- call: VAN -->

<!-- speaker: Van -->

Van here.

<!-- speaker: Control -->

Follow him.

<!-- call: AISLE -->

<!-- speaker: Aisle -->

He looked at me.

<!-- speaker: Cashier -->

Eight?

<!-- speaker: Van -->

The door will not open.

<!-- speaker: Control -->

Go home.

<!-- /call -->

<!-- text: AISLE | He smiled at me -->

<!-- reply -->

Good. Let him wonder.

```terminal
> l
panel: log = LOG | NIGHT 1
22:40. Shift opened.
type: 23:21. Grocery store. Watcher in place.
```

<!-- print -->

<!-- ring: COUGH -->

<!-- call: COUGH -->

<!-- speaker: Cough -->

I am sick.

<!-- speaker: Control -->

Good.

<!-- /call -->

<!-- image (feed): an aisle seen from a camera high in a corner -->

There she is.

<!-- static: 3 -->

```terminal
type (Council): WHAT <!-- hesitation --> DO WE DO WITH IT
```

<!-- strike -->

<!-- switch: BAD -->

<!-- static: 2 -->

<!-- speaker: Council -->

Bad.

<!-- speaker: Control -->

Bad it is.

```terminal
> r
set: STATUS ...... LOOSE
SEARCHING .... {2} DONE
```

<!-- sound: a jet passes over -->

<!-- speaker: Van -->

Boss?

<!-- speaker: Control -->

<!-- call: VAN -->

Go home, Van.

<!-- /call -->

<!-- image (full): a desk long ago, by candlelight -->

The man before me had a candle.

<!-- /image -->

<!-- live: tv -->

<!-- off: tv -->

<!-- look: radar -->

<!-- gain: 9 -->

Keep an eye on him.

<!-- gain: 3 -->

It was clutter.

<!-- lamp: off -->

<!-- fade: to-black -->

<!-- switch: GOOD -->

<!-- hesitation: 1.5 -->

<!-- fade: from-black, 23:40 -->

<!-- ping: the hall -->

<!-- lamp: on -->

He came back.

<!-- tablet -->

```page
url: forum.board

# The Forum

## Recent

### [Headlights, three nights running](forum.board/t/headlights)

### Coughing behind me in line
```

They have a word for headlights. Brighting.

```page
url: forum.board/t/headlights

# Headlights

Brighting, three nights running, and a cough in every line.

<!-- player -->
```

<!-- live: tablet -->

<!-- replay: tablet | He is in the hall. -->

<!-- speaker: Van -->

<!-- heard: tablet -->

Be patient.

<!-- speaker: Control -->

Very good words.

<!-- /tablet -->

<!-- video (tv): dog.webm | a small dog spinning after its own tail -->

Look at him go.

<!-- bell -->

```terminal
> x
```

Back to the menu.

```terminal
alert: INVALID OPTION
```

<!-- hesitation: 2 -->

<!-- sleep -->
