# F72 OMEGA — MASTER ARCHITECTURE SPECIFICATION

**Canonical reconstruction of the synthetic trading organism.**

Sources (the only permitted ancestry):
- **F72 / V72 Master Architecture Specification** — the formal decision architecture (ancestry).
- **Letra 37** (`LETRA 37.txt`, Pine v6, 6207 lines) — the energy/structure organism + DIE decision layer (evolution).
- **F16 Raptor v60** (`V60 ALGO.txt`, Pine v6, 2611 lines) — the final form: Letra's engine ported verbatim + the F72 Curve organism + Senseei meta-intelligence (final form).

> **LAW ZERO — NOTHING MAY BE INVENTED.** Every variable, formula, threshold, state string and relationship in this document is recovered verbatim from one of the three sources above. Where a value appears, its origin is cited. No score system, indicator, gate, or concept is added that does not already exist in V60, Letra, or F72.

This document is the **canonical merge**. It is the single source of truth for the MT5 incarnation. The organism is split into a **BRAIN** (all recovered cognition) and a **BODY** (execution only). The intelligence decides; the body never overrules it.

---

## PART 0 — DESIGN PHILOSOPHY (recovered, not authored)

From V60's own header and F72's preamble, the organism rests on a small set of axioms:

- **Axiom 0 (F72 Curve):** *Energy cannot travel straight forever → it displaces → a curve.* The Curve is a first-class energy/displacement entity. Consequence layers (phases, campaign, participants) read FROM the Curve rather than recomputing.
- **Engine 1A owns lifecycle.** `ie1a_currentPhase` is the sole canonical phase. Nothing may assign, modify, or compete with it. Every other engine is a **consumer**.
- **Every variable must have a named downstream consumer.** If it has no consumer, it does not exist (F72 Law 3).
- **Messy ≠ Randomness; Messy = Energy Dissipation** (EDE axiom, Letra).
- **Objective Hit ≠ Process Complete** (RE axiom, Letra).
- **Price is attracted to unresolved energy, not just liquidity** (EAE axiom, Letra).
- **Cleaning ≠ Rotation** (ERF axiom, Letra) — active dissipation suppresses rotation scoring.
- **Recover cognition, not signals.** The system understands the market as a living wave organism; entries are a *consequence* of that understanding, never the understanding itself.

No alignment-count gates, no `if score > 65` hard blockers, no RSI/MACD/ADX/MA, no trend filters. The recovered scores are *internal beliefs of the organism*, exactly as they exist in the source — they are not external arbitrary thresholds bolted on.

---

## PART 1 — WHAT SURVIVED / EVOLVED / CHANGED / NEW

| Layer | F72 (ancestry) | Letra 37 (evolution) | V60 / F16 (final form) | Verdict |
|---|---|---|---|---|
| Core physics `f_phys` | implied | **present** (velocity/accel/convexity/efficiency/displacement/impulse) | **ported verbatim** | SURVIVED unchanged |
| Structure/lifecycle `f_se` (Engine 1A authority) | "Engine 1A perfect and untouched" | **present** (14-phase machine) | **ported verbatim** | SURVIVED unchanged |
| EDE / RE / EAE energy framework | "complete" | **present** (full formulas) | **ported verbatim** | SURVIVED unchanged |
| ERF (rotation suppression, trade readiness, entry gate) | extended into TQE/DOE | **present** (full) | present (suppressRotation preserved) | SURVIVED |
| FRZ (Future Return Zones) | integrated into TE/TQE | **present** (6-stage engine) | present | SURVIVED |
| DIE (hypothesis/prediction/validation/adaptive confidence/deviation) | reframed as NE/TQE | **present** (full self-monitoring) | present | SURVIVED |
| FU Order Blocks / FU Wick Authority / AFE | not formalized | **present** | present (Invisible Network = FU pools) | SURVIVED |
| Decision layer | **RIE/MCE/NE/TQE/TE/IE2/DOE** named engines | `liveDirective` + `longSignal`/`shortSignal` | Senseei meta-intelligence (master/alignment/conflict/threat/confidence/opportunity/action) | EVOLVED → re-architected |
| Wave Registry / DeliveryWave Registry | **new (F72)** | implicit (cycle arrays) | implicit (CurveNode tree) | NEW in F72, realized in MT5 |
| Curve object + Recursive Curve Tree | foundation stone | — | **NEW in V60** (`type Curve`, `type CurveNode`) | NEW (final form) |
| Life / Compression Persistence / Narrative Lineage / Chain Vitality | — | — | **NEW in V60** | NEW (final form) |
| Campaign + Participant engines | — | — | **NEW in V60** | NEW (final form) |
| Time Intelligence Engine (5-cycle) | MCE 9-TF stack | — | **NEW in V60** | NEW (final form) |
| Invisible Network (cross-TF FU node registry) | — | FU pools | **NEW in V60** (full registry + web + FEZ) | NEW (final form) |

