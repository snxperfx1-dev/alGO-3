//+------------------------------------------------------------------+
//|  Brain.mqh — orchestrates the full recovered cognition pipeline.  |
//|  Computed once per CLOSED exec-TF bar. Owns all stateful engines  |
//|  and the persistent wave-context carried across bars (Pine        |
//|  forward-var pattern). Produces the BrainState decision object.   |
//+------------------------------------------------------------------+
#ifndef F72_BRAIN_MQH
#define F72_BRAIN_MQH

#include "Params.mqh"
#include "BrainState.mqh"
#include "Structure.mqh"
#include "Engine1A.mqh"
#include "Observation.mqh"
#include "Energy.mqh"
#include "Liquidity.mqh"
#include "WaveIntel.mqh"
#include "Spawn.mqh"
#include "DIE.mqh"
#include "FRZ.mqh"
#include "CurveOrganism.mqh"
#include "TimeIntel.mqh"
#include "Network.mqh"
#include "Senseei.mqh"

class Brain
{
private:
   string          m_sym;
   ENUM_TIMEFRAMES m_tf;
   Engine1A        m_e1a;
   LiquidityEngine m_liq;
   WaveIntelEngine m_wi;
   SpawnEngine     m_spawn;
   DIEEngine       m_die;
   FRZEngine       m_frz;
   CurveOrganism   m_curve;
   TimeIntel       m_time;
   NetworkEngine   m_net;

   datetime        m_lastBar;
   int             m_structBias;
   // persistent wave-context (prev-bar forward vars)
   double m_pConvMat;
   BrainState      m_S;     // last computed state

   void m1flags(bool &expWeak,bool &convEmer,bool &indEmer,bool &liqEmer,bool &absEmer)
   {
      expWeak=convEmer=indEmer=liqEmer=absEmer=false;
      MqlRates r[]; int need=InpEffLen+5; if(CopyRates(m_sym,PERIOD_M1,1,need,r)<need) return;
      int n=ArraySize(r);
      double c=r[n-1].close, h=r[n-1].high, l=r[n-1].low;
      double v=(r[n-1].close-r[n-2].close); v=0.5*v+0.5*(r[n-2].close-r[n-3].close);
      double a=(r[n-1].close-r[n-2].close)-(r[n-2].close-r[n-3].close);
      double cv=a-((r[n-2].close-r[n-3].close)-(r[n-3].close-r[n-4].close));
      double mv=MathAbs(c-r[n-1-InpEffLen].close);
      double ps=0; for(int i=n-InpEffLen;i<n;i++) ps+=MathAbs(r[i].close-r[i-1].close);
      double e=ps>0?mv/ps:0.0;
      double atr=0; for(int i=1;i<n;i++) atr+=MathAbs(r[i].close-r[i-1].close); atr=MathMax(atr/(n-1),1e-10);
      double d=(h-l)/atr;
      bool mD=MathAbs(a)<MathAbs((r[n-2].close-r[n-3].close)-(r[n-3].close-r[n-4].close))*0.8;
      expWeak  = e<InpEffThresh*0.7 && mD;
      convEmer = MathAbs(cv)>atr*InpConvMult*1.5 && mD;
      indEmer  = e>InpEffThresh && a<0 && v>0;
      liqEmer  = d>InpDispThresh*1.2 && mD;
      absEmer  = e<InpEffThresh*0.5 && d<InpDispThresh*0.6;
   }

public:
   void Init(string sym,ENUM_TIMEFRAMES tf)
   {
      m_sym=sym; m_tf=tf; m_lastBar=0; m_structBias=0; m_pConvMat=0;
      m_e1a.Init(sym,tf); m_liq.Init(); m_wi.Init(); m_spawn.Init(); m_die.Init();
      m_frz.Init(); m_curve.Init(); m_time.Init(sym); m_net.Init(sym);
      // BrainState is value-initialised on construction (numbers 0, strings "").
      // prev-bar wave-context price fields must start as NA (not 0)
      m_S.flipTop=F72_NA; m_S.flipBot=F72_NA; m_S.point4OriginHigh=F72_NA; m_S.point4OriginLow=F72_NA;
      m_S.cycleHigh=F72_NA; m_S.cycleLow=F72_NA; m_S.inducZoneLow=F72_NA; m_S.inducZoneHigh=F72_NA;
      m_S.originToExtreme=F72_NA; m_S.availableSpace=F72_NA; m_S.eae_primaryAttractorPrice=F72_NA;
      m_S.eae_secondaryAttractorPrice=F72_NA; m_S.inv_activeStop=F72_NA;
      m_S.re_resolutionState="UNRESOLVED"; m_S.ie1a_currentPhase="Point 4 Origin";
   }

   BrainState State(){ return(m_S); }

