//+------------------------------------------------------------------+
//|  Observation.mqh — Physics Observation Layer (Letra Section 9)     |
//|  obs_* perceptual scores derived from the canonical (se5) physics.|
//+------------------------------------------------------------------+
#ifndef F72_OBSERVATION_MQH
#define F72_OBSERVATION_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

void ComputeObservation(BrainState &S)
{
   double atr=S.atr, vel=S.velocity, acc=S.acceleration, csm=S.convSmooth;
   double eff=S.efficiency, disp=S.displacement, effT=InpEffThresh, dispT=InpDispThresh;
   double velocityScore = MathMin(MathAbs(vel)/MathMax(atr*0.1,1e-10)*50.0,100.0);
   S.convexityScore     = MathMin(MathAbs(csm)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);

   S.obs_ExpansionScore = MathMin(
        (eff>effT? eff*60.0 : eff*30.0) +
        (disp>dispT? (disp/MathMax(dispT,1e-10)-1.0)*20.0 : 0.0) +
        ((vel>0&&acc>0)||(vel<0&&acc<0)? velocityScore*0.2 : 0.0), 100.0);
   S.obs_DecayScore = MathMin(
        ((S.bullMomDecay||S.bearMomDecay)?40.0:0.0) +
        (S.convexityScore>30? S.convexityScore*0.5:0.0) +
        (S.phys_vd70?30.0:0.0), 100.0);
   S.obs_CurvatureScore = S.convexityScore;
   S.obs_AbsorptionScore = MathMin(
        (eff<effT*0.7? (1.0-eff/MathMax(effT,1e-10))*50.0:0.0) +
        (S.phys_vd50?30.0:0.0) +
        (disp<dispT*0.5?20.0:0.0), 100.0);
   S.obs_LiquidityScore = MathMin(
        S.obs_DecayScore*0.4 + S.obs_CurvatureScore*0.4 +
        (disp>dispT*1.2 && (S.bullMomDecay||S.bearMomDecay)?20.0:0.0), 100.0);

   double pmax=MathMax(S.obs_ExpansionScore,MathMax(S.obs_DecayScore,MathMax(S.obs_AbsorptionScore,S.obs_LiquidityScore)));
   double pmin=MathMin(S.obs_ExpansionScore,MathMin(S.obs_DecayScore,MathMin(S.obs_AbsorptionScore,S.obs_LiquidityScore)));
   S.physicsDiff=pmax-pmin;
   S.physicsConsensus=MathMax(0.0,100.0-S.physicsDiff);
}

#endif // F72_OBSERVATION_MQH
