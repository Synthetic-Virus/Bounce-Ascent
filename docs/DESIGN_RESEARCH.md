# What the genre already knows

Research into Doodle Jump, Beatstar and mobile retention practice, and what it
implies for this game specifically. Written down because the conclusions changed
the order of work, and a decision without its reasoning is just a preference
someone will reverse later.

Sources are linked at the bottom.

---

## The one structural risk

Doodle Jump's most cited strength is that **failure feels close to success**.
Runs end from a small mistake rather than from unfairness, so the next run
always looks winnable, and that is what produces "one more go".

This game kills the player differently, and the difference is not cosmetic:

| | cause of death | how it reads |
|---|---|---|
| Doodle Jump | you missed a platform | obviously your fault, instantly diagnosable |
| Bounce Ascent | a rising line caught you | can read as a timer expiring |

A missed platform explains itself. A rising death line does not, unless the
player can trace it back to their own timing. Observed runs end around tier
20-30 at roughly 70% accuracy, which is exactly the ambiguous zone: it is not
obvious whether you died from bad timing or from time running out.

**The fix is not removing the line.** It is making the causal chain legible:
perfect timing climbs twice as fast, so it pushes the line away, and ordinary
timing eventually does not. That relationship is real and already implemented,
but it was invisible, stated only in a text screen the player reads once.

Hence the LEAD readout: gap to the death line, in tiers, with the direction it
is currently moving. It is not decoration. It is the difference between "I died"
and "I died because I stopped landing PERFECTs".

---

## Where this game is already on solid ground

**Sync is the whole genre, and competitors fail at it.** Players of the Magic
Tiles clones complain that the tiles were never actually synchronised with the
music. Beatstar won its market by prioritising feel and polish over feature
depth rather than by having more content.

This project solves landings against the audio clock analytically, and measures
within a few milliseconds. That is the moat, and it is worth more than any
amount of visual work. Anything that threatens it loses; that is why the bloom
experiment is parked rather than merged despite looking better.

**The difficulty ramp matches the pattern.** Doodle Jump opens with plenty of
safe platforms, then thins them and adds hazards. Here the spread ramps 0.22 to
0.78 over 240 tiers with types unlocking at 12, 30, 55 and 80. Structurally the
same shape.

**Session length is right.** The genre wants bursts of 30 to 90 seconds. Runs
land in that window.

---

## Where this game was wrong

### The tutorial was the wrong shape

The evidence is blunt: effective onboarding uses **interactive learning, where
players discover mechanics by doing rather than reading**, replacing long text
with short verbs and demonstration.

The How to play screen was a wall of text. It correctly stated the central rule,
that a PERFECT climbs two platforms instead of one, and that rule genuinely
cannot be discovered by playing: a player can jump whenever, climb steadily, and
never notice. But stating it in prose is the weakest way to teach it.

### The failure language was harsher than it needed to be

Beatstar deliberately softens failure. A mistimed hit is **still called "Great"**
regardless; the streak breaks, but the game does not announce a failure. That is
a deliberate psychological choice, not sloppiness.

This game showed **MISS** in red with the millisecond error attached. For a
player chasing precision that is useful information. For a new player on their
fourth run it is a scolding, four times a run.

### Onboarding outranks graphics

A streamlined introduction retains 20 to 25% more players in the first week, and
good onboarding can lift retention by up to 50%. Against 2026 medians of roughly
22% day one, 4% day seven and under 1% day thirty, that is the highest-leverage
work available: higher than bloom, particles or sprite art.

This reordered the plan. Visual work was queued first and moved behind
comprehension work.

---

## On juice, with a caveat

There is a real counter-argument that **exaggerated feedback harms design**:
juice added per effect, rather than per event, produces noise.

The usable principle is that visual, audio and tactile feedback must
**synchronise**. For this game that means a PERFECT should flash, sound and
buzz as one event on one frame, not three effects layered independently. The
pitched judgement sounds and the haptics already exist; particles join that
group rather than forming a fourth channel.

---

## Order of work this produced

1. Make the death line's cause legible
2. Replace the text tutorial with a guided first run
3. Soften the failure language
4. Particles, synchronised with the existing audio and haptics
5. Bloom and sprite art

Visual polish is last on purpose. It is the most visible work and the least
likely to change whether anyone plays a second run.

---

## Sources

- [Doodle Jump: mechanics and player engagement](https://ahay.org/wiki/Doodle_Jump:_An_Analysis_Of_Game_Mechanics_And_Player_Engagement)
- [Naavik: Beatstar, the Western world finds its rhythm](https://naavik.co/deep-dives/beatstar-west-finds-rhythm/)
- [GameRefinery: the most successful rhythm games](https://www.gamerefinery.com/the-most-successful-rhythm-games-of-the-three-big-markets/)
- [Segwise: mobile game retention benchmarks](https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies)
- [Mobile game onboarding UX strategies](https://medium.com/@amol346bhalerao/mobile-game-onboarding-top-ux-strategies-that-boost-retention-6ef266f433cb)
- [Wayline: the juice problem](https://www.wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design)
- [Game Developer: why the core gameplay loop is critical](https://www.gamedeveloper.com/business/why-the-core-gameplay-loop-is-critical-for-game-design)
