//+------------------------------------------------------------------+
//|  WaveIntel.mqh — Wave Intelligence (Letra Section 12)              |
//|  sim_* similarity, convexityMaturity, waveProgress, belief        |
//|  distribution. Stateful (EMA smoothing across bars).              |
//+------------------------------------------------------------------+
#ifndef F72_WAVEINTEL_MQH
#define F72_WAVEINTEL_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class WaveIntelEngine
{
private:
   double m_convMat, m_waveProg;
   double m_exp,m_conv,m_creat,m_abs,m_retr,m_dr;   // smoothed beliefs
   double m_prevVel2;                               // for velocity[2] proxy
   double m_velHist[3];
   double idealSim(double e,double d,double v,double cu,double ie,double id,double iv,double ic)
   {
      double diff=MathPow(e-ie,2)+MathPow(d-id,2)+MathPow(v-iv,2)+MathPow(cu-ic,2);
      return(MathMax(0.0,100.0*(1.0-diff/4.0)));
   }
public:
   void Init(){ m_convMat=0; m_waveProg=30.0; m_exp=0;m_conv=0;m_creat=0;m_abs=0;m_retr=0;m_dr=0; m_prevVel2=0; ArrayInitialize(m_velHist,0);}
   double ConvexityMaturity(){ return(m_convMat); }
   double WaveProgress(){ return(m_waveProg); }

   void Update(BrainState &S,double close)
   {
      double atr=S.atr, eff=S.efficiency, disp=S.displacement, vel=S.velocity, csm=S.convSmooth;
      double effT=InpEffThresh, dispT=InpDispThresh;
      double eN=MathMin(eff,1.0);
      double dN=MathMin(disp/MathMax(dispT*2.0,1e-10),1.0);
      double vN=MathMin(MathAbs(vel)/MathMax(atr*0.15,1e-10),1.0);
      double cN=MathMin(MathAbs(csm)/MathMax(atr*InpConvMult*2.0,1e-10),1.0);
      S.sim_Expansion   = idealSim(eN,dN,vN,cN,0.85,0.80,0.80,0.10);
      S.sim_PreConv     = idealSim(eN,dN,vN,cN,0.60,0.55,0.40,0.50);
      S.sim_Induction   = idealSim(eN,dN,vN,cN,0.65,0.60,0.30,0.60);
      S.sim_Liquidity   = idealSim(eN,dN,vN,cN,0.45,0.85,0.15,0.80);
      S.sim_Creation    = idealSim(eN,dN,vN,cN,0.30,0.70,0.05,0.90);
      S.sim_Absorption  = idealSim(eN,dN,vN,cN,0.20,0.25,0.10,0.40);
      S.sim_Retracement = idealSim(eN,dN,vN,cN,0.70,0.65,0.65,0.25);
      S.sim_DemandReturn= idealSim(eN,dN,vN,cN,0.50,0.40,0.35,0.20);

      // geometry
      double waveTotalRange = !f72_isna(S.originToExtreme)? S.originToExtreme : atr*5.0;
      double currentToExtreme = S.direction==1? MathAbs(f72_nz(S.cycleHigh,close+atr)-close) : MathAbs(close-f72_nz(S.cycleLow,close-atr));
      double posNormDen=MathMax(waveTotalRange,atr*0.5);
      double posDistToCreation=MathMin(currentToExtreme/posNormDen*100.0,100.0);

      // velocity[2] proxy
      double v2=m_velHist[2];
      double expWeak = MathMin(((eff<effT? (1.0-eff/MathMax(effT,1e-10))*40.0:0.0)+(S.obs_DecayScore*0.30)+(MathAbs(vel)<MathAbs(v2)*0.6?20.0:0.0))*(100.0/90.0),100.0);
      double inducMat= MathMin((/*inducEvidence proxy*/ (S.ie1a_currentPhase=="Induction"||S.ie1a_currentPhase=="Expansion Induction")?35.0:0.0)+(S.obs_CurvatureScore*0.35)+((S.ie1a_currentPhase=="Expansion Pre-Convexity")?20.0:0.0)+((disp>dispT*1.2&&(S.bullMomDecay||S.bearMomDecay))?10.0:0.0),100.0);
      double liqMat  = MathMin((S.obs_LiquidityScore*0.50)+((S.liqSweepBull||S.liqSweepBear)?30.0:0.0)+(S.liqHeat>60?20.0:S.liqHeat>30?10.0:0.0),100.0);
      double rawConvMat=MathMin(expWeak*0.35+inducMat*0.35+liqMat*0.30,100.0);
      double alpha=2.0/(InpBeliefSmooth+1);
      m_convMat=m_convMat+alpha*(rawConvMat-m_convMat);
      S.convexityMaturity=m_convMat;

      // waveProgress geom + phys
      double geomProg=30.0;
      if(!f72_isna(S.point4OriginHigh)&&!f72_isna(S.flipTop)&&!f72_isna(S.flipBot))
      {
         double origin=S.direction==1? S.point4OriginLow:S.point4OriginHigh;
         double extreme=S.direction==1? f72_nz(S.cycleHigh,close+atr):f72_nz(S.cycleLow,close-atr);
         double fzMid=(S.flipTop+S.flipBot)/2.0;
         double totalMove=MathAbs(extreme-origin), toFz=MathAbs(extreme-fzMid);
         double expProg = totalMove>1e-10? MathMin(MathAbs(close-origin)/totalMove*60.0,60.0):30.0;
         double retrMove=MathAbs(close-extreme);
         double retrProg= toFz>1e-10? MathMin(retrMove/MathMax(toFz,1e-10)*40.0,40.0):0.0;
         geomProg=expProg+retrProg*MathMin(S.obs_AbsorptionScore/40.0,1.0);
      }
      double simAnchor =
         (S.sim_DemandReturn>=S.sim_Retracement && S.sim_DemandReturn>=S.sim_Absorption && S.sim_DemandReturn>=S.sim_Creation && S.sim_DemandReturn>=S.sim_Expansion)?95.0:
         (S.sim_Retracement>=S.sim_Absorption && S.sim_Retracement>=S.sim_Creation && S.sim_Retracement>=S.sim_Expansion)?87.0:
         (S.sim_Absorption>=S.sim_Creation && S.sim_Absorption>=S.sim_Expansion)?75.0:
         (S.sim_Creation>=S.sim_Liquidity && S.sim_Creation>=S.sim_Expansion)?62.0:
         (S.sim_Liquidity>=S.sim_Induction && S.sim_Liquidity>=S.sim_Expansion)?52.0:
         (S.sim_Induction>=S.sim_PreConv && S.sim_Induction>=S.sim_Expansion)?43.0:
         (S.sim_PreConv>=S.sim_Expansion)?33.0:22.0;
      double convW=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
      double physProg=simAnchor+(m_convMat/100.0)*(simAnchor-33.0)*0.50*convW;
      double rawWP=geomProg*0.60+physProg*0.40;
      m_waveProg=m_waveProg+alpha*(rawWP-m_waveProg);
      S.waveProgress=m_waveProg;
      S.waveModelFit=S.ie1a_phaseConfidence;   // model fit proxy = canonical phase confidence (se5_mf basis)

      // belief distribution (raw * position multiplier, EMA)
      bool impulse=S.bullImpulse||S.bearImpulse;
      double expMult=(m_waveProg<40.0)?1.30:0.70;
      double rawExp=MathMin((S.obs_ExpansionScore*0.45+(impulse?30.0:0.0)+(eff>effT*1.1?15.0:0.0)+S.sim_Expansion*0.10)*expMult,100.0);
      double convPosMult=(m_waveProg>=30.0&&m_waveProg<=65.0)?1.30:0.70;
      double rawConv=MathMin((S.obs_DecayScore*0.30+S.obs_CurvatureScore*0.25+S.convexityMaturity*0.08)*convPosMult,100.0);
      double creatMult=(m_waveProg>=45.0&&m_waveProg<=68.0)?1.40:0.60;
      double rawCreat=MathMin(((S.convexityMaturity>50?S.convexityMaturity*0.12:0.0)+(S.obs_DecayScore>60?S.obs_DecayScore*0.20:0.0)+(S.obs_LiquidityScore>50?S.obs_LiquidityScore*0.20:0.0)+(S.obs_AbsorptionScore>20?S.obs_AbsorptionScore*0.15:0.0)+S.sim_Creation*0.10+(posDistToCreation<15.0?(15.0-posDistToCreation)*1.0:0.0))*creatMult,100.0);
      double rawAbs=MathMin(S.obs_AbsorptionScore*0.50+(eff<effT*0.6?25.0:0.0)+(disp<dispT*0.5?15.0:0.0)+S.sim_Absorption*0.10,100.0);
      double rawRetr=MathMin(((S.direction==1&&S.bearImpulse)||(S.direction==-1&&S.bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(S.obs_CurvatureScore>40?15.0:0.0)+S.sim_Retracement*0.10,100.0);
      double rawDR=MathMin((!f72_isna(S.flipTop)&&!f72_isna(S.flipBot)&&close<=S.flipTop&&close>=S.flipBot?35.0:0.0)+(rawRetr>60?rawRetr*0.30:0.0)+(S.liqHeat>50?S.liqHeat*0.15:0.0)+((S.liqSweepBull||S.liqSweepBear)?20.0:0.0)+S.sim_DemandReturn*0.10,100.0);
      m_exp=m_exp+alpha*(rawExp-m_exp);   m_conv=m_conv+alpha*(rawConv-m_conv);
      m_creat=m_creat+alpha*(rawCreat-m_creat); m_abs=m_abs+alpha*(rawAbs-m_abs);
      m_retr=m_retr+alpha*(rawRetr-m_retr); m_dr=m_dr+alpha*(rawDR-m_dr);
      S.expansionBelief=m_exp; S.convexityBelief=m_conv; S.creationBelief=m_creat;
      S.absorptionBelief=m_abs; S.retracementBelief=m_retr; S.demandReturnBelief=m_dr;

      // shift velocity history
      m_velHist[2]=m_velHist[1]; m_velHist[1]=m_velHist[0]; m_velHist[0]=vel;
   }
};

#endif // F72_WAVEINTEL_MQH