**Conclusion:** The MT5 organism is the **union** of all three, with V60/F16 as the dominant final form. The F72 named decision engines (DOE/TQE/NE/RIE/TE/IE2) are the *formal skeleton*; Letra's DIE + ERF + FRZ provide the *energy cognition*; V60's Curve organism + Senseei provide the *living judgement* ("is the trade alive?"). All are preserved.

---

## PART 2 — THE 14 CANONICAL PHASES (sole vocabulary)

Engine 1A (`f_se` state machine `_pst` 0→13, mapped by `f_phaseStr`) is the only entity permitted to assign a phase. The complete vocabulary, recovered verbatim:

| `_pst` | dir-adjusted phase | EDE state |
|---|---|---|
| 0 | Point 4 Origin | 1 |
| 1 | Expansion | 1 |
| 2 | Expansion Pre-Convexity | 2 |
| 3 | Expansion Induction | 3 |
| 4 | Expansion Liquidity | 4 |
| 5 / 6 | New High / New Low | 5 |
| 7 | Transition | 6 |
| 8 | Retracement | 6 |
| 9 | HTF Flip Zone | 6 |
| 10 | Induction | 6 |
| 11 | Liquidation | 6 |
| 12 | Terminal Curve | 6 |
| 13 / 14 | Demand Return / Supply Return | 6 |

Letra additionally names `Retracement Pre-Convexity`, `Retracement Induction`, `Retracement Liquidity`, `Absorption` in its canonical list; these are produced by the same machine on the retracement side. **No phase outside this set may ever be produced.**

State machine transition rules (verbatim from `f_se`, V60 lines ~565–615):
```
_pst 0 → 1   : _expanding
1 → 2        : not atExtreme & momDecaying & physConvexDevel
2 → 3        : not atExtreme & momCounter & physTransfer
3 → 4        : not atExtreme & (bos1|bos2|indBrk) & physTransfer
1..7 → 5     : atExtreme & extended            (fresh cycle extreme on >=1.5 ATR leg)
5 → 7        : not atExtreme & (recBrk>=1 | momExhaust)
7 → 8        : transferDone                    (recDom >= 50%)
8 → 9        : atFlip
9 → 10       : counter-impulse inside zone
10 → 11      : oppBOS | physCapacityLow
11 → 12      : terminal sweep of flip extreme
12 → 13      : reversal CHoCH out of zone
```

---

## PART 3 — BRAIN ARCHITECTURE (recovered cognition)

The BRAIN is a strict dependency pipeline. Compute order is mandatory (it mirrors Letra/V60 exactly): **Physics → Structure (6 rungs) → Engine 1A → Physics Observation → EDE → RE → EAE → ERF → Liquidity → Geometry → Wave Intelligence → Beliefs → Spawn → DIE (hypothesis/prediction/validation/confidence) → FRZ → FU/Curve organism → Time Intelligence → Invisible Network → Senseei/DOE.**

