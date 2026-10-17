# Password Logic

> How the playoff password in *NHL Hockey* is built. EA's original notes, converted from `src/_docs/password_layout.readme`.

## Formula

```text
PW = V0 + R0(V1 + R1(V2 + R2(...)))
```

The password is displayed as a base 30 number using the numerals `BCDFGHJKLMNPRSTVWXYZ0123456789`.

## Fields

`V` is a field's value and `R` is its radix (how many values the field can take).

| Field | Meaning | Radix |
|---|---|---:|
| V0 | Check sum = (sum of V1 through V22) and 511 | R0 = 512 |
| V1 | Game one, top team wins | R1 = 5 |
| V2 | Game one, bottom team wins | R2 = 5 |
| V3-V16 | Same as V1/V2 for games 2 through 8 | R = 5 |
| V17 | Win bits: a set bit means the top team wins (see the tree below) | R17 = 2^14 |
| V18 | Joystick control: 0 = one player, 1 = team mates, 2 = two player cont. 1 winner, 3 = two player cont. 2 winner | R18 = 4 |
| V19 | Team tree location 0-15: which team on the starting tree continues through the playoff | R19 = 16 |
| V20 | Playoff round | R20 = 4 |
| V21 | Best of seven game, or 7 for single game elimination | R21 = 8 |
| V22 | Starting teams lookup value | R22 = 32 |

## Win bit tree

Each bit of V17 is one game of the bracket. Only the top half of the tree is drawn; the other side is interpolated.

```text
    Round 0		   Round 1		   Round 2

_________________
Game 1
Bit 0		_________________
_________________
		Game 1
_________________	Bit 8		_________________
Game 2
Bit 1		_________________
_________________
				Game 1
_________________			Bit 12
Game 3
Bit 2		_________________
_________________
		Game 2		_________________
_________________	Bit 9
Game 4
Bit 3		_________________
_________________


interpolate for other side of tree
```
