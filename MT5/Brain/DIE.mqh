//+------------------------------------------------------------------+
//|  DIE.mqh — Display/Decision Intelligence Engine (Letra 12D-12J)   |
//|  Hypothesis / Prediction / Validation / Adaptive Confidence /     |
//|  Deviation. The organism's self-observation & learning.           |
//+------------------------------------------------------------------+
#ifndef F72_DIE_MQH
#define F72_DIE_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class DIEEngine
{
private:
   double m_modelConfidence;
   int    m_predOutcomes[100]; int m_predTotalIdx;
   string m_lastExpected, m_lastPhase;
public:
   int    flipzoneStagesComplete;
   string grade;
   void Init(){ m_modelConfidence=50.0; m_predTotalIdx=0; ArrayInitialize(m_predOutcomes,0);
                m_lastExpected="Point 4 Origin"; m_lastPhase="Point 4 Origin"; flipzoneStagesComplete=0; grade="D"; }
   double ModelConfidence(){ return(m_modelConfidence); }

   double predAcc(int n)
   {
      int cnt=MathMin(n,m_predTotalIdx); if(cnt<=0) return(50.0);
      int sum=0,start=MathMax(0,m_predTotalIdx-cnt);
      for(int i=start;i<m_predTotalIdx;i++) sum+=m_predOutcomes[i%100];
      return((double)sum/(double)cnt*100.0);
   }

   void Update(BrainState &S,double close,int htfAlign,int dir_tf1,int dir_tf2,
               bool m1ExpWeak,bool m1ConvEmer,bool m1IndEmer,bool m1LiqEmer,bool m1AbsEmer,
               bool dirFUactive)
   {
      double wp=S.waveProgress, cm=S.convexityMaturity;
      double posDistToCreation = MathMin( (S.direction==1? MathAbs(f72_nz(S.cycleHigh,close)-close):MathAbs(close-f72_nz(S.cycleLow,close))) / MathMax(f72_nz(S.originToExtreme,S.atr*5.0),S.atr*0.5)*100.0,100.0);
      double posDistToDemand = !f72_isna(S.flipTop)&&!f72_isna(S.flipBot)? MathMin(MathAbs(close-(S.flipTop+S.flipBot)/2.0)/MathMax(S.atr*4.0,1e-10)*100.0,100.0):100.0;

      //--- flipzone staged lifecycle (Letra Section 14) ---
      bool preConvSeen = S.closeInside && (S.bullMomDecay||S.bearMomDecay);
      bool inductionConf = (S.ie1a_currentPhase=="Induction"||S.ie1a_currentPhase=="Expansion Induction");
      flipzoneStagesComplete = (S.demandReturnBelief>75 && S.recursiveComplete)?5:
                               S.demandReturnBelief>60?4: S.retracementBelief>55?3: inductionConf?2: preConvSeen?1:0;

      //--- PREDICTION ENGINE (12E) ---
      double effT=InpEffThresh;
      double predExp = (wp<35.0?(35.0-wp)*1.0:0.0)+(S.expansionBelief>55?S.expansionBelief*0.30:0.0)+(cm<25?20.0:0.0)+(posDistToCreation>30?15.0:0.0)+(htfAlign==S.direction&&S.direction!=0?15.0:0.0);
      double predConv= (wp>=25.0&&wp<=60.0?30.0:0.0)+(cm>20?cm*0.30:0.0)+(S.obs_DecayScore>40?20.0:0.0)+(m1ConvEmer?15.0:0.0)+(preConvSeen?15.0:0.0);
      double predCreat=(cm>55?(cm-55.0)*1.20:0.0)+(posDistToCreation<20.0?(20.0-posDistToCreation)*2.0:0.0)+(S.obs_LiquidityScore>55?20.0:0.0)+((S.liqSweepBull||S.liqSweepBear)?15.0:0.0)+(m1LiqEmer?10.0:0.0);
      double predAbs = (predCreat>50?predCreat*0.40:0.0)+(S.obs_AbsorptionScore>35?S.obs_AbsorptionScore*0.30:0.0)+(m1AbsEmer?20.0:0.0)+(wp>=60.0&&wp<=78.0?15.0:0.0);
      double predRetr= (S.absorptionBelief>45?S.absorptionBelief*0.35:0.0)+(((S.direction==1&&S.bearImpulse)||(S.direction==-1&&S.bullImpulse))?25.0:0.0)+(wp>=72.0&&wp<=90.0?20.0:0.0)+(S.physicsConsensus<40?10.0:0.0);
      double predDR  = (S.retracementBelief>45?S.retracementBelief*0.35:0.0)+(posDistToDemand<20.0?(20.0-posDistToDemand)*1.50:0.0)+((S.liqSweepBull||S.liqSweepBear)?20.0:0.0)+(wp>=88.0?(wp-88.0)*1.20:0.0);
      double mx=MathMax(predExp,MathMax(predConv,MathMax(predCreat,MathMax(predAbs,MathMax(predRetr,predDR)))));
      S.expectedNextPhase =
         (predDR>=predRetr&&predDR>=predAbs&&predDR>=predCreat&&predDR>=predConv&&predDR>=predExp)?(S.direction==-1?"Supply Return":"Demand Return"):
         (predRetr>=predAbs&&predRetr>=predCreat&&predRetr>=predConv&&predRetr>=predExp)?"Retracement":
         (predAbs>=predCreat&&predAbs>=predConv&&predAbs>=predExp)?"Absorption":
         (predCreat>=predConv&&predCreat>=predExp)?(S.direction==-1?"New Low":"New High"):
         (predConv>=predExp)?"Expansion Pre-Convexity":"Expansion";
      S.expectedNextProb = mx>0? MathMin(mx/MathMax(mx+30.0,1.0)*100.0,95.0):50.0;

      //--- VALIDATION ENGINE (12F) ---
      bool predTransition = (S.ie1a_currentPhase!=m_lastPhase);
      bool predSucceeded  = predTransition && (S.ie1a_currentPhase==m_lastExpected);
      if(predTransition){ m_predOutcomes[m_predTotalIdx%100]=predSucceeded?1:0; m_predTotalIdx++; }
      m_lastExpected=S.expectedNextPhase; m_lastPhase=S.ie1a_currentPhase;
      double a10=predAcc(10),a25=predAcc(25),a50=predAcc(50),a100=predAcc(100);
      S.predReliability=a10*0.4+a25*0.3+a50*0.2+a100*0.1;

      //--- ADAPTIVE CONFIDENCE (12G) ---
      double confInc=(predSucceeded?3.0:0.0)+(S.physicsConsensus>70?2.0:0.0)+(htfAlign==S.direction&&S.direction!=0?1.5:0.0)+(dir_tf1==dir_tf2&&dir_tf1!=0?1.0:0.0);
      double confDec=(predTransition&&!predSucceeded?2.0:0.0)+(S.physicsDiff>60?2.0:0.0)+(htfAlign!=S.direction&&S.direction!=0?1.5:0.0)+(dir_tf1!=dir_tf2&&dir_tf1!=0&&dir_tf2!=0?1.0:0.0);
      m_modelConfidence=MathMax(10.0,MathMin(100.0, m_modelConfidence+confInc-confDec-InpConfDecayRate*(m_modelConfidence-50.0)));
      S.modelConfidence=m_modelConfidence;

      //--- WAVE DEVIATION (12H) ---
      double idealExp=S.efficiency, idealConv=S.obs_DecayScore/100.0, idealAbs=S.obs_AbsorptionScore/100.0;
      double devRaw = MathAbs(idealExp-(S.ie1a_hypFamily=="EXPANSION"?0.85:0.30))*40.0
                    + MathAbs(idealConv-(S.ie1a_hypFamily=="CONVEXITY FORMING"?0.70:0.20))*30.0
                    + MathAbs(idealAbs-(S.ie1a_hypFamily=="ABSORPTION"?0.70:0.15))*30.0;
      S.waveDeviation=MathMin(devRaw,100.0); S.deviationAlert=S.waveDeviation>InpDevReinterp;

      //--- die_entryScore ---
      S.die_entryScore = MathMin(
         (S.waveModelFit*0.20)+(m_modelConfidence*0.20)+
         (htfAlign==S.direction&&S.direction!=0?20.0:htfAlign==0?10.0:0.0)+
         (S.liqHeat>50?15.0:S.liqHeat*0.30)+
         (dirFUactive?15.0:0.0)+
         (flipzoneStagesComplete>=3?10.0:flipzoneStagesComplete*3.3),100.0);

      //--- grade (continuation probability proxy from confidence + alignment) ---
      double contProb=MathMin(100.0, m_modelConfidence*0.5 + S.fractalStackScore*0.3 + S.ie1a_phaseConfidence*0.2);
      grade = contProb>=90?"A+": contProb>=80?"A": contProb>=70?"B": contProb>=60?"C":"D";
      S.doe_grade=grade;
   }
};

#endif // F72_DIE_MQH