```
                          ┌─────────────────────────────────────┐
   Price (M1..MN bars) ─► │ CORE PHYSICS  f_phys  (per fixed TF) │
                          └──────────────────┬──────────────────┘
                                             ▼
                          ┌─────────────────────────────────────┐
                          │ STRUCTURE ENGINE  f_se  × 6 rungs    │
                          │ se1 se3 se5(=1A) se15 se60 se240     │
                          └───────┬───────────────────┬─────────┘
                                  ▼                   ▼
                    ┌──────────────────────┐   ┌───────────────────────┐
                    │ ENGINE 1A (LIFECYCLE)│   │ FRACTAL STACK          │
                    │ ie1a_currentPhase    │   │ fractalStackDir/Score  │
                    │ (sole authority)     │   └───────────────────────┘
                    └──────────┬───────────┘
                               ▼
              ┌────────────────────────────────────────────┐
              │ PHYSICS OBSERVATION  obs_Expansion/Decay/   │
              │ Curvature/Absorption/Liquidity + physicsCons│
              └───────┬──────────────────────────┬─────────┘
                      ▼                          ▼
        ┌──────────────────────┐    ┌──────────────────────────────┐
        │ ENERGY: EDE→RE→EAE→ERF│    │ LIQUIDITY HEATMAP / GEOMETRY │
        │ resolutionState,      │    │ liqHeat, liqVacuum, sweep,   │
        │ residual, attractor,  │    │ availableSpace, originToExt  │
        │ tradeReadiness, gate  │    └──────────────────────────────┘
        └──────────┬────────────┘
                   ▼
        ┌────────────────────────────────────────────────────────────┐
        │ WAVE INTELLIGENCE: sim_*, convexityMaturity, waveProgress    │
        │ BELIEFS: expansion/convexity/creation/absorption/            │
        │          retracement/demandReturn (EMA smoothed)             │
        └──────────┬───────────────────────────────────────────────────┘
                   ▼
        ┌────────────────────────────────────────────────────────────┐
        │ SPAWN ENGINE → wave context (direction, flip zone, point4,   │
        │ induc zones, cycleHigh/Low, entryCycle, waveDepth, recursive)│
        └──────────┬───────────────────────────────────────────────────┘
                   ▼
   ┌─────────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
   │ DIE (Letra)             │ │ FRZ ENGINE (Letra)   │ │ FU / CURVE ORGANISM   │
   │ hypothesis/prediction/  │ │ zones, tiers, status │ │ (V60): Curve, Tree,   │
   │ validation/adaptive conf│ │                      │ │ Life, Compression     │
   │ /deviation/M1 warning   │ │                      │ │ Persistence, Narrative│
   └────────────┬────────────┘ └──────────┬───────────┘ │ Lineage, Chain Vitality│
                │                          │             └──────────┬───────────┘
                ▼                          ▼                        ▼
   ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
   │ TIME INTELLIGENCE     │  │ INVISIBLE NETWORK     │  │ CAMPAIGN / PARTICIPANT│
   │ (V60 5-cycle stack)   │  │ (V60 FU node registry)│  │ (V60)                 │
   └──────────┬───────────┘  └──────────┬───────────┘  └──────────┬───────────┘
              └───────────────┬──────────┴────────────┬───────────┘
                              ▼                        ▼
                 ┌────────────────────────────────────────────────┐
                 │ SENSEEI META-INTELLIGENCE / DECISION OUTPUT      │
                 │ master · alignment · conflict · threat ·         │
                 │ confidence · timing · intent · opportunity ·     │
                 │ ACTION (WAIT/PREPARE/ATTACK/MANAGE-EXIT)         │
                 │  ≡ F72 DOE: doe_bias/action/confidence/tradeType │
                 └────────────────────────┬───────────────────────┘
                                          ▼  (decision only — never overruled)
                                      [ BODY ]
```

### 3.1 CORE PHYSICS — `f_phys` (Letra Section 2 / V60)
Computed inside each timeframe context so history references resolve on that TF:
```
atr          = ta.atr(atrLen=14)
velocity     = ema(close - close[1], 3)
acceleration = velocity - velocity[1]
convexity    = acceleration - acceleration[1]
convSmooth   = ema(convexity, 3)
efficiency   = |close - close[effLen=10]| / sum(|close-close[1]|, effLen)
displacement = (high - low) / atr
bullImpulse  = eff>effThresh(.65) & vel>vel[1] & acc>0 & close>open & disp>dispThresh(1.5)
bearImpulse  = mirror
bullMomDecay = |acc| < |acc[1]|*0.8 & vel>0      (bearMomDecay mirror)
bullConvShift= convSmooth>atr*convMult(.01) & convSmooth[1]<=thr  (bear mirror)
phys_vd70    = |vel| < |vel[1]|*0.7 ;  phys_vd50 = |vel| < |vel[1]|*0.5
```

### 3.2 STRUCTURE ENGINE — `f_se` (sole lifecycle authority)
Per fixed TF: pivots → swing highs/lows (`curSH/curSL/prSH/prSL`) → BOS (`close>prSH`) / CHoCH (`close>prSH+atr*chochBufferATR(.75)`) → impulse-leg `eLong/eShort` (`> impulseAtrMult(1.5)*atr`) → **spawn** of order block (`_ft/_fb` flip zone, `_p4h/_p4l` point4 origin, `_inv` invalidation pinned to protective extreme, `_tgt = obT/obB ± range`). Tracks `cycleHigh/cycleLow`. Latches `bos1/bos2`, inducement `indOrig/indExt/indBrk`. Computes `convScore/expScore/absScore`, `compIdx` (compression 0–100). Recursive transition: `recBrk` counts Phase-2 CHoCHs after the extreme (each armed by a pullback pivot); `recDom = min(100, max(recBrk*(30 - compIdx*0.15), retrFrac*80))`; `transferDone = recDom>=50`. Runs the 14-phase machine (Part 2). **Outputs:** `dir, phase, curSH, curSL, prSH, prSL, bos, ch, p4h, p4l, inv, tgt, ft, fb, frzS, wp, cm, mf, compIdx, recBrk, recDom`.

