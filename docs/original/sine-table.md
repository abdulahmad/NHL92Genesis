# Sine Table (`SINTAB.ASM`)

> A 256-entry sine lookup table from EA's original hockey sources, converted from `src/_docs/SINTAB.ASM`. The file is not included by the build and nothing in `src/` refers to it.

## What it is

One full sine period in 256 steps of signed 16-bit words, amplitude 32767 (`$7FFF`): entry `i` is `round(32767 * sin(2*pi*i / 256))`. Entries 0, 64, 128 and 192 are 0, 32767, 0 and -32767.

A table like this turns an angle into a fixed-point sine (and, shifted by 64 entries, a cosine). The game's collision code in `hockey.asm` and `logic.asm` works with `dx/r` style ratios instead and never refers to the table, so it looks like a leftover from the original development tree rather than something the shipped ROM uses. That is an inference from the source, not something checked against the ROM data.

## Data

```text
0, 804, 1607, 2410, 3211, 4011, 4808, 5602, 6392, 7179, 7961, 8739, 9512, 10278, 11039, 11793
12539, 13728, 14010, 14732, 15446, 16151, 16846, 17530, 18204, 18868, 19519, 20159, 20787, 21403, 22005, 22594
23170, 23732, 24279, 24812, 25330, 25832, 26319, 26790, 27245, 27684, 28106, 28511, 28898, 29269, 29621, 29956
30273, 30572, 30852, 31114, 31357, 31581, 31785, 31971, 32138, 32285, 32413, 32521, 32610, 32679, 32728, 32758
32767, 32758, 32728, 32679, 32610, 32521, 32413, 32285, 32138, 31971, 31785, 31581, 31357, 31114, 30852, 30572
30273, 29956, 29621, 29269, 28898, 28511, 28106, 27684, 27245, 26790, 26319, 25832, 25330, 24812, 24279, 23732
23170, 22594, 22005, 21403, 20787, 20159, 19519, 18868, 18204, 17530, 16846, 16151, 15446, 14732, 14010, 13728
12539, 11793, 11039, 10278, 9512, 8739, 7961, 7179, 6392, 5602, 4808, 4011, 3211, 2410, 1607, 804
0, -804, -1607, -2410, -3211, -4011, -4808, -5602, -6392, -7179, -7961, -8739, -9512, -10278, -11039, -11793
-12539, -13728, -14010, -14732, -15446, -16151, -16846, -17530, -18204, -18868, -19519, -20159, -20787, -21403, -22005, -22594
-23170, -23732, -24279, -24812, -25330, -25832, -26319, -26790, -27245, -27684, -28106, -28511, -28898, -29269, -29621, -29956
-30273, -30572, -30852, -31114, -31357, -31581, -31785, -31971, -32138, -32285, -32413, -32521, -32610, -32679, -32728, -32758
-32767, -32758, -32728, -32679, -32610, -32521, -32413, -32285, -32138, -31971, -31785, -31581, -31357, -31114, -30852, -30572
-30273, -29956, -29621, -29269, -28898, -28511, -28106, -27684, -27245, -26790, -26319, -25832, -25330, -24812, -24279, -23732
-23170, -22594, -22005, -21403, -20787, -20159, -19519, -18868, -18204, -17530, -16846, -16151, -15446, -14732, -14010, -13728
-12539, -11793, -11039, -10278, -9512, -8739, -7961, -7179, -6392, -5602, -4808, -4011, -3211, -2410, -1607, -804
```

## Check against the exact sine

Four entries differ from `round(32767 * sin(2*pi*i / 256))` by more than rounding error: indices 17, 111, 145 and 239 hold `13728` (and `-13728` for the negative half). The exact value is `13279`, so the original has two digits transposed. It is kept as in the source.
