//+------------------------------------------------------------------+
//|  Energy.mqh — EDE -> RE -> EAE -> ERF (Letra, verbatim)            |
//|  Consumes prev-bar spawn/wave-intel state (Pine forward-var       |
//|  pattern). 'close' is the canonical exec-TF close.                |
//+------------------------------------------------------------------+
#ifndef F72_ENERGY_MQH
#define F72_ENERGY_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

void ComputeEnergy(BrainState &S,double close)
{
   string p=S.ie1a_currentPhase;
   double eff=S.efficiency, effT=InpEffThresh;

   //--- EDE ---
   S.ede_state = (p=="Point 4 Origin"||p=="Expansion")?1 :
                 (p=="Expansion Pre-Convexity")?2 :
                 (p=="Expansion Induction")?3 :
                 (p=="Expansion Liquidity")?4 :
                 (p=="New High"||p=="New Low")?5 : 6;
   S.ede_expansionEnergy = MathMin(S.obs_ExpansionScore*0.50 + ((S.bullImpulse||S.bearImpulse)?30.0:0.0) + eff*20.0, 100.0);
   S.ede_dissipatedEnergy = MathMin(
        (S.ede_state>=2? S.obs_DecayScore*0.40:0.0) +
        (S.ede_state>=3? S.obs_CurvatureScore*0.30:0.0) +
        (S.ede_state>=4? S.obs_LiquidityScore*0.30:0.0), 100.0);
   S.ede_dissipationProgress = MathMin(
        (S.ede_state>=2?25.0:0.0)+(S.ede_state>=3?25.0:0.0)+(S.ede_state>=4?25.0:0.0)+(S.ede_state>=5?25.0:0.0),100.0);
   S.ede_liquidationBecomingDirectional = (S.ede_state==4 && (S.bullImpulse||S.bearImpulse) && eff>effT*0.8);
   S.ede_deliverySpaceScore = MathMin(MathMax(0.0,100.0-S.convexityMaturity),100.0);
   S.ede_messyPriceIsDissipation = (S.ede_state>=2 && S.ede_state<=4) && S.obs_DecayScore>30.0 && eff<effT*0.9 && !(S.bullImpulse||S.bearImpulse);

   //--- RE ---
   S.re_expectedCycles = MathMax(1,MathMin(S.waveDepth+2,4));
   S.re_completedCycles= MathMax(0,MathMin(S.entryCycle,S.re_expectedCycles));
   S.re_recursiveCompletionScore = S.re_expectedCycles>0? MathMin((double)S.re_completedCycles/(double)S.re_expectedCycles*100.0,100.0):0.0;
   S.re_residualEnergy = MathMax(0.0,S.ede_expansionEnergy-S.ede_dissipatedEnergy);
   bool objectiveReached = S.ede_state>=5;
   bool fullDissipation  = S.ede_dissipationProgress>=75.0;
   bool absorbedReturned = (p=="Demand Return"||p=="Supply Return") && S.recursiveComplete;
   S.re_resolutionState = (absorbedReturned && fullDissipation && S.re_recursiveCompletionScore>=75.0)? "RESOLVED" :
                          (objectiveReached && S.ede_dissipationProgress>=50.0)? "PARTIALLY RESOLVED" : "UNRESOLVED";
   S.re_residualEnergyScore = MathMin(S.re_residualEnergy,100.0);
   S.re_nodeOpen   = (S.re_resolutionState=="UNRESOLVED"||S.re_resolutionState=="PARTIALLY RESOLVED");
   S.re_nodeClosed = (S.re_resolutionState=="RESOLVED");
   S.re_revisitProbability = S.re_resolutionState=="UNRESOLVED"? MathMin(S.re_residualEnergyScore*0.90,95.0) :
                             S.re_resolutionState=="PARTIALLY RESOLVED"? MathMin(S.re_residualEnergyScore*0.60,75.0) :
                             MathMin(S.re_residualEnergyScore*0.20,25.0);

   //--- EAE ---
   double a2=S.atr*2.0;
   S.eae_primaryAttractorPrice = S.direction==0? F72_NA :
        S.re_resolutionState=="UNRESOLVED"? (S.direction==1? f72_nz(S.flipBot,close-a2) : f72_nz(S.flipTop,close+a2)) :
        S.re_resolutionState=="PARTIALLY RESOLVED"? (S.direction==1? f72_nz(S.point4OriginLow,close-S.atr) : f72_nz(S.point4OriginHigh,close+S.atr)) : F72_NA;
   S.eae_secondaryAttractorPrice = (S.direction!=0 && S.re_resolutionState=="UNRESOLVED" && !f72_isna(S.inducZoneLow) && !f72_isna(S.inducZoneHigh))?
        (S.direction==1? S.inducZoneLow : S.inducZoneHigh) : F72_NA;
   S.eae_primaryAttractorScore = MathMin(
        S.re_residualEnergyScore*0.40 +
        (S.re_resolutionState=="UNRESOLVED"?30.0: S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:5.0) +
        (!f72_isna(S.eae_primaryAttractorPrice)? MathMax(0.0,30.0-MathAbs(close-S.eae_primaryAttractorPrice)/MathMax(S.atr,1e-10)*5.0):0.0),100.0);
   S.eae_secondaryAttractorScore = MathMin(
        S.re_residualEnergyScore*0.25 +
        (S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:10.0) +
        (!f72_isna(S.eae_secondaryAttractorPrice)? MathMax(0.0,20.0-MathAbs(close-S.eae_secondaryAttractorPrice)/MathMax(S.atr,1e-10)*4.0):0.0),100.0);
   S.eae_energyState = S.ede_state==1?"Accumulating": (S.ede_state>=2&&S.ede_state<=4)?"Cleaning": S.ede_state==5?"Delivering": S.re_resolutionState=="RESOLVED"?"Exhausted":"Resolving";

   //--- ERF ---
   S.erf_suppressRotation = S.ede_messyPriceIsDissipation && S.ede_state>=2 && S.ede_state<=4;
   S.erf_confidence = MathMin(
        (S.eae_energyState!="Accumulating"? S.ie1a_phaseConfidence*0.40 : 20.0) +
        (S.re_resolutionState=="RESOLVED"?30.0: S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:10.0) +
        S.eae_primaryAttractorScore*0.30, 100.0);
   S.erf_dissipationConfidence = MathMin((S.ede_messyPriceIsDissipation?50.0:0.0)+S.ede_dissipationProgress*0.50,100.0);
   S.erf_tradeReadiness = MathMin(
        (S.re_resolutionState=="RESOLVED"?40.0: S.re_resolutionState=="PARTIALLY RESOLVED"?25.0:10.0) +
        S.re_recursiveCompletionScore*InpErfReadyResW +
        (100.0-S.re_residualEnergyScore)*InpErfReadyResidW +
        S.erf_confidence*InpErfReadyConfW, 100.0);
   S.erf_entryGate = (!InpErfGateEnabled) || (S.erf_tradeReadiness>=InpErfEntryThresh);
}

#endif // F72_ENERGY_MQH