Instantiated on 6 rungs over an adaptive ladder that climbs from the chart TF: `se1, se3, se5(=canonical/Engine 1A), se15, se60, se240`. Direction per rung: `lN_dir = (close > seN_inv ? 1 : close < seN_inv ? -1 : prevDir)`.

**Fractal stack:** `fractalStackDir = sign(stackBull - stackBear)`, `fractalStackScore = max(stackBull,stackBear)/6*100`.

### 3.3 ENGINE 1A — lifecycle authority
```
ie1a_currentPhase    = phaseStr(se5_ph)
ie1a_phaseConfidence = max(20, min(100, fractalStackScore*0.50 + se5_mf*0.30 + se5_wp*0.20))
ie1a_hypFamily       = map(phase → EXPANSION|CONVEXITY FORMING|CREATION FORMING|ABSORPTION|RETRACEMENT|DEMAND/SUPPLY RETURN)
```

### 3.4 PHYSICS OBSERVATION LAYER (Letra Section 9)
`obs_ExpansionScore, obs_DecayScore, obs_CurvatureScore(=convexityScore), obs_AbsorptionScore, obs_LiquidityScore`, plus `physicsMax/physicsDiff/physicsConsensus`. (Full formulas in §A1.)

### 3.5 ENERGY FRAMEWORK — EDE → RE → EAE → ERF (Letra)
- **EDE:** `ede_state` 1–6 from phase; `ede_expansionEnergy = min(obs_Exp*.5 + (impulse?30:0) + eff*20, 100)`; `ede_dissipatedEnergy`; `ede_dissipationProgress` (25 per state ≥2..≥5); `ede_messyPriceIsDissipation`; `ede_cleaningState`; `ede_liquidationBecomingDirectional`; `ede_deliverySpaceScore`.
- **RE:** `re_expectedCycles = clamp(waveDepth+2, 1, 4)`; `re_completedCycles = clamp(entryCycle,0,expected)`; `re_recursiveCompletionScore`; `re_residualEnergy = max(0, expEnergy - dissEnergy)`; `re_resolutionState ∈ {RESOLVED, PARTIALLY RESOLVED, UNRESOLVED}`; `re_residualEnergyScore`; `re_nodeOpen/nodeClosed`; `re_revisitProbability`.
- **EAE:** `eae_primaryAttractorPrice` (UNRESOLVED→flip zone edge; PARTIAL→origin); `eae_secondaryAttractorPrice` (inducement zone); `eae_primaryAttractorScore`; `eae_primaryAttractorLabel`; `eae_energyState`.
- **ERF:** `erf_suppressRotation = ede_messyPriceIsDissipation & ede_state∈[2,4]`; `erf_confidence`; `erf_dissipationConfidence`; `erf_tradeReadiness = (RESOLVED?40:PARTIAL?25:10) + recCompletion*0.25 + (100-residual)*0.20 + confidence*0.15`; `erf_entryGate = !gateEnabled or tradeReadiness >= erfEntryThreshold(45)`.

### 3.6 LIQUIDITY HEATMAP & GEOMETRY (Letra Sections 10–11)
Weighted decaying density (`liqAgDecay=.95`) of swept pivots → `liqHeat`, `liqZone`, `liqVacuum (wDensity<.5)`, `liqSweepBull/Bear`, `liqSweepOK`. Geometry: `obAge/obFresh`, `originToExtreme`, `flipzoneWidth`, `availableSpace`, `cycleCapacity`, `zonePrecision`, `geoFull/Partial/AbsorptionConvexity` possibility flags.

