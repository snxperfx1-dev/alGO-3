//+------------------------------------------------------------------+
//|  BrainState.mqh — the organism's per-bar cognitive state.          |
//|  Mirrors the flat global scope of the Pine sources: every engine  |
//|  writes its named outputs here; downstream engines consume them.  |
//+------------------------------------------------------------------+
#ifndef F72_BRAINSTATE_MQH
#define F72_BRAINSTATE_MQH

struct BrainState
{
   // --- canonical physics (se5) ---
   double atr, velocity, acceleration, convSmooth, efficiency, displacement;
   bool   bullImpulse, bearImpulse, bullMomDecay, bearMomDecay, bullConvShift, bearConvShift;
   bool   phys_vd70, phys_vd50;
   double convexityScore;

   // --- Engine 1A / fractal ---
   string ie1a_currentPhase;
   double ie1a_phaseConfidence;
   string ie1a_hypFamily;
   int    fractalStackDir;
   double fractalStackScore;
   int    waveDir;          // l0_dir
   int    structBias;

   // --- physics observation ---
   double obs_ExpansionScore, obs_DecayScore, obs_CurvatureScore, obs_AbsorptionScore, obs_LiquidityScore;
   double physicsConsensus, physicsDiff;

   // --- EDE / RE / EAE / ERF ---
   int    ede_state;
   double ede_expansionEnergy, ede_dissipatedEnergy, ede_dissipationProgress;
   bool   ede_messyPriceIsDissipation, ede_liquidationBecomingDirectional;
   double ede_deliverySpaceScore;
   int    re_expectedCycles, re_completedCycles;
   double re_recursiveCompletionScore, re_residualEnergy, re_residualEnergyScore;
   string re_resolutionState;
   bool   re_nodeOpen, re_nodeClosed;
   double re_revisitProbability;
   double eae_primaryAttractorPrice, eae_secondaryAttractorPrice;
   double eae_primaryAttractorScore, eae_secondaryAttractorScore;
   string eae_energyState;
   bool   erf_suppressRotation;
   double erf_confidence, erf_dissipationConfidence, erf_tradeReadiness;
   bool   erf_entryGate;

   // --- liquidity / geometry ---
   double liqHeat; bool liqVacuum, liqSweepBull, liqSweepBear, liqSweepOK;
   double originToExtreme, flipzoneWidth, availableSpace;

   // --- wave context (spawn) ---
   int    direction, entryCycle, waveDepth;
   bool   isRecursiveWave, recursiveComplete, recursiveJustFired;
   double flipTop, flipBot, point4OriginHigh, point4OriginLow;
   double cycleHigh, cycleLow;
   double inducZoneLow, inducZoneHigh;
   bool   closeInside;

   // --- wave intelligence / beliefs ---
   double convexityMaturity, waveProgress, waveModelFit;
   double expansionBelief, convexityBelief, creationBelief, absorptionBelief, retracementBelief, demandReturnBelief;
   double sim_Expansion, sim_PreConv, sim_Induction, sim_Liquidity, sim_Creation, sim_Absorption, sim_Retracement, sim_DemandReturn;

   // --- DIE ---
   double modelConfidence, predReliability, waveDeviation;
   string expectedNextPhase; double expectedNextProb;
   double die_entryScore;
   bool   deviationAlert;

   // --- FRZ best ---
   int    frz_activeCount;
   double frz_bestScore; string frz_bestTier, frz_bestStatus; int frz_bestDir;
   double frz_bestTop, frz_bestBot, frz_distanceToZone;

   // --- curve organism / life ---
   int    ownerDir, treeDepth;
   double life, chainVitality, wholeChainLife, cpForce, gCompress, gResidual;
   string cpState, narrState, chainScope, aliveVerdict;
   double narrative;

   // --- time intelligence ---
   int    timeDir; double timeAlign, timeConflict; string h1Timing;

   // --- invisible network ---
   int    netBias, pdir, eligNodes; double netPressure; double attractorScore;

   // --- senseei / DOE decision ---
   int    master; double alignment, conflict, threat, confidence, oppScore;
   string timing, intent, opportunity, action;
   // F72 DOE surface
   string doe_bias, doe_action, doe_tradeType, doe_grade, doe_entryTrigger;
   double doe_confidence, doe_entryMid, doe_entryHigh, doe_entryLow;
   double inv_activeStop, te_tp1, te_tp2, te_tp3;
};

#endif // F72_BRAINSTATE_MQH
