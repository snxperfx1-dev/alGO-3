//+------------------------------------------------------------------+
//|  Engine1A.mqh — 6-rung structure ladder, Engine 1A authority,     |
//|  fractal stack. Replaces Pine request.security(_wtfN, f_se(...)). |
//|  Adaptive ladder climbs from the execution timeframe (verbatim    |
//|  _wtf1.._wtf6 mapping). se5 (_wtf3 = exec TF) is canonical.        |
//+------------------------------------------------------------------+
#ifndef F72_ENGINE1A_MQH
#define F72_ENGINE1A_MQH

#include "Structure.mqh"

class Engine1A
{
private:
   string            m_sym;
   ENUM_TIMEFRAMES   m_tf[6];      // rung timeframes (index 0=se1 .. 5=se240)
   StructureEngine  *m_eng[6];     // MQL5: array of object pointers (no array of objects)
   SE_Out            m_out[6];
   datetime          m_lastBar[6];

   // direction-by-origin: lN_dir = f_waveDirByOrigin(seN_inv, seN_dir)
   int dirByOrigin(const SE_Out &o)
   {
      double origin=o.inv; int fb=o.dir;
      double c=iClose(m_sym,m_tf[2],1);   // canonical exec-TF closed bar
      if(f72_isna(origin)) return(fb);
      return(c>origin?1: c<origin?-1: fb);
   }

   void buildLadder(ENUM_TIMEFRAMES exec)
   {
      int s=PeriodSeconds(exec);
      // verbatim _wtf mapping (intraday branch fully native; higher TFs use
      // nearest MT5-native periods — the organism is designed for M1..M15).
      if(s<3600)        { setL(PERIOD_M1,PERIOD_M3,exec,PERIOD_M15,PERIOD_H1,PERIOD_H4); }
      else if(s<14400)  { setL(PERIOD_H1,PERIOD_H2,exec,PERIOD_H8,PERIOD_H12,PERIOD_D1); }
      else if(s<86400)  { setL(PERIOD_H4,PERIOD_H8,exec,PERIOD_D1,PERIOD_D1,PERIOD_D1); }
      else if(s<604800) { setL(PERIOD_D1,PERIOD_D1,exec,PERIOD_W1,PERIOD_W1,PERIOD_MN1); }
      else              { setL(PERIOD_W1,PERIOD_W1,exec,PERIOD_MN1,PERIOD_MN1,PERIOD_MN1); }
   }
   void setL(ENUM_TIMEFRAMES a,ENUM_TIMEFRAMES b,ENUM_TIMEFRAMES c,ENUM_TIMEFRAMES d,ENUM_TIMEFRAMES e,ENUM_TIMEFRAMES f)
   { m_tf[0]=a;m_tf[1]=b;m_tf[2]=c;m_tf[3]=d;m_tf[4]=e;m_tf[5]=f; }

   // Feed all newly-closed bars of rung r in chronological order.
   void feedRung(int r)
   {
      int avail=Bars(m_sym,m_tf[r]); if(avail<3) return;
      // process closed bars (shift>=1). Catch up from last processed.
      // find how many closed bars are newer than m_lastBar[r].
      datetime t1=iTime(m_sym,m_tf[r],1);
      if(t1==0) return;
      if(m_lastBar[r]==0)
      {
         // backfill last N closed bars oldest->newest
         int back=MathMin(avail-1,600);
         for(int i=back;i>=1;i--)
         {
            MqlRates rt[]; if(CopyRates(m_sym,m_tf[r],i,1,rt)==1)
               m_eng[r].ProcessNewBar(rt[0].open,rt[0].high,rt[0].low,rt[0].close,m_out[r]);
         }
         m_lastBar[r]=t1;
      }
      else if(t1>m_lastBar[r])
      {
         // process every closed bar between last processed and t1
         int shift=1; while(shift<avail && iTime(m_sym,m_tf[r],shift)>m_lastBar[r]) shift++;
         for(int i=shift-1;i>=1;i--)
         {
            MqlRates rt[]; if(CopyRates(m_sym,m_tf[r],i,1,rt)==1)
               m_eng[r].ProcessNewBar(rt[0].open,rt[0].high,rt[0].low,rt[0].close,m_out[r]);
         }
         m_lastBar[r]=t1;
      }
   }

public:
   // fractal stack
   int    fractalStackDir;
   double fractalStackScore;
   int    ldir[6];               // l(0..5)_dir by origin

   Engine1A(){ for(int r=0;r<6;r++){ m_eng[r]=NULL; m_lastBar[r]=0; } }

   void Init(string sym,ENUM_TIMEFRAMES exec)
   {
      m_sym=sym; buildLadder(exec);
      for(int r=0;r<6;r++)
      {
         m_eng[r]=new StructureEngine;
         m_eng[r].Init(InpPivotLen,InpEffLen,InpAtrLen,InpEffThresh,InpDispThresh,InpConvMult,InpImpulseAtrMult,InpChochBufferATR);
         m_lastBar[r]=0;
      }
   }
   void Deinit(){ for(int r=0;r<6;r++) if(CheckPointer(m_eng[r])==POINTER_DYNAMIC) delete m_eng[r]; }
  ~Engine1A(){ Deinit(); }

   void Update()
   {
      for(int r=0;r<6;r++){ feedRung(r); ldir[r]=dirByOrigin(m_out[r]); }
      int sb=0,sr=0;
      for(int r=0;r<6;r++){ if(ldir[r]==1) sb++; else if(ldir[r]==-1) sr++; }
      fractalStackDir = sb>sr?1: sr>sb?-1:0;
      fractalStackScore = (double)MathMax(sb,sr)/6.0*100.0;
   }

   // accessors (rung index: 0=se1 1=se3 2=se5(canonical) 3=se15 4=se60 5=se240)
   SE_Out  Rung(int r){ return(m_out[r]); }
   SE_Out  Canon(){ return(m_out[2]); }           // se5 == Engine 1A canonical
   int     CanonDir(){ return(ldir[2]); }
   string  CurrentPhase(){ return(F72_PhaseName(m_out[2].phase)); }
   double  PhaseConfidence()
   {
      return(MathMax(20.0,MathMin(100.0, fractalStackScore*0.50 + f72_nz(m_out[2].mf,0)*0.30 + f72_nz(m_out[2].wp,0)*0.20)));
   }
   // canonical -> hypothesis family (ie1a_hypFamily)
   string  HypFamily()
   {
      string p=CurrentPhase();
      if(p=="Expansion") return("EXPANSION");
      if(p=="Expansion Pre-Convexity"||p=="Expansion Induction") return("CONVEXITY FORMING");
      if(p=="New High"||p=="New Low") return("CREATION FORMING");
      if(p=="Retracement"||p=="HTF Flip Zone") return("RETRACEMENT");
      if(p=="Demand Return"||p=="Supply Return") return("DEMAND/SUPPLY RETURN");
      if(p=="Liquidation"||p=="Terminal Curve"||p=="Induction") return("ABSORPTION");
      return("EXPANSION");
   }
};

#endif // F72_ENGINE1A_MQH