### 3.7 WAVE INTELLIGENCE & BELIEFS (Letra Section 12)
- `sim_*` (Expansion/PreConv/Induction/Liquidity/Creation/Absorption/Retracement/DemandReturn) via `f_idealSim` Euclidean distance to ideal (eff/disp/vel/curv) signatures.
- `convexityMaturity` = EMA of (expWeakness*.35 + inductionMat*.35 + liqMat*.30).
- `waveProgress` = geom 60% + phys 40%, EMA smoothed by `beliefSmooth(3)`.
- **Belief distribution** (EMA smoothed): `expansionBelief, convexityBelief, creationBelief, absorptionBelief, retracementBelief, demandReturnBelief`, each = raw × position multiplier.

### 3.8 SPAWN ENGINE (Letra Section 13 / V60 Section 8/13)
`f_spawnWave` builds the order block from pivots + `l0_p4`. On `l0_dir` flip, mutates the wave context: `direction, flipTop/Bot, point4OriginHigh/Low, flipzoneInduc*, induc Exp/Retr origin/extreme zones, cycleHigh/Low, entryCycle=0, waveDepth=0, isRecursiveWave=false`. **recursiveTrigger** (`trueCHoCH bull/bear OR structFlip` while phase∈{Demand Return, Supply Return} & `demandReturnBelief>40`) fires a recursive re-spawn: `entryCycle = min(+1, 4)`, `waveDepth = entryCycle`, `waveGeneration++`, `recursiveComplete = true`. Cycle state stored in 4-deep arrays `cycleObTop/Bot/FlipTop/Bot/P4High/Low/StartBar/Dir`. **safeReset:** `hardInvalid (origin broken) OR softReset (stalled+opposing & not suppressRotation)`.

### 3.9 DIE — DISPLAY/DECISION INTELLIGENCE (Letra Section 12D–12J)
The organism's **self-aware** layer:
- **Hypothesis engine (12D):** belief/confidence scores `hyp_*` (each ×`_fitMult=max(.6, waveModelFit/100)`), normalized by fixed maxima. `primaryHypothesis = ie1a_hypFamily` (display only — does not assign phase).
- **Prediction engine (12E):** `predScore_*` additive formulas → `expectedNextPhase = argmax`, `expectedNextProb`.
- **Validation engine (12F):** ring buffer `predOutcomes[100]`; `predSucceeded = (phase transitioned) & (newPhase == lastExpected)`; rolling `predAcc10/25/50/100`; `predReliability = acc10*.4+acc25*.3+acc50*.2+acc100*.1`. **(self-observation / learning)**
- **Adaptive confidence (12G):** `modelConfidence` (start 50) `+= confIncrease(predSucceeded+3, physConsensus>70+2, htfAlign+1.5, tf1==tf2+1) - confDecrease - confDecayRate(.02)*(mc-50)`. **(experience / memory)**
- **Wave deviation (12H):** `waveDeviation` from |ideal − actual| signatures vs active hypothesis; `deviationAlert > devReinterpThresh(30)`. **(contradiction detection)**
- **M1 early warning (12I):** `m1WarningScore` 0–5 → CRITICAL/HIGH/MODERATE/LOW/CLEAR.
- **MTF belief stack (12J):** `htf_Exp/Conv/Abs/LiqBelief`.
- **die_entryScore** = `waveModelFit*.2 + modelConfidence*.2 + (htfAlign==dir?20:htfAlign0?10:0) + (liqHeat>50?15:liqHeat*.3) + (dirFU active?15:0) + (flipzoneStages>=3?10:stages*3.3)`.

### 3.10 FRZ — FUTURE RETURN ZONES (Letra Sections 17/18)
Four components × 25 pts: FU (gap-confirmed preferred), Imbalance (`displacement>dispThresh`), Liquidity cleared (`sweep|vacuum|obs_Liq>55`), Displacement (`impulse`). `frz_rawScore` 0–100. `frz_approved = !(liqHeat>60 & !sweep)`. Class: Exceptional≥76/Strong≥51/Moderate≥26/Weak. Tier: T1≥76/T2≥51/T3(≥26&FU)/T4(≥26&IMB). Parallel-array registry with lifecycle **Open→Partial→Mitigated→Invalidated**, spawn guard (one/bar, >50% overlap dedup), expiry at `frz_maxBarsActive(100)`.