   // returns true if a fresh decision was computed (on new closed bar)
   bool OnNewBar()
   {
      datetime t1=iTime(m_sym,m_tf,1);
      if(t1==0 || t1==m_lastBar) return(false);
      m_lastBar=t1;

      // closed bar [1] values
      double o=iOpen(m_sym,m_tf,1), h=iHigh(m_sym,m_tf,1), l=iLow(m_sym,m_tf,1), c=iClose(m_sym,m_tf,1);
      double vol=(double)iTickVolume(m_sym,m_tf,1);
      double volAvg=0; { long vsum=0; for(int i=1;i<=20;i++) vsum+=iTickVolume(m_sym,m_tf,i); volAvg=(double)vsum/20.0; }
      int barIndex=Bars(m_sym,m_tf);

      BrainState S;   // value-initialised (numbers 0, strings "")

      //--- 1. Engine 1A (6-rung structure ladder) ---
      m_e1a.Update();
      SE_Out canon=m_e1a.Canon();
      // canonical physics
      S.atr=canon.atr; S.velocity=canon.vel; S.acceleration=canon.acc; S.convSmooth=canon.convSmooth;
      S.efficiency=canon.eff; S.displacement=canon.disp;
      S.bullImpulse=canon.bullImp; S.bearImpulse=canon.bearImp;
      S.bullMomDecay=canon.bullDec; S.bearMomDecay=canon.bearDec;
      S.bullConvShift=canon.bullCS; S.bearConvShift=canon.bearCS;
      S.phys_vd70=canon.vd70; S.phys_vd50=canon.vd50;
      // engine 1A outputs
      S.ie1a_currentPhase=m_e1a.CurrentPhase();
      S.ie1a_phaseConfidence=m_e1a.PhaseConfidence();
      S.ie1a_hypFamily=m_e1a.HypFamily();
      S.fractalStackDir=m_e1a.fractalStackDir; S.fractalStackScore=m_e1a.fractalStackScore;
      S.waveDir=m_e1a.CanonDir();
      // structBias (Letra) from canonical swings
      bool isHH=!f72_isna(canon.curSH)&&!f72_isna(canon.prSH)&&canon.curSH>canon.prSH;
      bool isLH=!f72_isna(canon.curSH)&&!f72_isna(canon.prSH)&&canon.curSH<canon.prSH;
      bool isHL=!f72_isna(canon.curSL)&&!f72_isna(canon.prSL)&&canon.curSL>canon.prSL;
      bool isLL=!f72_isna(canon.curSL)&&!f72_isna(canon.prSL)&&canon.curSL<canon.prSL;
      if(InpUseStrictStruct){ if(isHH&&isHL) m_structBias=1; if(isLH&&isLL) m_structBias=-1; }
      else { if(canon.bos==1) m_structBias=1; if(canon.bos==-1) m_structBias=-1; }
      S.structBias=m_structBias;

      //--- load PREV wave-context forward vars (set by last bar's spawn) ---
      S.direction=m_S.direction; S.flipTop=m_S.flipTop; S.flipBot=m_S.flipBot;
      S.point4OriginHigh=m_S.point4OriginHigh; S.point4OriginLow=m_S.point4OriginLow;
      S.cycleHigh=m_S.cycleHigh; S.cycleLow=m_S.cycleLow;
      S.inducZoneLow=m_S.inducZoneLow; S.inducZoneHigh=m_S.inducZoneHigh;
      S.entryCycle=m_S.entryCycle; S.waveDepth=m_S.waveDepth; S.recursiveComplete=m_S.recursiveComplete;
      S.closeInside=m_S.closeInside; S.originToExtreme=m_S.originToExtreme; S.availableSpace=m_S.availableSpace;
      S.convexityMaturity=m_pConvMat;

      //--- 2. Observation ---
      ComputeObservation(S);
      //--- 3. Energy (uses prev wave-context + prev convexityMaturity) ---
      ComputeEnergy(S,c);
      //--- 4. Liquidity (uses prev flip zone for sweeps) ---
      m_liq.Update(S,h,l,c,vol,volAvg,barIndex);
      //--- 5. Wave intelligence + beliefs (uses prev wave-context) ---
      m_wi.Update(S,c);
      m_pConvMat=S.convexityMaturity;
      //--- 6. Spawn (mutates wave context for THIS bar) ---
      bool bullCH=(canon.ch==1), bearCH=(canon.ch==-1);
      m_spawn.Update(S,o,h,l,c,m_e1a.CanonDir(),canon.p4h,canon.p4l,bullCH,bearCH);
      //--- 7. DIE (self-observation / learning) ---
      int dir_tf1=m_e1a.ldir[3], dir_tf2=m_e1a.ldir[4];
      int htfAlign=(dir_tf1+dir_tf2)>0?1:(dir_tf1+dir_tf2)<0?-1:0;
      bool m1ew,m1ce,m1ie,m1le,m1ae; m1flags(m1ew,m1ce,m1ie,m1le,m1ae);
      bool dirFUactive=(S.frz_activeCount>0 && S.frz_bestDir==S.direction);
      m_die.Update(S,c,htfAlign,dir_tf1,dir_tf2,m1ew,m1ce,m1ie,m1le,m1ae,dirFUactive);
      //--- 8. FRZ ---
      m_frz.Update(S,o,h,l,c);
      //--- 9. Curve organism / Life ---
      m_curve.Update(S,canon,h,l,c);
      //--- 10. Time intelligence ---
      m_time.Update(S,c);
      //--- 11. Invisible network ---
      m_net.Update(S,c);
      //--- 12. Senseei / DOE decision ---
      ComputeSenseei(S,c);

      m_S=S;
      return(true);
   }
};

#endif // F72_BRAIN_MQH
