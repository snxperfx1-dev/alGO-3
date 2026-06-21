//+------------------------------------------------------------------+
//|  Params.mqh — F72 OMEGA recovered parameters (verbatim defaults) |
//|  Every default is recovered from V60/Letra (see                  |
//|  F72_OMEGA_MASTER_ARCHITECTURE.md Appendix A2). Nothing invented. |
//+------------------------------------------------------------------+
#ifndef F72_PARAMS_MQH
#define F72_PARAMS_MQH

//--- Letra engine (exact f_phys / f_se parameters) -------------------
input int    InpPivotLen       = 5;     // Pivot Length (f_se)
input int    InpAtrLen         = 14;    // ATR Length
input int    InpEffLen         = 10;    // Efficiency Lookback
input int    InpStructLen      = 10;    // Structure Pivot Length
input double InpImpulseAtrMult = 1.5;   // Impulse ATR Multiple
input double InpEffThresh      = 0.65;  // Efficiency Threshold
input double InpDispThresh     = 1.5;   // Displacement ATR Threshold
input double InpConvMult       = 0.01;  // Convexity ATR Multiplier
input double InpChochBufferATR = 0.75;  // Direction CHoCH Buffer (ATR)
input bool   InpUseStrictStruct= true;  // Use Strict Structure
input int    InpAcceptBars     = 2;     // Flipzone Acceptance Bars
input int    InpObMaxBars      = 50;    // OB Max Valid Bars
input int    InpInducLookback  = 80;    // Inducement Lookback Bars
input double InpInducZoneWidth = 0.25;  // Inducement Zone Half-Width (ATR)
input int    InpLiqSweepLook   = 10;    // Sweep Lookback Bars
input double InpLiqRadius      = 0.25;  // Liquidity Radius (x ATR)
input double InpLiqAgDecay     = 0.95;  // Liquidity Age Decay
input bool   InpRequireLiqSweep= true;  // Require Liquidity Sweep
input int    InpResetBars      = 20;    // Min Bars Before Reset
input int    InpBeliefSmooth   = 3;     // Belief EMA Smoothing

//--- Intelligence engine (Letra DIE) ---------------------------------
input double InpConfDecayRate  = 0.02;  // Confidence Decay Rate
input double InpDevReinterp     = 30.0; // Deviation Reinterpret Threshold

//--- FRZ engine ------------------------------------------------------
input int    InpFrzMinScore    = 26;    // Min FRZ Score to track
input int    InpFrzMaxBars     = 100;   // FRZ Max Active Bars

//--- FU order blocks -------------------------------------------------
input int    InpFuLookback     = 3;     // FU Detection Lookback Bars
input double InpFuMinBodyRatio = 0.6;   // Min Body/Range Ratio
input double InpFuMinWickRatio = 0.25;  // Min Wick Ratio
input int    InpFuMaxBars      = 75;    // FU Zone Max Active Bars

//--- ERF (Energy Resolution Framework) -------------------------------
input double InpErfReadyResW   = 0.25;  // ERF Recursive Completion Weight
input double InpErfReadyResidW = 0.20;  // ERF Delivered Energy Weight
input double InpErfReadyConfW  = 0.15;  // ERF Confidence Weight
input double InpErfEntryThresh = 45.0;  // ERF Entry Gate Threshold
input bool   InpErfGateEnabled = true;  // ERF Enable Entry Gate

//--- Invisible network (V60) -----------------------------------------
input double InpWickFrac       = 0.3;   // FU spike: min wick / range
input int    InpFuStructLook   = 3;     // FU spike: structure lookback
input int    InpAuthMin        = 45;    // Min node authority
input int    InpNodeMax        = 250;   // Max remembered nodes
input int    InpDormantBars    = 120;   // Bars until dormant
input int    InpHistoryBars    = 600;   // Bars until historical

//--- Senseei / decision ----------------------------------------------
input int    InpMinConf        = 55;    // Min confidence to ATTACK

//--- BODY (execution) ------------------------------------------------
input ENUM_TIMEFRAMES InpExecTF = PERIOD_M5; // Execution / canonical timeframe
input double InpRiskPctPerTrade = 0.5;   // Risk % of equity per trade
input double InpMaxRiskPctTotal = 2.0;   // Max aggregate open risk %
input int    InpMaxPositions    = 1;     // Max concurrent positions (this symbol)
input double InpDailyLossCapPct = 4.0;   // Daily loss cap % (halts new entries)
input long   InpMagic           = 720060;// EA magic number
input int    InpSlippagePts     = 30;    // Max deviation (points)
input double InpStopBufferATR   = 0.25;  // Stop buffer beyond invalidation (ATR) - F72 IE2
input bool   InpUseTP1          = true;  // Scale out at TP1 (secondary attractor)
input double InpTP1ClosePct     = 50.0;  // % of position closed at TP1
input int    InpBaseLockBars    = 10;    // Base lock bars after entry
input bool   InpEnableTrading   = true;  // Master trading switch (false = brain-only/observe)
input bool   InpVerboseJournal  = true;  // Verbose decision journaling

#endif // F72_PARAMS_MQH