### 3.11 FU / CURVE ORGANISM (V60 — the living judgement)
- **FU Order Blocks / FU Wick Authority (1A.8/1A.9):** captured wick = future magnet; 38–62% induction band; valid when opposite extreme destroyed. **AFE (1A.9B):** 6-step alternating-flip-echo state machine. **FU convergence:** per-TF `f_fuPool` (W/D/H4/H1/M15/M5) → `fu_recursiveAlign`, `fu_winTarget` (highest TF with valid FU).
- **Curve object** (`type Curve`): dir, origin, extreme, dispATR, eIn, eDiss, eRes, convex, compress, maturity. `gCurve` from se5; per-rung `c_r1..c_r6`.
- **Recursive Curve Tree** (`type CurveNode`): event-generated children on Phase-2 CHoCH against the owner; ownership = shallowest alive node with `energy≥12`; recursion budget 1–4 from compression; energy `+7` on progress / `−2` on stall, dies `≤2`; `f_nodeState` emits emergent phase. **(parents/children/grandchildren/merge/death/inheritance/lineage)**
- **Compression Persistence:** `cpForce`, `cpState ∈ {PERSISTING, LEAKING, NEUTRAL}`.
- **Life ("is the trade alive?"):** `life = cpForce*.45 + eRes*.30 + tighten + progressing − recursionComplete − leaking + retraceX`; verdict ALIVE/DEAD/WEAKENING; HTF parent threat.
- **Narrative Lineage:** sequence of entry-curve pullbacks; SUPPORT/DEGRADE votes; `narrative ∈ {STRENGTHENING, WEAKENING, HOLDING}`; converging flag.
- **Chain Vitality:** `wholeChainLife` (slow EMA), `chainVitality`, `chainScope ∈ {healthy, CURVE only, CHAIN weakening, WHOLE CHAIN decaying}`.

### 3.12 TIME INTELLIGENCE ENGINE (V60)
5-cycle stack MN/W/D/H4/H1 (open, running H/L, prior H/L, time) → bias/state/completion/lowProb per cycle → `timeDir`, `timeAlign`, `timeConflict`, `h1Timing`, `tSeq`. (Maps to F72's MCE multi-timeframe consensus.)

### 3.13 INVISIBLE NETWORK (V60)
Cross-TF FU rejection-wick node registry (`nPx/nMid/nDir/nSc/nWt/nState/nBar/nRev`); authority `f_auth = score + wt*4 + rev*3`; forward path `f_pathNodes`; `netBias`; pressure `= (bullAuth-bearAuth)/sum*100`, `pdir`; FEZ corridor; conversation web.

---

## PART 4 — THE DECISION LAYER (Senseei ≡ F72 DOE)

V60's Senseei meta-intelligence IS the unified decision output the F72 spec calls the DOE. Both are preserved; the MT5 incarnation uses the Senseei computation (verbatim) and exposes it through the F72 DOE vocabulary.

**Four votes** (V60 Part D): `vt1=waveDir(l0_dir)`, `vt2=stackDir`, `vt3=netBias`, `vt4=pdir`.
```
master      = sign(vt1+vt2+vt3+vt4)
alignment   = forVotes/castVotes*100
conflict    = (cast-for)/cast*100
threat      = clamp(conflict*.40 + residual*.28 + timeConflict*.12 + (pdir≠0 & pdir≠master ? 18:0) + (resCode==1 ? 10:0), 0,100)
confidence  = clamp(alignment*.40 + timeAlign*.12 + stackPct*.18 + attractor*.15 + min(15, eligNodes*1.2) − threat*.20, 0,100)
timing      = waveProgress → VERY EARLY|EARLY|DEVELOPING|MID CYCLE|LATE|TERMINAL
intent      = phase → EXPANSION|CONTINUATION|RESOLUTION|DELIVERY|ABSORPTION|BALANCE
oppScore    = clamp(alignment*.40 + attractor*.30 + stackPct*.30 − threat*.35, 0,100)
opportunity = master==0 ? NONE : conflict>60 ? DEVELOPING : oppScore→NONE/DEVELOPING/GOOD/STRONG/EXCEPTIONAL
ACTION:
   master==0                                            → WAIT
   conflict>60                                          → WAIT
   resCode==2 (RESOLVED)                                → MANAGE / EXIT
   opp∈{STRONG,EXCEPTIONAL} & confidence≥minConf(55) & threat<45 → ATTACK
   opp∈{GOOD,STRONG}                                    → PREPARE
   else                                                 → WAIT
```

**F72 DOE mapping (same values, F72 names):**
- `doe_bias` ← `master` + `mce(timeAlign)` strength → Strong Bullish/Bullish/Neutral/Bearish/Strong Bearish.
- `doe_action` ← Senseei `action` (Long when ATTACK & master=+1; Short when ATTACK & master=−1; Wait; Manage/Exit).
- `doe_confidence` ← Senseei `confidence`.
- `doe_tradeType` ← `intent` + phase (Continuation/Pullback/Rotation/Breakout/Range).
- `doe_entryZone` ← FRZ best zone or Demand/Supply zone (`flipTop/Bot`, `eae_primaryAttractorPrice ± entryZoneWidth`).
- `doe_grade` ← Letra `grade` (A+/A/B/C) and `tqe_grade` from `ie1a_phaseConfidence/erf_confidence/frz/mce/re/liq` weights.

**ERF entry gate is preserved as the only hard pre-condition Letra itself imposes** (`erf_entryGate`), exactly as the source does — it is not an invented external filter, it is the organism's own readiness check.

---

## PART 5 — BODY ARCHITECTURE (execution only)

The BODY never computes a signal, bias, or score. It only **acts** on the BRAIN's `doe_action`/`doe_*` outputs and manages the consequences.

| Module | Responsibility | Reads from BRAIN |
|---|---|---|
| **Executor** | Open/modify/close orders, order types (Market / Limit-on-retest), magic number, deviation/slippage control | `doe_action`, `doe_entryZone`, `doe_entryTrigger` |
| **Risk** | Position sizing from account risk %, stop distance from Invalidation Engine, max concurrent positions, daily loss cap | `inv_activeStop` (≡ `se5_inv` / origin), `doe_confidence` |
| **Targets** | TP1/TP2/TP3 placement, partial scaling, trailing | `eae_primary/secondaryAttractorPrice`, `se5_tgt`, FRZ zones |
| **Position Intelligence** | Hold/Scale/Reduce/Reverse/Exit while in a trade | Life score, `re_resolutionState`, narrative lineage, `chainScope`, `doe_action==MANAGE/EXIT` |
| **Portfolio** | Per-symbol & aggregate exposure, correlation guard, margin | account state |
| **Persistence** | Serialize wave context, registries, `modelConfidence`, `predOutcomes` across restarts | all `var` state |
| **Replay / Logging** | Structured decision log (every `doe_*` + breakdown), trade journal, CSV/DB | full decision object |
| **Database** | Campaign memory, experience, similarity replay (Letra's validation/adaptive-confidence persisted) | `predOutcomes`, `modelConfidence`, campaign records |

**Absolute requirement (F72):** the body never overrules the intelligence. There are no artificial gates, arbitrary thresholds, or external filters in the BODY. The stop-loss is the organism's own invalidation (`se5_inv`); the targets are the organism's own attractors; the exit is the organism's own `MANAGE/EXIT` verdict. Risk sizing is the only purely mechanical concern, and it scales *within* the decision the BRAIN already made.

---

## PART 6 — MT5 MODULE MAP (incarnation)

```
F72Omega.mq5                         ← EA entry (OnInit/OnTick/OnDeinit)  [BODY orchestration]
Include/
  Brain/
    Params.mqh                       ← all recovered input parameters (verbatim defaults)
    Physics.mqh                      ← f_phys primitives                         (§3.1)
    Structure.mqh                    ← f_se structure engine + 14-phase machine  (§3.2, Part 2)
    Engine1A.mqh                     ← lifecycle authority + fractal stack        (§3.3)
    Observation.mqh                  ← obs_* physics observation                  (§3.4)
    Energy.mqh                       ← EDE / RE / EAE / ERF                        (§3.5)
    Liquidity.mqh                    ← liquidity heatmap + geometry               (§3.6)
    WaveIntel.mqh                    ← sim_*, convexityMaturity, waveProgress, beliefs (§3.7)
    Spawn.mqh                        ← spawn engine + wave context + recursion     (§3.8)
    DIE.mqh                          ← hypothesis/prediction/validation/confidence (§3.9)
    FRZ.mqh                          ← Future Return Zone registry                 (§3.10)
    CurveOrganism.mqh                ← Curve, CurveNode tree, Life, lineage, chain (§3.11)
    TimeIntel.mqh                    ← 5-cycle time intelligence                   (§3.12)
    Network.mqh                      ← invisible network FU node registry          (§3.13)
    Senseei.mqh                      ← meta-intelligence + DOE decision object     (Part 4)
    Brain.mqh                        ← orchestrates the full pipeline, owns state
  Body/
    Executor.mqh                     ← order execution
    Risk.mqh                         ← sizing, invalidation stop
    Targets.mqh                      ← TP1/2/3 from attractors
    PositionIntel.mqh                ← hold/scale/reduce/reverse/exit
    Portfolio.mqh                    ← exposure/margin
    Persistence.mqh                  ← state serialization
    Journal.mqh                      ← decision + trade logging
```

The BRAIN is computed once per **closed bar** on the execution timeframe (M5 canonical), using `iCustom`-free direct multi-timeframe series access (`CopyRates` on each fixed rung) — the MT5 equivalent of Pine's `request.security`. The BODY runs every tick for order management but only consults a fresh decision on bar close.

---

## APPENDIX A1 — VERBATIM FORMULA REFERENCE

Physics observation (Letra Section 9):
```
obs_ExpansionScore  = min((eff>effT? eff*60 : eff*30) + (disp>dispT? (disp/dispT-1)*20 : 0)
                          + ((vel>0&acc>0)||(vel<0&acc<0)? velocityScore*0.2 : 0), 100)
obs_DecayScore      = min((bull/bearMomDecay?40:0) + (convScore>30? convScore*0.5:0) + (vd70?30:0), 100)
obs_CurvatureScore  = convexityScore = min(|convSmooth|/(atr*convMult)*25, 100)
obs_AbsorptionScore = min((eff<effT*.7? (1-eff/effT)*50:0) + (vd50?30:0) + (disp<dispT*.5?20:0), 100)
obs_LiquidityScore  = min(obs_Decay*0.4 + obs_Curv*0.4 + (disp>dispT*1.2 & momDecay?20:0), 100)
physicsConsensus    = max(0, 100 - (physicsMax - physicsMin))
```

Scoring engine (Letra Section 18 — used for grade/edge, preserved):
```
buyScore  = (eff*30 + (disp>dispT?20:0) + max(momScore,0) + max(accScore,0) + max(structScore,0)
            + max(htfScore,0) + liqScore + (closeInside?15:0) + max(inducScore,0) + flipzoneStages*6
            + beliefBonus + (fractalDir==1? fractalScore*0.30:0)) * confMult
confMult  = clamp(modelConfidence/100*1.3, 0.7, 1.3)
netEdge   = buyScore - sellScore ;  netEdgeAdjusted = netEdge - slippage/atr*10
liveDirective: >25 BUY PRESSURE / >10 BULLISH BIAS / <-25 SELL PRESSURE / <-10 BEARISH BIAS / NEUTRAL
```

Entry (Letra Section 21 — the organism's own entry condition, preserved verbatim):
```
beliefEntryLong  = dir==1 & phase=="Demand Return" & demandReturnBelief>50 & expansionBelief<60 & absorptionBelief>25
beliefEntryShort = dir==-1 & phase=="Supply Return" & (mirror)
longSignal  = beliefEntryLong & htfAligned & gradeOK & !locked & edgePassesFilter
              & preConvOK & inducOK & structLongOK & liqSweepOK & obFresh & htfLongOK & erf_entryGate
```

## APPENDIX A2 — RECOVERED PARAMETERS (verbatim defaults)
```
pivotLen=5  pivotLenFU/lookback=3  atrLen=14  effLen=10  structLenL=10
impulseAtrMult=1.5  effThresh=0.65  dispThresh=1.5  convMult=0.01  chochBufferATR=0.75
acceptBars=2  obMaxBars=50  inducLookback=80  inducZoneWidth=0.25
liqSweepLookback=10  liqRadius=0.25  liqAgDecay=0.95  requireLiqSweep=true
resetBars=20  beliefSmooth=3  confDecayRate=0.02  devReinterpThresh=30
frz_minScore=26  frz_maxBarsActive=100  fuMinBodyRatio=0.6  fuMinWickRatio=0.25  fuMaxBarsActive=75
erfReadyResW=0.25  erfReadyResidW=0.20  erfReadyConfW=0.15  erfEntryThreshold=45
minConf=55  baseLockBars=10  execThreshold=5.0  wickFrac=0.3  authMin=45  nodeMax=250
```

## APPENDIX A3 — AUTHORITY BOUNDARIES (F72 Part 2, preserved)
- Any variable containing "Phase" may only be assigned by **Engine 1A**.
- The Curve Tree owns ownership/transfer probability — it may **not** assign lifecycle phase.
- Senseei/DOE synthesizes — it may **not** compute raw physics/lifecycle.
- The BODY renders/executes — it may **not** compute anything cognitive.

---

*End of F72 OMEGA Master Architecture. This document is canonical. The MT5 organism implements it without addition or substitution.*
