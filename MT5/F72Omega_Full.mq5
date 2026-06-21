//+------------------------------------------------------------------+
//|                                                F72Omega_Full.mq5  |
//|   F72 OMEGA — synthetic trading organism (single-file MT5).       |
//|   BRAIN = recovered cognition (V60/F16 lifecycle authority +      |
//|   Letra energy/DIE + F72 decision surface). BODY = execution.     |
//|   The intelligence decides; the body never overrules it.          |
//|   Lineage: F72 (ancestry) -> Letra 37 -> V60/F16 (final form).    |
//|   Nothing invented. See F72_OMEGA_MASTER_ARCHITECTURE.md.         |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "1.00"
#property strict
#include <Trade/Trade.mqh>

//============================== INPUTS ==============================
input int    InpPivotLen       = 5;
input int    InpAtrLen         = 14;
input int    InpEffLen         = 10;
input int    InpStructLen      = 10;
input double InpImpulseAtrMult = 1.5;
input double InpEffThresh       = 0.65;
input double InpDispThresh      = 1.5;
input double InpConvMult        = 0.01;
input double InpChochBufferATR  = 0.75;
input bool   InpUseStrictStruct = true;
input int    InpAcceptBars      = 2;
input int    InpObMaxBars       = 50;
input int    InpInducLookback   = 80;
input double InpInducZoneWidth  = 0.25;
input int    InpLiqSweepLook    = 10;
input double InpLiqRadius        = 0.25;
input double InpLiqAgDecay        = 0.95;
input bool   InpRequireLiqSweep   = true;
input int    InpResetBars         = 20;
input int    InpBeliefSmooth      = 3;
input double InpConfDecayRate     = 0.02;
input double InpDevReinterp        = 30.0;
input int    InpFrzMinScore        = 26;
input int    InpFrzMaxBars         = 100;
input int    InpFuLookback         = 3;
input double InpFuMinBodyRatio     = 0.6;
input double InpFuMinWickRatio     = 0.25;
input int    InpFuMaxBars          = 75;
input double InpErfReadyResW       = 0.25;
input double InpErfReadyResidW     = 0.20;
input double InpErfReadyConfW      = 0.15;
input double InpErfEntryThresh     = 45.0;
input bool   InpErfGateEnabled     = true;

input double InpWickFrac        = 0.3;
input int    InpFuStructLook    = 3;
input int    InpAuthMin         = 45;
input int    InpNodeMax         = 250;
input int    InpDormantBars     = 120;
input int    InpHistoryBars     = 600;
input int    InpMinConf         = 55;
input ENUM_TIMEFRAMES InpExecTF = PERIOD_M5;
input double InpRiskPctPerTrade = 0.5;
input double InpMaxRiskPctTotal = 2.0;
input int    InpMaxPositions    = 1;
input double InpDailyLossCapPct = 4.0;
input long   InpMagic           = 720060;
input int    InpSlippagePts     = 30;
input double InpStopBufferATR   = 0.25;
input bool   InpUseTP1          = true;
input double InpTP1ClosePct     = 50.0;
input int    InpBaseLockBars    = 10;
input bool   InpEnableTrading   = true;
input bool   InpVerboseJournal  = true;

//============================== HELPERS ==============================
#define F72_NA (EMPTY_VALUE)
bool   f72_isna(double v){ return(v==F72_NA || v>=EMPTY_VALUE*0.999 || !MathIsValidNumber(v)); }
double f72_nz(double v,double rep){ return(f72_isna(v)?rep:v); }

string F72_PhaseName(int c)
{
   switch(c)
   {
      case 1:  return("Expansion");
      case 2:  return("Expansion Pre-Convexity");
      case 3:  return("Expansion Induction");
      case 4:  return("Expansion Liquidity");
      case 5:  return("New High");
      case 6:  return("New Low");
      case 7:  return("Transition");
      case 8:  return("Retracement");
      case 9:  return("HTF Flip Zone");
      case 10: return("Induction");
      case 11: return("Liquidation");
      case 12: return("Terminal Curve");
      case 13: return("Demand Return");
      case 14: return("Supply Return");
      default: return("Point 4 Origin");
   }
}

//============================== SE_Out ==============================
struct SE_Out
{
   int    dir, phase;
   double curSH, curSL, prSH, prSL;
   int    bos, ch;
   double p4h, p4l, inv, tgt, ft, fb, frzS, wp, cm, mf, compIdx;
   int    recBrk; double recDom;
   double atr, vel, acc, convSmooth, eff, disp;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;
};

//============================== StructureEngine =====================
class StructureEngine
{
private:
   double m_atr; bool m_atrInit;
   double m_velEma; bool m_velInit;
   double m_prevVel,m_prevAcc,m_prevConv;
   double m_convSmEma; bool m_convInit; double m_prevConvSm;
   double m_close[],m_high[],m_low[]; int m_nbars;
   double m_curSH,m_curSL,m_prSH,m_prSL;
   double m_lastP,m_prevP; int m_lastD,m_prevD;
   int    m_dir;
   double m_ft,m_fb,m_p4h,m_p4l,m_inv,m_tgt,m_cycH,m_cycL;
   bool   m_bos1,m_bos2; double m_protSw,m_protSw2,m_indOrig,m_indExt; bool m_indBrk;
   int    m_lastDirSeen, m_recBrk; bool m_recArm; int m_pst;
   int    m_pvLen,m_effLen,m_atrLen;
   double m_convMult,m_effThresh,m_dispThresh,m_impMult,m_chBuf;
   double getC(int b){ return(b<m_nbars?m_close[b]:F72_NA); }
   double pivotHigh(){int L=m_pvLen;if(m_nbars<2*L+1)return(F72_NA);double m=m_high[L];for(int i=1;i<=L;i++)if(m_high[L-i]>=m||m_high[L+i]>=m)return(F72_NA);return(m);}
   double pivotLow(){int L=m_pvLen;if(m_nbars<2*L+1)return(F72_NA);double m=m_low[L];for(int i=1;i<=L;i++)if(m_low[L-i]<=m||m_low[L+i]<=m)return(F72_NA);return(m);}
public:
   void Init(int pvLen,int effLen,int atrLen,double effT,double dispT,double convM,double impM,double chBuf)
   {
      m_pvLen=pvLen;m_effLen=effLen;m_atrLen=atrLen;m_effThresh=effT;m_dispThresh=dispT;m_convMult=convM;m_impMult=impM;m_chBuf=chBuf;
      m_atrInit=false;m_velInit=false;m_convInit=false;m_prevVel=0;m_prevAcc=0;m_prevConv=0;m_prevConvSm=0;m_velEma=0;m_convSmEma=0;m_atr=0;
      m_nbars=0;ArrayResize(m_close,0);ArrayResize(m_high,0);ArrayResize(m_low,0);
      m_curSH=F72_NA;m_curSL=F72_NA;m_prSH=F72_NA;m_prSL=F72_NA;m_lastP=F72_NA;m_prevP=F72_NA;m_lastD=0;m_prevD=0;
      m_dir=0;m_ft=F72_NA;m_fb=F72_NA;m_p4h=F72_NA;m_p4l=F72_NA;m_inv=F72_NA;m_tgt=F72_NA;m_cycH=F72_NA;m_cycL=F72_NA;
      m_bos1=false;m_bos2=false;m_protSw=F72_NA;m_protSw2=F72_NA;m_indOrig=F72_NA;m_indExt=F72_NA;m_indBrk=false;
      m_lastDirSeen=0;m_recBrk=0;m_recArm=true;m_pst=0;
   }
   void pushBar(double o,double h,double l,double c)
   {
      int keep=MathMax(2*m_pvLen+5,MathMax(m_effLen+3,40));
      ArrayResize(m_close,m_nbars+1);ArrayResize(m_high,m_nbars+1);ArrayResize(m_low,m_nbars+1);
      for(int i=m_nbars;i>0;i--){m_close[i]=m_close[i-1];m_high[i]=m_high[i-1];m_low[i]=m_low[i-1];}
      m_close[0]=c;m_high[0]=h;m_low[0]=l;m_nbars++;
      if(m_nbars>keep){ArrayResize(m_close,keep);ArrayResize(m_high,keep);ArrayResize(m_low,keep);m_nbars=keep;}
   }

   void ProcessNewBar(double o,double h,double l,double c,SE_Out &out)
   {
      pushBar(o,h,l,c);
      double tr,prevC=getC(1);
      if(f72_isna(prevC)) tr=h-l; else tr=MathMax(h-l,MathMax(MathAbs(h-prevC),MathAbs(l-prevC)));
      if(!m_atrInit){m_atr=h-l;m_atrInit=true;} else m_atr=(m_atr*(m_atrLen-1)+tr)/m_atrLen;
      double diff=f72_isna(prevC)?0.0:c-prevC;
      if(!m_velInit){m_velEma=diff;m_velInit=true;} else m_velEma=m_velEma+0.5*(diff-m_velEma);
      double vel=m_velEma, acc=vel-m_prevVel, conv=acc-m_prevAcc;
      if(!m_convInit){m_convSmEma=conv;m_convInit=true;} else m_convSmEma=m_convSmEma+0.5*(conv-m_convSmEma);
      double csm=m_convSmEma;
      double cE=getC(m_effLen); double mv=f72_isna(cE)?0.0:MathAbs(c-cE);
      double ps=0; for(int i=0;i<m_effLen;i++){double a=getC(i),b=getC(i+1);if(!f72_isna(a)&&!f72_isna(b))ps+=MathAbs(a-b);}
      double eff=ps>0?mv/ps:0.0, disp=(h-l)/MathMax(m_atr,1e-10), cth=m_atr*m_convMult;
      bool bImp=eff>m_effThresh&&vel>m_prevVel&&acc>0&&c>o&&disp>m_dispThresh;
      bool rImp=eff>m_effThresh&&vel<m_prevVel&&acc<0&&c<o&&disp>m_dispThresh;
      bool bDec=MathAbs(acc)<MathAbs(m_prevAcc)*0.8&&vel>0;
      bool rDec=MathAbs(acc)<MathAbs(m_prevAcc)*0.8&&vel<0;
      bool bCS=csm>cth&&m_prevConvSm<=cth, rCS=csm<-cth&&m_prevConvSm>=-cth;
      bool vd70=MathAbs(vel)<MathAbs(m_prevVel)*0.7, vd50=MathAbs(vel)<MathAbs(m_prevVel)*0.5;

      double pH=pivotHigh(),pL=pivotLow();
      if(!f72_isna(pH)){m_prSH=f72_isna(m_curSH)?pH:m_curSH;m_curSH=pH;}
      if(!f72_isna(pL)){m_prSL=f72_isna(m_curSL)?pL:m_curSL;m_curSL=pL;}
      double eP=F72_NA;int eD=0;
      if(!f72_isna(pH)){eP=pH;eD=1;} else if(!f72_isna(pL)){eP=pL;eD=-1;}
      if(eD!=0){m_prevP=m_lastP;m_prevD=m_lastD;m_lastP=eP;m_lastD=eD;}
      bool bullBOS=!f72_isna(m_prSH)&&c>m_prSH, bearBOS=!f72_isna(m_prSL)&&c<m_prSL;
      bool bullCH=!f72_isna(m_prSH)&&c>m_prSH+m_atr*m_chBuf, bearCH=!f72_isna(m_prSL)&&c<m_prSL-m_atr*m_chBuf;
      bool eLong=!f72_isna(pH)&&m_prevD==-1&&(pH-m_prevP)>m_atr*m_impMult;
      bool eShort=!f72_isna(pL)&&m_prevD==1&&(m_prevP-pL)>m_atr*m_impMult;
      bool hasCtx=m_dir!=0&&!f72_isna(m_ft);
      bool flipDn=m_dir==1&&bearCH, flipUp=m_dir==-1&&bullCH;
      bool isRev=(eLong&&m_dir==-1)||(eShort&&m_dir==1)||flipUp||flipDn;
      bool spawn=(eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
      if(spawn)
      {
         int nd=eLong?1:eShort?-1:flipUp?1:-1;
         double hi=MathMax(m_lastP,m_prevP),lo=MathMin(m_lastP,m_prevP);
         m_dir=nd;m_ft=hi;m_fb=lo;m_p4h=hi;m_p4l=lo;m_cycH=h;m_cycL=l;m_inv=nd==1?lo:hi;
         double rng=(!f72_isna(m_prSH)&&!f72_isna(m_prSL))?MathAbs(m_prSH-m_prSL):m_atr*5.0;
         m_tgt=nd==1?f72_nz(hi,c)+rng:f72_nz(lo,c)-rng;
      }
      if(m_dir==1) m_cycH=f72_isna(m_cycH)?h:MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL=f72_isna(m_cycL)?l:MathMin(m_cycL,l);
      int bosOut=bullBOS?1:bearBOS?-1:0, chOut=bullCH?1:bearCH?-1:0;

      bool rst=(m_dir!=m_lastDirSeen); m_lastDirSeen=m_dir;
      if(rst){m_bos1=false;m_bos2=false;m_protSw=F72_NA;m_protSw2=F72_NA;m_indOrig=F72_NA;m_indExt=F72_NA;m_indBrk=false;}
      if(m_dir==1&&!f72_isna(pL)){m_protSw2=m_protSw;m_protSw=pL;}
      if(m_dir==-1&&!f72_isna(pH)){m_protSw2=m_protSw;m_protSw=pH;}
      bool oppBOS=(m_dir==1&&!f72_isna(m_protSw)&&c<m_protSw)||(m_dir==-1&&!f72_isna(m_protSw)&&c>m_protSw);
      if(!m_bos1&&oppBOS){m_bos1=true;m_indOrig=m_dir==1?f72_nz(m_cycH,h):f72_nz(m_cycL,l);}
      if(m_bos1&&!m_bos2&&oppBOS&&!f72_isna(m_protSw2)&&(m_dir==1?c<m_protSw2:c>m_protSw2)) m_bos2=true;
      if(m_bos1&&m_dir==1) m_indExt=f72_isna(m_indExt)?c:MathMin(m_indExt,c);
      if(m_bos1&&m_dir==-1) m_indExt=f72_isna(m_indExt)?c:MathMax(m_indExt,c);
      if(m_bos2&&!f72_isna(m_indOrig)){ if(m_dir==1&&c>m_indOrig)m_indBrk=true; if(m_dir==-1&&c<m_indOrig)m_indBrk=true; }
      double convScore=MathMin(MathAbs(csm)/MathMax(m_atr*m_convMult,1e-10)*50.0,100.0);
      double expScore=MathMin(eff/MathMax(m_effThresh,1e-10)*50.0+disp/MathMax(m_dispThresh,1e-10)*50.0,100.0);
      double absScore=(eff<m_effThresh*0.7&&MathAbs(vel)<MathAbs(m_prevVel)*0.6)?60.0+convScore*0.4:convScore*0.3;
      bool momExpStrong=eff>m_effThresh*0.75&&(m_dir==1?vel>0:vel<0);
      bool momDecaying=m_dir==1?bDec:rDec, momCounter=m_dir==1?rImp:bImp;
      bool momExhaust=eff<m_effThresh*0.65&&absScore>40.0;
      bool physConvexDevel=convScore>35.0, physTransfer=convScore>48.0||absScore>40.0, physCapacityLow=absScore>45.0||eff<m_effThresh*0.6;
      int wdir=!f72_isna(m_inv)?(c>m_inv?1:c<m_inv?-1:m_dir):m_dir;
      bool atFlip=!f72_isna(m_ft)&&!f72_isna(m_fb)&&c<=m_ft&&c>=m_fb;
      bool expanding=momExpStrong||eLong||eShort||(wdir==1?bImp:rImp);
      bool atExtreme=wdir==1?h>=f72_nz(m_cycH,h):wdir==-1?l<=f72_nz(m_cycL,l):false;
      double extr=wdir==1?f72_nz(m_cycH,c):f72_nz(m_cycL,c);
      bool extended=!f72_isna(m_inv)&&MathAbs(extr-m_inv)>m_atr*1.5;
      double fzMid=(!f72_isna(m_ft)&&!f72_isna(m_fb))?(m_ft+m_fb)/2.0:F72_NA;
      double retrFrac=(!f72_isna(fzMid)&&MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-c)/MathAbs(extr-fzMid):0.0;
      double compIdx=MathMin(100.0,MathMax(0.0,(1.0-MathMin(disp/MathMax(m_dispThresh,1e-10),1.0))*60.0+(1.0-MathMin(eff/MathMax(m_effThresh,1e-10),1.0))*40.0));
      bool phase2CH=(m_dir==1&&bearCH)||(m_dir==-1&&bullCH);
      if(rst||(atExtreme&&extended)){m_recBrk=0;m_recArm=true;}
      if((m_dir==1&&!f72_isna(pH))||(m_dir==-1&&!f72_isna(pL))) m_recArm=true;
      if((phase2CH||oppBOS)&&m_recArm&&!atExtreme){m_recBrk++;m_recArm=false;}
      double recDom=MathMin(100.0,MathMax(m_recBrk*(30.0-compIdx*0.15),retrFrac*80.0));
      bool transferDone=recDom>=50.0;
      if(rst) m_pst=0;
      if(m_dir!=0&&!rst)
      {
         if(m_pst==0&&expanding)m_pst=1;
         if(m_pst==1&&!atExtreme&&momDecaying&&physConvexDevel)m_pst=2;
         if(m_pst==2&&!atExtreme&&momCounter&&physTransfer)m_pst=3;
         if(m_pst==3&&!atExtreme&&(m_bos1||m_bos2||m_indBrk)&&physTransfer)m_pst=4;
         if(m_pst>=1&&m_pst<=7&&atExtreme&&extended)m_pst=5;
         if(m_pst==5&&!atExtreme&&(m_recBrk>=1||momExhaust))m_pst=7;
         if(m_pst==7&&transferDone)m_pst=8;
         if(m_pst==8&&atFlip)m_pst=9;
         if(m_pst==9&&((m_dir==1&&bImp)||(m_dir==-1&&rImp)))m_pst=10;
         if(m_pst==10&&(oppBOS||physCapacityLow))m_pst=11;
         if(m_pst==11&&((m_dir==1&&l<m_fb)||(m_dir==-1&&h>m_ft)))m_pst=12;
         if(m_pst==12&&((m_dir==1&&bullCH)||(m_dir==-1&&bearCH)))m_pst=13;
      }

      int phase=m_pst; if(phase==5&&m_dir==-1)phase=6; if(phase==13&&m_dir==-1)phase=14;
      double wp=m_pst==0?5.0:m_pst==1?15.0:m_pst==2?25.0:m_pst==3?33.0:m_pst==4?42.0:m_pst==5?55.0:m_pst==7?65.0:m_pst==8?75.0:m_pst==9?85.0:m_pst==10?90.0:m_pst==11?94.0:m_pst==12?97.0:100.0;
      double cm=MathMin(convScore,100.0);
      double mf=MathMin(MathMax(expScore,MathMax(absScore,convScore))*0.70+(m_dir!=0?30.0:0.0),100.0);
      double frzS=MathMin((eLong||eShort?50.0:0.0)+expScore*0.30+convScore*0.20,100.0);
      m_prevVel=vel;m_prevAcc=acc;m_prevConv=conv;m_prevConvSm=csm;
      out.dir=wdir;out.phase=phase;out.curSH=m_curSH;out.curSL=m_curSL;out.prSH=m_prSH;out.prSL=m_prSL;
      out.bos=bosOut;out.ch=chOut;out.p4h=m_p4h;out.p4l=m_p4l;out.inv=m_inv;out.tgt=m_tgt;out.ft=m_ft;out.fb=m_fb;
      out.frzS=frzS;out.wp=wp;out.cm=cm;out.mf=mf;out.compIdx=compIdx;out.recBrk=m_recBrk;out.recDom=recDom;
      out.atr=m_atr;out.vel=vel;out.acc=acc;out.convSmooth=csm;out.eff=eff;out.disp=disp;
      out.bullImp=bImp;out.bearImp=rImp;out.bullDec=bDec;out.bearDec=rDec;out.bullCS=bCS;out.bearCS=rCS;out.vd70=vd70;out.vd50=vd50;
   }
};

//============================== Engine1A ============================
class Engine1A
{
private:
   string m_sym; ENUM_TIMEFRAMES m_tf[6];
   StructureEngine *m_eng[6]; SE_Out m_out[6]; datetime m_lastBar[6];
   int dirByOrigin(const SE_Out &o)
   { double origin=o.inv;int fb=o.dir;double c=iClose(m_sym,m_tf[2],1);if(f72_isna(origin))return(fb);return(c>origin?1:c<origin?-1:fb); }
   void setL(ENUM_TIMEFRAMES a,ENUM_TIMEFRAMES b,ENUM_TIMEFRAMES c,ENUM_TIMEFRAMES d,ENUM_TIMEFRAMES e,ENUM_TIMEFRAMES f)
   { m_tf[0]=a;m_tf[1]=b;m_tf[2]=c;m_tf[3]=d;m_tf[4]=e;m_tf[5]=f; }
   void buildLadder(ENUM_TIMEFRAMES exec)
   {
      int s=PeriodSeconds(exec);
      if(s<3600) setL(PERIOD_M1,PERIOD_M3,exec,PERIOD_M15,PERIOD_H1,PERIOD_H4);
      else if(s<14400) setL(PERIOD_H1,PERIOD_H2,exec,PERIOD_H8,PERIOD_H12,PERIOD_D1);
      else if(s<86400) setL(PERIOD_H4,PERIOD_H8,exec,PERIOD_D1,PERIOD_D1,PERIOD_D1);
      else if(s<604800) setL(PERIOD_D1,PERIOD_D1,exec,PERIOD_W1,PERIOD_W1,PERIOD_MN1);
      else setL(PERIOD_W1,PERIOD_W1,exec,PERIOD_MN1,PERIOD_MN1,PERIOD_MN1);
   }
   void feedRung(int r)
   {
      int avail=Bars(m_sym,m_tf[r]); if(avail<3) return;
      datetime t1=iTime(m_sym,m_tf[r],1); if(t1==0) return;
      if(m_lastBar[r]==0)
      {
         int back=MathMin(avail-1,600);
         for(int i=back;i>=1;i--){ MqlRates rt[]; if(CopyRates(m_sym,m_tf[r],i,1,rt)==1) m_eng[r].ProcessNewBar(rt[0].open,rt[0].high,rt[0].low,rt[0].close,m_out[r]); }
         m_lastBar[r]=t1;
      }
      else if(t1>m_lastBar[r])
      {
         int shift=1; while(shift<avail&&iTime(m_sym,m_tf[r],shift)>m_lastBar[r]) shift++;
         for(int i=shift-1;i>=1;i--){ MqlRates rt[]; if(CopyRates(m_sym,m_tf[r],i,1,rt)==1) m_eng[r].ProcessNewBar(rt[0].open,rt[0].high,rt[0].low,rt[0].close,m_out[r]); }
         m_lastBar[r]=t1;
      }
   }

public:
   int fractalStackDir; double fractalStackScore; int ldir[6];
   Engine1A(){ for(int r=0;r<6;r++){ m_eng[r]=NULL; m_lastBar[r]=0; } }
   void Init(string sym,ENUM_TIMEFRAMES exec)
   {
      m_sym=sym; buildLadder(exec);
      for(int r=0;r<6;r++){ m_eng[r]=new StructureEngine; m_eng[r].Init(InpPivotLen,InpEffLen,InpAtrLen,InpEffThresh,InpDispThresh,InpConvMult,InpImpulseAtrMult,InpChochBufferATR); m_lastBar[r]=0; }
   }
   void Deinit(){ for(int r=0;r<6;r++) if(CheckPointer(m_eng[r])==POINTER_DYNAMIC) delete m_eng[r]; }
  ~Engine1A(){ Deinit(); }
   void Update()
   {
      for(int r=0;r<6;r++){ feedRung(r); ldir[r]=dirByOrigin(m_out[r]); }
      int sb=0,sr=0; for(int r=0;r<6;r++){ if(ldir[r]==1)sb++; else if(ldir[r]==-1)sr++; }
      fractalStackDir=sb>sr?1:sr>sb?-1:0; fractalStackScore=(double)MathMax(sb,sr)/6.0*100.0;
   }
   SE_Out Rung(int r){ return(m_out[r]); }
   SE_Out Canon(){ return(m_out[2]); }
   int CanonDir(){ return(ldir[2]); }
   string CurrentPhase(){ return(F72_PhaseName(m_out[2].phase)); }
   double PhaseConfidence(){ return(MathMax(20.0,MathMin(100.0,fractalStackScore*0.50+f72_nz(m_out[2].mf,0)*0.30+f72_nz(m_out[2].wp,0)*0.20))); }
   string HypFamily()
   {
      string p=CurrentPhase();
      if(p=="Expansion")return("EXPANSION");
      if(p=="Expansion Pre-Convexity"||p=="Expansion Induction")return("CONVEXITY FORMING");
      if(p=="New High"||p=="New Low")return("CREATION FORMING");
      if(p=="Retracement"||p=="HTF Flip Zone")return("RETRACEMENT");
      if(p=="Demand Return"||p=="Supply Return")return("DEMAND/SUPPLY RETURN");
      if(p=="Liquidation"||p=="Terminal Curve"||p=="Induction")return("ABSORPTION");
      return("EXPANSION");
   }
};

//============================== BrainState ==========================
struct BrainState
{
   double atr,velocity,acceleration,convSmooth,efficiency,displacement;
   bool   bullImpulse,bearImpulse,bullMomDecay,bearMomDecay,bullConvShift,bearConvShift,phys_vd70,phys_vd50;
   double convexityScore;
   string ie1a_currentPhase; double ie1a_phaseConfidence; string ie1a_hypFamily;
   int    fractalStackDir; double fractalStackScore; int waveDir,structBias;
   double obs_ExpansionScore,obs_DecayScore,obs_CurvatureScore,obs_AbsorptionScore,obs_LiquidityScore,physicsConsensus,physicsDiff;
   int    ede_state; double ede_expansionEnergy,ede_dissipatedEnergy,ede_dissipationProgress;
   bool   ede_messyPriceIsDissipation,ede_liquidationBecomingDirectional; double ede_deliverySpaceScore;
   int    re_expectedCycles,re_completedCycles; double re_recursiveCompletionScore,re_residualEnergy,re_residualEnergyScore;
   string re_resolutionState; bool re_nodeOpen,re_nodeClosed; double re_revisitProbability;
   double eae_primaryAttractorPrice,eae_secondaryAttractorPrice,eae_primaryAttractorScore,eae_secondaryAttractorScore; string eae_energyState;
   bool   erf_suppressRotation; double erf_confidence,erf_dissipationConfidence,erf_tradeReadiness; bool erf_entryGate;
   double liqHeat; bool liqVacuum,liqSweepBull,liqSweepBear,liqSweepOK;
   double originToExtreme,flipzoneWidth,availableSpace;
   int    direction,entryCycle,waveDepth; bool isRecursiveWave,recursiveComplete,recursiveJustFired;
   double flipTop,flipBot,point4OriginHigh,point4OriginLow,cycleHigh,cycleLow,inducZoneLow,inducZoneHigh; bool closeInside;
   double convexityMaturity,waveProgress,waveModelFit;
   double expansionBelief,convexityBelief,creationBelief,absorptionBelief,retracementBelief,demandReturnBelief;
   double sim_Expansion,sim_PreConv,sim_Induction,sim_Liquidity,sim_Creation,sim_Absorption,sim_Retracement,sim_DemandReturn;
   double modelConfidence,predReliability,waveDeviation; string expectedNextPhase; double expectedNextProb,die_entryScore; bool deviationAlert;
   int    frz_activeCount; double frz_bestScore; string frz_bestTier,frz_bestStatus; int frz_bestDir; double frz_bestTop,frz_bestBot,frz_distanceToZone;
   int    ownerDir,treeDepth; double life,chainVitality,wholeChainLife,cpForce,gCompress,gResidual; string cpState,narrState,chainScope,aliveVerdict; double narrative;
   int    timeDir; double timeAlign,timeConflict; string h1Timing;
   int    netBias,pdir,eligNodes; double netPressure,attractorScore;
   int    master; double alignment,conflict,threat,confidence,oppScore; string timing,intent,opportunity,action;
   string doe_bias,doe_action,doe_tradeType,doe_grade,doe_entryTrigger,doe_entryQuality; double doe_confidence,doe_entryMid,doe_entryHigh,doe_entryLow;
   double inv_activeStop,te_tp1,te_tp2,te_tp3;
   // --- V72 decision layer additions ---
   double rot_pressure,rot_controlStability,rot_transferProbability,rot_emergingWaveStrength; string rot_state;
   double mce_alignmentScore,mce_htfAlignmentScore,mce_mtfAlignmentScore,mce_execAlignmentScore; int mce_dir; string mce_htfNarrative,mce_execNarrative;
   string ne_dominantNarrative; double ne_narrativeStrength; bool ne_narrativeConflict;
   double tqe_rawScore,tqe_frzQuality,tqe_liqQuality; string tqe_grade,tqe_riskLevel; bool tqe_readiness;
   double te_tp1q,te_tp2q,te_tp3q,te_rr1,te_rr2,te_rr3; bool te_rrGate; string te_expectedPath;
   double inv_bullOrigin,inv_bearOrigin,inv_demandFail,inv_supplyFail,inv_riskPts,inv_riskATR; bool inv_invalidated;
   double frz_resolutionScore,frz_residualEnergy,frz_attractorWeight,frz_confidence; bool frz_attractorConvergence;
   double eae_tertiaryAttractorPrice,eae_tertiaryAttractorScore;
   int    wr_activeWaveId,wr_parentWaveId,wr_rootWaveId,wr_waveDepth,dwr_activeId;
   string trc_decisionSource,trc_waveChain,trc_confidenceBreakdown;
};

//============================== Observation =========================
void ComputeObservation(BrainState &S)
{
   double atr=S.atr,vel=S.velocity,acc=S.acceleration,csm=S.convSmooth,eff=S.efficiency,disp=S.displacement,effT=InpEffThresh,dispT=InpDispThresh;
   double velocityScore=MathMin(MathAbs(vel)/MathMax(atr*0.1,1e-10)*50.0,100.0);
   S.convexityScore=MathMin(MathAbs(csm)/MathMax(atr*InpConvMult,1e-10)*25.0,100.0);
   S.obs_ExpansionScore=MathMin((eff>effT?eff*60.0:eff*30.0)+(disp>dispT?(disp/MathMax(dispT,1e-10)-1.0)*20.0:0.0)+(((vel>0&&acc>0)||(vel<0&&acc<0))?velocityScore*0.2:0.0),100.0);
   S.obs_DecayScore=MathMin(((S.bullMomDecay||S.bearMomDecay)?40.0:0.0)+(S.convexityScore>30?S.convexityScore*0.5:0.0)+(S.phys_vd70?30.0:0.0),100.0);
   S.obs_CurvatureScore=S.convexityScore;
   S.obs_AbsorptionScore=MathMin((eff<effT*0.7?(1.0-eff/MathMax(effT,1e-10))*50.0:0.0)+(S.phys_vd50?30.0:0.0)+(disp<dispT*0.5?20.0:0.0),100.0);
   S.obs_LiquidityScore=MathMin(S.obs_DecayScore*0.4+S.obs_CurvatureScore*0.4+(disp>dispT*1.2&&(S.bullMomDecay||S.bearMomDecay)?20.0:0.0),100.0);
   double pmax=MathMax(S.obs_ExpansionScore,MathMax(S.obs_DecayScore,MathMax(S.obs_AbsorptionScore,S.obs_LiquidityScore)));
   double pmin=MathMin(S.obs_ExpansionScore,MathMin(S.obs_DecayScore,MathMin(S.obs_AbsorptionScore,S.obs_LiquidityScore)));
   S.physicsDiff=pmax-pmin; S.physicsConsensus=MathMax(0.0,100.0-S.physicsDiff);
}

//============================== Energy (EDE/RE/EAE/ERF) =============
void ComputeEnergy(BrainState &S,double close)
{
   string p=S.ie1a_currentPhase; double eff=S.efficiency,effT=InpEffThresh;
   S.ede_state=(p=="Point 4 Origin"||p=="Expansion")?1:(p=="Expansion Pre-Convexity")?2:(p=="Expansion Induction")?3:(p=="Expansion Liquidity")?4:(p=="New High"||p=="New Low")?5:6;
   S.ede_expansionEnergy=MathMin(S.obs_ExpansionScore*0.50+((S.bullImpulse||S.bearImpulse)?30.0:0.0)+eff*20.0,100.0);
   S.ede_dissipatedEnergy=MathMin((S.ede_state>=2?S.obs_DecayScore*0.40:0.0)+(S.ede_state>=3?S.obs_CurvatureScore*0.30:0.0)+(S.ede_state>=4?S.obs_LiquidityScore*0.30:0.0),100.0);
   S.ede_dissipationProgress=MathMin((S.ede_state>=2?25.0:0.0)+(S.ede_state>=3?25.0:0.0)+(S.ede_state>=4?25.0:0.0)+(S.ede_state>=5?25.0:0.0),100.0);
   S.ede_liquidationBecomingDirectional=(S.ede_state==4&&(S.bullImpulse||S.bearImpulse)&&eff>effT*0.8);
   S.ede_deliverySpaceScore=MathMin(MathMax(0.0,100.0-S.convexityMaturity),100.0);
   S.ede_messyPriceIsDissipation=(S.ede_state>=2&&S.ede_state<=4)&&S.obs_DecayScore>30.0&&eff<effT*0.9&&!(S.bullImpulse||S.bearImpulse);
   S.re_expectedCycles=MathMax(1,MathMin(S.waveDepth+2,4));
   S.re_completedCycles=MathMax(0,MathMin(S.entryCycle,S.re_expectedCycles));
   S.re_recursiveCompletionScore=S.re_expectedCycles>0?MathMin((double)S.re_completedCycles/(double)S.re_expectedCycles*100.0,100.0):0.0;
   S.re_residualEnergy=MathMax(0.0,S.ede_expansionEnergy-S.ede_dissipatedEnergy);
   bool objReached=S.ede_state>=5,fullDiss=S.ede_dissipationProgress>=75.0;
   bool absRet=(p=="Demand Return"||p=="Supply Return")&&S.recursiveComplete;
   S.re_resolutionState=(absRet&&fullDiss&&S.re_recursiveCompletionScore>=75.0)?"RESOLVED":(objReached&&S.ede_dissipationProgress>=50.0)?"PARTIALLY RESOLVED":"UNRESOLVED";
   S.re_residualEnergyScore=MathMin(S.re_residualEnergy,100.0);
   S.re_nodeOpen=(S.re_resolutionState=="UNRESOLVED"||S.re_resolutionState=="PARTIALLY RESOLVED"); S.re_nodeClosed=(S.re_resolutionState=="RESOLVED");
   S.re_revisitProbability=S.re_resolutionState=="UNRESOLVED"?MathMin(S.re_residualEnergyScore*0.90,95.0):S.re_resolutionState=="PARTIALLY RESOLVED"?MathMin(S.re_residualEnergyScore*0.60,75.0):MathMin(S.re_residualEnergyScore*0.20,25.0);
   double a2=S.atr*2.0;
   S.eae_primaryAttractorPrice=S.direction==0?F72_NA:S.re_resolutionState=="UNRESOLVED"?(S.direction==1?f72_nz(S.flipBot,close-a2):f72_nz(S.flipTop,close+a2)):S.re_resolutionState=="PARTIALLY RESOLVED"?(S.direction==1?f72_nz(S.point4OriginLow,close-S.atr):f72_nz(S.point4OriginHigh,close+S.atr)):F72_NA;
   S.eae_secondaryAttractorPrice=(S.direction!=0&&S.re_resolutionState=="UNRESOLVED"&&!f72_isna(S.inducZoneLow)&&!f72_isna(S.inducZoneHigh))?(S.direction==1?S.inducZoneLow:S.inducZoneHigh):F72_NA;
   S.eae_primaryAttractorScore=MathMin(S.re_residualEnergyScore*0.40+(S.re_resolutionState=="UNRESOLVED"?30.0:S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:5.0)+(!f72_isna(S.eae_primaryAttractorPrice)?MathMax(0.0,30.0-MathAbs(close-S.eae_primaryAttractorPrice)/MathMax(S.atr,1e-10)*5.0):0.0),100.0);
   S.eae_secondaryAttractorScore=MathMin(S.re_residualEnergyScore*0.25+(S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:10.0)+(!f72_isna(S.eae_secondaryAttractorPrice)?MathMax(0.0,20.0-MathAbs(close-S.eae_secondaryAttractorPrice)/MathMax(S.atr,1e-10)*4.0):0.0),100.0);
   S.eae_energyState=S.ede_state==1?"Accumulating":(S.ede_state>=2&&S.ede_state<=4)?"Cleaning":S.ede_state==5?"Delivering":S.re_resolutionState=="RESOLVED"?"Exhausted":"Resolving";
   S.erf_suppressRotation=S.ede_messyPriceIsDissipation&&S.ede_state>=2&&S.ede_state<=4;
   S.erf_confidence=MathMin((S.eae_energyState!="Accumulating"?S.ie1a_phaseConfidence*0.40:20.0)+(S.re_resolutionState=="RESOLVED"?30.0:S.re_resolutionState=="PARTIALLY RESOLVED"?20.0:10.0)+S.eae_primaryAttractorScore*0.30,100.0);
   S.erf_dissipationConfidence=MathMin((S.ede_messyPriceIsDissipation?50.0:0.0)+S.ede_dissipationProgress*0.50,100.0);
   S.erf_tradeReadiness=MathMin((S.re_resolutionState=="RESOLVED"?40.0:S.re_resolutionState=="PARTIALLY RESOLVED"?25.0:10.0)+S.re_recursiveCompletionScore*InpErfReadyResW+(100.0-S.re_residualEnergyScore)*InpErfReadyResidW+S.erf_confidence*InpErfReadyConfW,100.0);
   S.erf_entryGate=(!InpErfGateEnabled)||(S.erf_tradeReadiness>=InpErfEntryThresh);
}

//============================== LiquidityEngine =====================
class LiquidityEngine
{
private:
   double m_lvl[],m_wt[]; int m_age[]; int m_n;
   double m_h[],m_l[],m_c[],m_vol[]; int m_nb; int m_pvLen;
   double getH(int b){return(b<m_nb?m_h[b]:F72_NA);} double getL(int b){return(b<m_nb?m_l[b]:F72_NA);}
   double pivotHigh(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_h[L];for(int i=1;i<=L;i++)if(m_h[L-i]>=m||m_h[L+i]>=m)return(F72_NA);return(m);}
   double pivotLow(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_l[L];for(int i=1;i<=L;i++)if(m_l[L-i]<=m||m_l[L+i]<=m)return(F72_NA);return(m);}
public:
   double liqHeat; bool liqVacuum;
   void Init(){ m_pvLen=InpPivotLen;m_n=0;m_nb=0;liqHeat=0;liqVacuum=false;ArrayResize(m_lvl,0);ArrayResize(m_wt,0);ArrayResize(m_age,0);ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0);ArrayResize(m_vol,0); }
   void pushBar(double h,double l,double c,double v)
   { int keep=MathMax(2*m_pvLen+5,40);
     ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);ArrayResize(m_vol,m_nb+1);
     for(int i=m_nb;i>0;i--){m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];m_vol[i]=m_vol[i-1];}
     m_h[0]=h;m_l[0]=l;m_c[0]=c;m_vol[0]=v;m_nb++;
     if(m_nb>keep){ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);ArrayResize(m_vol,keep);m_nb=keep;} }
   void Update(BrainState &S,double h,double l,double c,double v,double volAvg,int barIndex)
   {
      pushBar(h,l,c,v); double atr=S.atr; double pH=pivotHigh(),pL=pivotLow();
      double volAtPiv=(m_pvLen<m_nb)?m_vol[m_pvLen]:v; double normVol=volAvg>0?volAtPiv/volAvg:1.0;
      if(!f72_isna(pH)||!f72_isna(pL))
      {
         double lvl=!f72_isna(pH)?pH:pL; double swRng=(getH(m_pvLen)-getL(m_pvLen))/MathMax(atr,1e-10);
         int sz=m_n;ArrayResize(m_lvl,sz+1);ArrayResize(m_wt,sz+1);ArrayResize(m_age,sz+1);
         m_lvl[sz]=lvl;m_wt[sz]=normVol*swRng;m_age[sz]=barIndex-m_pvLen;m_n++;
         if(m_n>150){for(int i=0;i<m_n-1;i++){m_lvl[i]=m_lvl[i+1];m_wt[i]=m_wt[i+1];m_age[i]=m_age[i+1];}m_n--;ArrayResize(m_lvl,m_n);ArrayResize(m_wt,m_n);ArrayResize(m_age,m_n);}
      }
      double wD=0,wA=0,wB=0,rP=atr*InpLiqRadius,rW=atr*InpLiqRadius*3.0;
      for(int i=0;i<m_n;i++){ int age=barIndex-m_age[i]; double dcy=MathPow(InpLiqAgDecay,age); double dist=MathAbs(c-m_lvl[i]);
         if(dist<rP)wD+=m_wt[i]*dcy; if(dist<rW){ if(m_lvl[i]>c)wA+=m_wt[i]*dcy*(1.0-dist/rW); else wB+=m_wt[i]*dcy*(1.0-dist/rW); } }
      double raw=MathMin((wA+wB)/2.0,5.0)/5.0*100.0; liqHeat=MathMin(MathMax(raw,0.0),100.0); S.liqHeat=liqHeat;
      liqVacuum=(wD<0.5); S.liqVacuum=liqVacuum;
      double swH=-DBL_MAX,swL=DBL_MAX; for(int i=0;i<InpLiqSweepLook&&i<m_nb;i++){swH=MathMax(swH,m_h[i]);swL=MathMin(swL,m_l[i]);}
      S.liqSweepBull=!f72_isna(S.flipTop)&&swH>S.flipTop; S.liqSweepBear=!f72_isna(S.flipBot)&&swL<S.flipBot;
      S.liqSweepOK=(!InpRequireLiqSweep)||(S.direction==1&&(S.liqSweepBull||liqVacuum))||(S.direction==-1&&(S.liqSweepBear||liqVacuum));
   }
};

//============================== WaveIntelEngine =====================
class WaveIntelEngine
{
private:
   double m_convMat,m_waveProg,m_exp,m_conv,m_creat,m_abs,m_retr,m_dr; double m_velHist[3];
   double idealSim(double e,double d,double v,double cu,double ie,double id,double iv,double ic)
   { double diff=MathPow(e-ie,2)+MathPow(d-id,2)+MathPow(v-iv,2)+MathPow(cu-ic,2); return(MathMax(0.0,100.0*(1.0-diff/4.0))); }
public:
   void Init(){ m_convMat=0;m_waveProg=30.0;m_exp=0;m_conv=0;m_creat=0;m_abs=0;m_retr=0;m_dr=0;ArrayInitialize(m_velHist,0); }
   double ConvexityMaturity(){ return(m_convMat); }
   void Update(BrainState &S,double close)
   {
      double atr=S.atr,eff=S.efficiency,disp=S.displacement,vel=S.velocity,csm=S.convSmooth,effT=InpEffThresh,dispT=InpDispThresh;
      double eN=MathMin(eff,1.0),dN=MathMin(disp/MathMax(dispT*2.0,1e-10),1.0),vN=MathMin(MathAbs(vel)/MathMax(atr*0.15,1e-10),1.0),cN=MathMin(MathAbs(csm)/MathMax(atr*InpConvMult*2.0,1e-10),1.0);
      S.sim_Expansion=idealSim(eN,dN,vN,cN,0.85,0.80,0.80,0.10); S.sim_PreConv=idealSim(eN,dN,vN,cN,0.60,0.55,0.40,0.50);
      S.sim_Induction=idealSim(eN,dN,vN,cN,0.65,0.60,0.30,0.60); S.sim_Liquidity=idealSim(eN,dN,vN,cN,0.45,0.85,0.15,0.80);
      S.sim_Creation=idealSim(eN,dN,vN,cN,0.30,0.70,0.05,0.90); S.sim_Absorption=idealSim(eN,dN,vN,cN,0.20,0.25,0.10,0.40);
      S.sim_Retracement=idealSim(eN,dN,vN,cN,0.70,0.65,0.65,0.25); S.sim_DemandReturn=idealSim(eN,dN,vN,cN,0.50,0.40,0.35,0.20);
      double waveTotalRange=!f72_isna(S.originToExtreme)?S.originToExtreme:atr*5.0;
      double currentToExtreme=S.direction==1?MathAbs(f72_nz(S.cycleHigh,close+atr)-close):MathAbs(close-f72_nz(S.cycleLow,close-atr));
      double posNormDen=MathMax(waveTotalRange,atr*0.5); double posDistToCreation=MathMin(currentToExtreme/posNormDen*100.0,100.0);
      double v2=m_velHist[2];
      double expWeak=MathMin(((eff<effT?(1.0-eff/MathMax(effT,1e-10))*40.0:0.0)+(S.obs_DecayScore*0.30)+(MathAbs(vel)<MathAbs(v2)*0.6?20.0:0.0))*(100.0/90.0),100.0);
      double inducMat=MathMin(((S.ie1a_currentPhase=="Induction"||S.ie1a_currentPhase=="Expansion Induction")?35.0:0.0)+(S.obs_CurvatureScore*0.35)+((S.ie1a_currentPhase=="Expansion Pre-Convexity")?20.0:0.0)+((disp>dispT*1.2&&(S.bullMomDecay||S.bearMomDecay))?10.0:0.0),100.0);
      double liqMat=MathMin((S.obs_LiquidityScore*0.50)+((S.liqSweepBull||S.liqSweepBear)?30.0:0.0)+(S.liqHeat>60?20.0:S.liqHeat>30?10.0:0.0),100.0);
      double rawConvMat=MathMin(expWeak*0.35+inducMat*0.35+liqMat*0.30,100.0);
      double alpha=2.0/(InpBeliefSmooth+1); m_convMat=m_convMat+alpha*(rawConvMat-m_convMat); S.convexityMaturity=m_convMat;
      double geomProg=30.0;
      if(!f72_isna(S.point4OriginHigh)&&!f72_isna(S.flipTop)&&!f72_isna(S.flipBot))
      {
         double origin=S.direction==1?S.point4OriginLow:S.point4OriginHigh;
         double extreme=S.direction==1?f72_nz(S.cycleHigh,close+atr):f72_nz(S.cycleLow,close-atr);
         double fzMid=(S.flipTop+S.flipBot)/2.0; double totalMove=MathAbs(extreme-origin),toFz=MathAbs(extreme-fzMid);
         double expProg=totalMove>1e-10?MathMin(MathAbs(close-origin)/totalMove*60.0,60.0):30.0;
         double retrMove=MathAbs(close-extreme); double retrProg=toFz>1e-10?MathMin(retrMove/MathMax(toFz,1e-10)*40.0,40.0):0.0;
         geomProg=expProg+retrProg*MathMin(S.obs_AbsorptionScore/40.0,1.0);
      }
      double simAnchor=(S.sim_DemandReturn>=S.sim_Retracement&&S.sim_DemandReturn>=S.sim_Absorption&&S.sim_DemandReturn>=S.sim_Creation&&S.sim_DemandReturn>=S.sim_Expansion)?95.0:(S.sim_Retracement>=S.sim_Absorption&&S.sim_Retracement>=S.sim_Creation&&S.sim_Retracement>=S.sim_Expansion)?87.0:(S.sim_Absorption>=S.sim_Creation&&S.sim_Absorption>=S.sim_Expansion)?75.0:(S.sim_Creation>=S.sim_Liquidity&&S.sim_Creation>=S.sim_Expansion)?62.0:(S.sim_Liquidity>=S.sim_Induction&&S.sim_Liquidity>=S.sim_Expansion)?52.0:(S.sim_Induction>=S.sim_PreConv&&S.sim_Induction>=S.sim_Expansion)?43.0:(S.sim_PreConv>=S.sim_Expansion)?33.0:22.0;
      double convW=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5); double physProg=simAnchor+(m_convMat/100.0)*(simAnchor-33.0)*0.50*convW;
      double rawWP=geomProg*0.60+physProg*0.40; m_waveProg=m_waveProg+alpha*(rawWP-m_waveProg); S.waveProgress=m_waveProg; S.waveModelFit=S.ie1a_phaseConfidence;
      bool impulse=S.bullImpulse||S.bearImpulse; double expMult=(m_waveProg<40.0)?1.30:0.70;
      double rawExp=MathMin((S.obs_ExpansionScore*0.45+(impulse?30.0:0.0)+(eff>effT*1.1?15.0:0.0)+S.sim_Expansion*0.10)*expMult,100.0);
      double convPosMult=(m_waveProg>=30.0&&m_waveProg<=65.0)?1.30:0.70;
      double rawConv=MathMin((S.obs_DecayScore*0.30+S.obs_CurvatureScore*0.25+S.convexityMaturity*0.08)*convPosMult,100.0);
      double creatMult=(m_waveProg>=45.0&&m_waveProg<=68.0)?1.40:0.60;
      double rawCreat=MathMin(((S.convexityMaturity>50?S.convexityMaturity*0.12:0.0)+(S.obs_DecayScore>60?S.obs_DecayScore*0.20:0.0)+(S.obs_LiquidityScore>50?S.obs_LiquidityScore*0.20:0.0)+(S.obs_AbsorptionScore>20?S.obs_AbsorptionScore*0.15:0.0)+S.sim_Creation*0.10+(posDistToCreation<15.0?(15.0-posDistToCreation)*1.0:0.0))*creatMult,100.0);
      double rawAbs=MathMin(S.obs_AbsorptionScore*0.50+(eff<effT*0.6?25.0:0.0)+(disp<dispT*0.5?15.0:0.0)+S.sim_Absorption*0.10,100.0);
      double rawRetr=MathMin(((S.direction==1&&S.bearImpulse)||(S.direction==-1&&S.bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(S.obs_CurvatureScore>40?15.0:0.0)+S.sim_Retracement*0.10,100.0);
      double rawDR=MathMin((!f72_isna(S.flipTop)&&!f72_isna(S.flipBot)&&close<=S.flipTop&&close>=S.flipBot?35.0:0.0)+(rawRetr>60?rawRetr*0.30:0.0)+(S.liqHeat>50?S.liqHeat*0.15:0.0)+((S.liqSweepBull||S.liqSweepBear)?20.0:0.0)+S.sim_DemandReturn*0.10,100.0);
      m_exp+=alpha*(rawExp-m_exp);m_conv+=alpha*(rawConv-m_conv);m_creat+=alpha*(rawCreat-m_creat);m_abs+=alpha*(rawAbs-m_abs);m_retr+=alpha*(rawRetr-m_retr);m_dr+=alpha*(rawDR-m_dr);
      S.expansionBelief=m_exp;S.convexityBelief=m_conv;S.creationBelief=m_creat;S.absorptionBelief=m_abs;S.retracementBelief=m_retr;S.demandReturnBelief=m_dr;
      m_velHist[2]=m_velHist[1];m_velHist[1]=m_velHist[0];m_velHist[0]=vel;
   }
};

//============================== SpawnEngine =========================
class SpawnEngine
{
private:
   int    m_dir,m_entryCycle,m_waveDepth,m_lastSpawnDir,m_waveGen; bool m_isRecursive,m_recursiveComplete;
   double m_flipTop,m_flipBot,m_p4h,m_p4l,m_cycH,m_cycL,m_fzIP,m_fzL,m_fzH;
   int    m_obBirthBar,m_contBar,m_p4Bar,m_recursiveFiredBar;
   double m_h[],m_l[],m_c[]; int m_nb,m_pvLen;
   double m_lastP,m_prevP; int m_lastD,m_prevD,m_lastPBar,m_prevPBar,m_barIndex;
   double gH(int b){return(b<m_nb?m_h[b]:F72_NA);} double gL(int b){return(b<m_nb?m_l[b]:F72_NA);}
   double pivotHigh(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_h[L];for(int i=1;i<=L;i++)if(m_h[L-i]>=m||m_h[L+i]>=m)return(F72_NA);return(m);}
   double pivotLow(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_l[L];for(int i=1;i<=L;i++)if(m_l[L-i]<=m||m_l[L+i]<=m)return(F72_NA);return(m);}
   double findInducPrice(int anchorRef,double top,double bot,int lookback)
   { double best=F72_NA,bd=F72_NA;int maxI=MathMin(lookback,m_barIndex-anchorRef);
     if(maxI>=1) for(int i=1;i<=maxI&&i<m_nb;i++) if(m_h[i]<top&&m_l[i]>bot){double d=MathAbs((m_barIndex-i)-anchorRef);if(f72_isna(bd)||d<bd){bd=d;best=(m_h[i]+m_l[i])/2.0;}} return(best); }
   void spawnAt(int nd,double atr)
   { double top=nd==1?m_lastP:m_prevP,bot=nd==1?m_prevP:m_lastP;int anch=m_prevPBar;
     double fzIP=findInducPrice(anch,MathMax(top,bot),MathMin(top,bot),InpInducLookback);
     m_dir=nd;m_flipTop=top;m_flipBot=bot;m_p4h=top;m_p4l=bot;m_p4Bar=m_barIndex;m_obBirthBar=m_barIndex;m_contBar=-1;
     m_fzIP=fzIP;m_fzL=!f72_isna(fzIP)?fzIP-atr*InpInducZoneWidth:F72_NA;m_fzH=!f72_isna(fzIP)?fzIP+atr*InpInducZoneWidth:F72_NA; }
public:
   void Init(){ m_dir=0;m_entryCycle=0;m_waveDepth=0;m_lastSpawnDir=0;m_waveGen=0;m_isRecursive=false;m_recursiveComplete=false;
      m_flipTop=F72_NA;m_flipBot=F72_NA;m_p4h=F72_NA;m_p4l=F72_NA;m_cycH=F72_NA;m_cycL=F72_NA;m_fzIP=F72_NA;m_fzL=F72_NA;m_fzH=F72_NA;
      m_obBirthBar=-1;m_contBar=-1;m_p4Bar=-1;m_recursiveFiredBar=-100000;m_nb=0;m_pvLen=InpPivotLen;m_lastP=F72_NA;m_prevP=F72_NA;m_lastD=0;m_prevD=0;m_lastPBar=-1;m_prevPBar=-1;m_barIndex=0;
      ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0); }
   void pushBar(double h,double l,double c){ int keep=MathMax(InpInducLookback+5,2*m_pvLen+5);
      ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);
      for(int i=m_nb;i>0;i--){m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];}
      m_h[0]=h;m_l[0]=l;m_c[0]=c;m_nb++;
      if(m_nb>keep){ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);m_nb=keep;} m_barIndex++; }
   void Update(BrainState &S,double o,double h,double l,double c,int l0dir,double l0p4h,double l0p4l,bool bullCH,bool bearCH)
   {
      pushBar(h,l,c); double atr=S.atr; bool recJustFired=false;
      double pH=pivotHigh(),pL=pivotLow(); double eP=F72_NA;int eD=0;int eBar=m_barIndex-m_pvLen;
      if(!f72_isna(pH)){eP=pH;eD=1;} else if(!f72_isna(pL)){eP=pL;eD=-1;}
      if(eD!=0){m_prevP=m_lastP;m_prevPBar=m_lastPBar;m_prevD=m_lastD;m_lastP=eP;m_lastPBar=eBar;m_lastD=eD;}
      bool allowSpawn=l0dir!=0&&l0dir!=m_dir&&!f72_isna(m_lastP)&&!f72_isna(m_prevP);
      if(allowSpawn){ spawnAt(l0dir,atr); if(!f72_isna(l0p4h)){m_flipTop=l0p4h;m_p4h=l0p4h;} if(!f72_isna(l0p4l)){m_flipBot=l0p4l;m_p4l=l0p4l;} m_lastSpawnDir=l0dir;m_cycH=h;m_cycL=l;m_isRecursive=false;m_entryCycle=0;m_waveDepth=0; }
      if(m_dir==1) m_cycH=f72_isna(m_cycH)?h:MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL=f72_isna(m_cycL)?l:MathMin(m_cycL,l);
      bool closeInside=!f72_isna(m_flipTop)&&c<=m_flipTop&&c>=m_flipBot;
      bool priceInDemand=!f72_isna(m_flipBot)&&l<m_flipBot&&(!f72_isna(m_p4h)&&l<=m_p4h);
      bool priceInSupply=!f72_isna(m_flipTop)&&h>m_flipTop&&(!f72_isna(m_p4l)&&h>=m_p4l);
      bool trueChBull=m_dir==1&&priceInDemand&&S.bullImpulse&&S.liqSweepOK;
      bool trueChBear=m_dir==-1&&priceInSupply&&S.bearImpulse&&S.liqSweepOK;
      bool structFlipBull=m_dir==1&&S.bullConvShift&&S.structBias==-1;
      bool structFlipBear=m_dir==-1&&S.bearConvShift&&S.structBias==1;
      string p=S.ie1a_currentPhase;
      bool recursiveTrigger=(trueChBull||trueChBear||structFlipBull||structFlipBear)&&(p=="Demand Return"||p=="Supply Return")&&S.demandReturnBelief>40&&m_dir!=0&&!f72_isna(m_flipTop);
      if(recursiveTrigger&&(m_barIndex-m_recursiveFiredBar)>InpResetBars)
      { recJustFired=true;m_recursiveFiredBar=m_barIndex;m_recursiveComplete=true;m_waveGen++;m_entryCycle=MathMin(m_entryCycle+1,4);m_isRecursive=true;m_waveDepth=m_entryCycle;
        int nextDir=l0dir!=0?l0dir:((S.bullImpulse||S.bullConvShift)?1:-1); spawnAt(nextDir,atr);m_lastSpawnDir=nextDir;m_dir=l0dir!=0?l0dir:nextDir;m_cycH=h;m_cycL=l;m_contBar=m_barIndex; }
      bool bullInvalid=m_dir==1&&c<m_flipBot-atr*0.5, bearInvalid=m_dir==-1&&c>m_flipTop+atr*0.5;
      bool opposingMove=(m_dir==1&&S.bearImpulse)||(m_dir==-1&&S.bullImpulse);
      int barsSinceCont=m_contBar>=0?m_barIndex-m_contBar:(m_obBirthBar>=0?m_barIndex-m_obBirthBar:0);
      bool hardInvalid=bullInvalid||bearInvalid;
      bool softReset=barsSinceCont>InpResetBars&&opposingMove&&(p!="Demand Return"&&p!="Supply Return")&&S.demandReturnBelief<30&&S.expansionBelief<30&&!S.erf_suppressRotation;
      if(m_dir!=l0dir&&(hardInvalid||softReset)){ m_dir=0;m_lastSpawnDir=0;m_flipTop=F72_NA;m_flipBot=F72_NA;m_contBar=-1;m_obBirthBar=-1;m_isRecursive=false;m_entryCycle=0;m_waveDepth=0;m_recursiveComplete=false; }
      S.direction=m_dir;S.entryCycle=m_entryCycle;S.waveDepth=m_waveDepth;S.isRecursiveWave=m_isRecursive;S.recursiveComplete=m_recursiveComplete;S.recursiveJustFired=recJustFired;
      S.flipTop=m_flipTop;S.flipBot=m_flipBot;S.point4OriginHigh=m_p4h;S.point4OriginLow=m_p4l;S.cycleHigh=m_cycH;S.cycleLow=m_cycL;S.inducZoneLow=m_fzL;S.inducZoneHigh=m_fzH;S.closeInside=closeInside;
      if(!f72_isna(m_p4h)&&!f72_isna(m_p4l)){double org=m_dir==1?m_p4l:m_p4h;double ext=m_dir==1?f72_nz(m_cycH,org):f72_nz(m_cycL,org);S.originToExtreme=MathAbs(ext-org);} else S.originToExtreme=F72_NA;
      S.flipzoneWidth=(!f72_isna(m_flipTop)&&!f72_isna(m_flipBot))?m_flipTop-m_flipBot:F72_NA;
      if(!f72_isna(m_flipTop)&&!f72_isna(m_flipBot)){double fzMid=(m_flipTop+m_flipBot)/2.0;S.availableSpace=MathMin(MathAbs(c-fzMid)/MathMax(atr*4.0,1e-10)*100.0,100.0);} else S.availableSpace=F72_NA;
   }
};

//============================== DIEEngine ===========================
class DIEEngine
{
private:
   double m_modelConfidence; int m_predOutcomes[100]; int m_predTotalIdx; string m_lastExpected,m_lastPhase;
public:
   int flipzoneStagesComplete; string grade;
   void Init(){ m_modelConfidence=50.0;m_predTotalIdx=0;ArrayInitialize(m_predOutcomes,0);m_lastExpected="Point 4 Origin";m_lastPhase="Point 4 Origin";flipzoneStagesComplete=0;grade="D"; }
   double predAcc(int n){ int cnt=MathMin(n,m_predTotalIdx);if(cnt<=0)return(50.0);int sum=0,start=MathMax(0,m_predTotalIdx-cnt);for(int i=start;i<m_predTotalIdx;i++)sum+=m_predOutcomes[i%100];return((double)sum/(double)cnt*100.0); }
   void Update(BrainState &S,double close,int htfAlign,int dir_tf1,int dir_tf2,bool m1ExpWeak,bool m1ConvEmer,bool m1IndEmer,bool m1LiqEmer,bool m1AbsEmer,bool dirFUactive)
   {
      double wp=S.waveProgress,cm=S.convexityMaturity;
      double posDistToCreation=MathMin((S.direction==1?MathAbs(f72_nz(S.cycleHigh,close)-close):MathAbs(close-f72_nz(S.cycleLow,close)))/MathMax(f72_nz(S.originToExtreme,S.atr*5.0),S.atr*0.5)*100.0,100.0);
      double posDistToDemand=!f72_isna(S.flipTop)&&!f72_isna(S.flipBot)?MathMin(MathAbs(close-(S.flipTop+S.flipBot)/2.0)/MathMax(S.atr*4.0,1e-10)*100.0,100.0):100.0;
      bool preConvSeen=S.closeInside&&(S.bullMomDecay||S.bearMomDecay);
      bool inductionConf=(S.ie1a_currentPhase=="Induction"||S.ie1a_currentPhase=="Expansion Induction");
      flipzoneStagesComplete=(S.demandReturnBelief>75&&S.recursiveComplete)?5:S.demandReturnBelief>60?4:S.retracementBelief>55?3:inductionConf?2:preConvSeen?1:0;
      double effT=InpEffThresh;
      double predExp=(wp<35.0?(35.0-wp)*1.0:0.0)+(S.expansionBelief>55?S.expansionBelief*0.30:0.0)+(cm<25?20.0:0.0)+(posDistToCreation>30?15.0:0.0)+(htfAlign==S.direction&&S.direction!=0?15.0:0.0);
      double predConv=(wp>=25.0&&wp<=60.0?30.0:0.0)+(cm>20?cm*0.30:0.0)+(S.obs_DecayScore>40?20.0:0.0)+(m1ConvEmer?15.0:0.0)+(preConvSeen?15.0:0.0);
      double predCreat=(cm>55?(cm-55.0)*1.20:0.0)+(posDistToCreation<20.0?(20.0-posDistToCreation)*2.0:0.0)+(S.obs_LiquidityScore>55?20.0:0.0)+((S.liqSweepBull||S.liqSweepBear)?15.0:0.0)+(m1LiqEmer?10.0:0.0);
      double predAbs=(predCreat>50?predCreat*0.40:0.0)+(S.obs_AbsorptionScore>35?S.obs_AbsorptionScore*0.30:0.0)+(m1AbsEmer?20.0:0.0)+(wp>=60.0&&wp<=78.0?15.0:0.0);
      double predRetr=(S.absorptionBelief>45?S.absorptionBelief*0.35:0.0)+(((S.direction==1&&S.bearImpulse)||(S.direction==-1&&S.bullImpulse))?25.0:0.0)+(wp>=72.0&&wp<=90.0?20.0:0.0)+(S.physicsConsensus<40?10.0:0.0);
      double predDR=(S.retracementBelief>45?S.retracementBelief*0.35:0.0)+(posDistToDemand<20.0?(20.0-posDistToDemand)*1.50:0.0)+((S.liqSweepBull||S.liqSweepBear)?20.0:0.0)+(wp>=88.0?(wp-88.0)*1.20:0.0);
      double mx=MathMax(predExp,MathMax(predConv,MathMax(predCreat,MathMax(predAbs,MathMax(predRetr,predDR)))));
      S.expectedNextPhase=(predDR>=predRetr&&predDR>=predAbs&&predDR>=predCreat&&predDR>=predConv&&predDR>=predExp)?(S.direction==-1?"Supply Return":"Demand Return"):(predRetr>=predAbs&&predRetr>=predCreat&&predRetr>=predConv&&predRetr>=predExp)?"Retracement":(predAbs>=predCreat&&predAbs>=predConv&&predAbs>=predExp)?"Absorption":(predCreat>=predConv&&predCreat>=predExp)?(S.direction==-1?"New Low":"New High"):(predConv>=predExp)?"Expansion Pre-Convexity":"Expansion";
      S.expectedNextProb=mx>0?MathMin(mx/MathMax(mx+30.0,1.0)*100.0,95.0):50.0;
      bool predTransition=(S.ie1a_currentPhase!=m_lastPhase); bool predSucceeded=predTransition&&(S.ie1a_currentPhase==m_lastExpected);
      if(predTransition){m_predOutcomes[m_predTotalIdx%100]=predSucceeded?1:0;m_predTotalIdx++;}
      m_lastExpected=S.expectedNextPhase;m_lastPhase=S.ie1a_currentPhase;
      double a10=predAcc(10),a25=predAcc(25),a50=predAcc(50),a100=predAcc(100); S.predReliability=a10*0.4+a25*0.3+a50*0.2+a100*0.1;
      double confInc=(predSucceeded?3.0:0.0)+(S.physicsConsensus>70?2.0:0.0)+(htfAlign==S.direction&&S.direction!=0?1.5:0.0)+(dir_tf1==dir_tf2&&dir_tf1!=0?1.0:0.0);
      double confDec=(predTransition&&!predSucceeded?2.0:0.0)+(S.physicsDiff>60?2.0:0.0)+(htfAlign!=S.direction&&S.direction!=0?1.5:0.0)+(dir_tf1!=dir_tf2&&dir_tf1!=0&&dir_tf2!=0?1.0:0.0);
      m_modelConfidence=MathMax(10.0,MathMin(100.0,m_modelConfidence+confInc-confDec-InpConfDecayRate*(m_modelConfidence-50.0))); S.modelConfidence=m_modelConfidence;
      double idealExp=S.efficiency,idealConv=S.obs_DecayScore/100.0,idealAbs=S.obs_AbsorptionScore/100.0;
      double devRaw=MathAbs(idealExp-(S.ie1a_hypFamily=="EXPANSION"?0.85:0.30))*40.0+MathAbs(idealConv-(S.ie1a_hypFamily=="CONVEXITY FORMING"?0.70:0.20))*30.0+MathAbs(idealAbs-(S.ie1a_hypFamily=="ABSORPTION"?0.70:0.15))*30.0;
      S.waveDeviation=MathMin(devRaw,100.0);S.deviationAlert=S.waveDeviation>InpDevReinterp;
      S.die_entryScore=MathMin((S.waveModelFit*0.20)+(m_modelConfidence*0.20)+(htfAlign==S.direction&&S.direction!=0?20.0:htfAlign==0?10.0:0.0)+(S.liqHeat>50?15.0:S.liqHeat*0.30)+(dirFUactive?15.0:0.0)+(flipzoneStagesComplete>=3?10.0:flipzoneStagesComplete*3.3),100.0);
      double contProb=MathMin(100.0,m_modelConfidence*0.5+S.fractalStackScore*0.3+S.ie1a_phaseConfidence*0.2);
      grade=contProb>=90?"A+":contProb>=80?"A":contProb>=70?"B":contProb>=60?"C":"D"; S.doe_grade=grade;
   }
};

//============================== FRZEngine ===========================
class FRZEngine
{
private:
   double m_top[],m_bot[]; int m_bar[],m_dir[],m_score[]; string m_tier[],m_status[]; int m_n;
   double m_o[],m_h[],m_l[],m_c[]; int m_nb,m_barIndex;
   double gO(int b){return(b<m_nb?m_o[b]:F72_NA);} double gC(int b){return(b<m_nb?m_c[b]:F72_NA);}
   double gH(int b){return(b<m_nb?m_h[b]:F72_NA);} double gL(int b){return(b<m_nb?m_l[b]:F72_NA);}
public:
   void Init(){ m_n=0;m_nb=0;m_barIndex=0;ArrayResize(m_top,0);ArrayResize(m_bot,0);ArrayResize(m_bar,0);ArrayResize(m_dir,0);ArrayResize(m_score,0);ArrayResize(m_tier,0);ArrayResize(m_status,0);ArrayResize(m_o,0);ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0); }
   void pushBar(double o,double h,double l,double c){ int keep=10;
      ArrayResize(m_o,m_nb+1);ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);
      for(int i=m_nb;i>0;i--){m_o[i]=m_o[i-1];m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];}
      m_o[0]=o;m_h[0]=h;m_l[0]=l;m_c[0]=c;m_nb++;
      if(m_nb>keep){ArrayResize(m_o,keep);ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);m_nb=keep;} m_barIndex++; }
   void Update(BrainState &S,double o,double h,double l,double c)
   {
      pushBar(o,h,l,c); double atr=S.atr; double rng=h-l,body=MathAbs(c-o),upW=h-MathMax(o,c),loW=MathMin(o,c)-l;
      double pRng=gH(1)-gL(1),pBody=MathAbs(gC(1)-gO(1)),pUpW=gH(1)-MathMax(gO(1),gC(1)),pLoW=MathMin(gO(1),gC(1))-gL(1);
      double pBodyR=pRng>1e-10?pBody/pRng:0,pUpR=pRng>1e-10?pUpW/pRng:0,pLoR=pRng>1e-10?pLoW/pRng:0;
      bool bearGap=!f72_isna(gC(1))&&o<gC(1)-atr*0.05, bullGap=!f72_isna(gC(1))&&o>gC(1)+atr*0.05;
      bool isBearFU_prev=pRng>atr*0.5&&pBodyR>=InpFuMinBodyRatio&&gC(1)<gO(1)&&pUpR>=InpFuMinWickRatio&&bearGap;
      bool isBullFU_prev=pRng>atr*0.5&&pBodyR>=InpFuMinBodyRatio&&gC(1)>gO(1)&&pLoR>=InpFuMinWickRatio&&bullGap;
      bool inZone=!f72_isna(S.flipTop)&&!f72_isna(S.flipBot)&&c>=S.flipBot*0.98&&c<=S.flipTop*1.02;
      bool isBullFU=rng>atr*0.5&&(rng>0?body/rng:0)>=InpFuMinBodyRatio&&c>o&&(rng>0?loW/rng:0)>=InpFuMinWickRatio&&inZone;
      bool isBearFU=rng>atr*0.5&&(rng>0?body/rng:0)>=InpFuMinBodyRatio&&c<o&&(rng>0?upW/rng:0)>=InpFuMinWickRatio&&inZone;
      bool hasFU_gc=isBullFU_prev||isBearFU_prev; bool hasFU=hasFU_gc||isBullFU||isBearFU;
      bool fuBull=isBullFU_prev||isBullFU, fuBear=isBearFU_prev||isBearFU;
      bool hasImb=S.displacement>InpDispThresh;
      bool hasLiq=S.liqSweepBull||S.liqSweepBear||S.liqVacuum||(S.obs_LiquidityScore>55.0);
      bool hasDisp=S.bullImpulse||S.bearImpulse;
      int raw=(hasFU?25:0)+(hasImb?25:0)+(hasLiq?25:0)+(hasDisp?25:0);
      bool approved=!(S.liqHeat>60&&!(S.liqSweepBull||S.liqSweepBear));
      string tier=raw>=76?"T1":raw>=51?"T2":(raw>=26&&hasFU)?"T3":(raw>=26&&hasImb)?"T4":"-";
      int spawnDir=(S.direction==1||fuBull)&&!(S.direction==-1||fuBear)?1:(S.direction==-1||fuBear)&&!(S.direction==1||fuBull)?-1:S.direction!=0?S.direction:0;
      double zTop=spawnDir==1?MathMax(o,c):h, zBot=spawnDir==1?l:MathMin(o,c);
      if(hasFU_gc){ zTop=spawnDir==1?gH(1):MathMax(gO(1),gC(1)); zBot=spawnDir==1?MathMin(gO(1),gC(1)):gL(1); }
      if(zTop<=zBot){ zTop=MathMax(o,MathMax(c,h)); zBot=MathMin(o,MathMin(c,l)); }
      bool overlaps=false; for(int i=0;i<m_n;i++){ double oh=MathMin(zTop,m_top[i]),olo=MathMax(zBot,m_bot[i]);double ov=MathMax(0.0,oh-olo);if(ov/MathMax(zTop-zBot,1e-10)>0.5){overlaps=true;break;} }
      bool spawn=approved&&raw>=InpFrzMinScore&&raw>0&&(hasFU||hasImb)&&spawnDir!=0&&!overlaps;
      if(spawn){ int sz=m_n;ArrayResize(m_top,sz+1);ArrayResize(m_bot,sz+1);ArrayResize(m_bar,sz+1);ArrayResize(m_dir,sz+1);ArrayResize(m_score,sz+1);ArrayResize(m_tier,sz+1);ArrayResize(m_status,sz+1);
                 m_top[sz]=zTop;m_bot[sz]=zBot;m_bar[sz]=m_barIndex;m_dir[sz]=spawnDir;m_score[sz]=raw;m_tier[sz]=tier;m_status[sz]="Open";m_n++; }
      for(int i=m_n-1;i>=0;i--){ bool terminal=(m_status[i]=="Mitigated"||m_status[i]=="Invalidated"); int age=m_barIndex-m_bar[i];
         if(!terminal){ bool wickIn=l<=m_top[i]&&h>=m_bot[i]; bool closeIn=c>=m_bot[i]&&c<=m_top[i]; bool invalid=(m_dir[i]==1&&c<m_bot[i]-atr*0.1)||(m_dir[i]==-1&&c>m_top[i]+atr*0.1);
            if(closeIn)m_status[i]="Mitigated"; else if(invalid)m_status[i]="Invalidated"; else if(wickIn&&m_status[i]=="Open")m_status[i]="Partial"; terminal=(m_status[i]=="Mitigated"||m_status[i]=="Invalidated"); }
         if(terminal||age>=InpFrzMaxBars){ for(int j=i;j<m_n-1;j++){m_top[j]=m_top[j+1];m_bot[j]=m_bot[j+1];m_bar[j]=m_bar[j+1];m_dir[j]=m_dir[j+1];m_score[j]=m_score[j+1];m_tier[j]=m_tier[j+1];m_status[j]=m_status[j+1];}
            m_n--;ArrayResize(m_top,m_n);ArrayResize(m_bot,m_n);ArrayResize(m_bar,m_n);ArrayResize(m_dir,m_n);ArrayResize(m_score,m_n);ArrayResize(m_tier,m_n);ArrayResize(m_status,m_n); } }
      S.frz_activeCount=m_n; int bi=-1;double bs=-1; for(int i=0;i<m_n;i++) if(m_score[i]>bs){bs=m_score[i];bi=i;}
      if(bi>=0){ S.frz_bestScore=m_score[bi];S.frz_bestTier=m_tier[bi];S.frz_bestStatus=m_status[bi];S.frz_bestDir=m_dir[bi];S.frz_bestTop=m_top[bi];S.frz_bestBot=m_bot[bi];S.frz_distanceToZone=MathAbs(c-(m_top[bi]+m_bot[bi])/2.0)/MathMax(atr,1e-10); }
      else { S.frz_bestScore=0;S.frz_bestTier="-";S.frz_bestStatus="-";S.frz_bestDir=0;S.frz_bestTop=F72_NA;S.frz_bestBot=F72_NA;S.frz_distanceToZone=F72_NA; }
   }
};

//============================== CurveOrganism =======================
class CurveOrganism
{
private:
   double m_compHist[6]; double m_wholeChainLife; int m_narrDir; double m_legX,m_legPBdepth,m_narrative; double m_lifeSeq[]; int m_lifeN;
public:
   void Init(){ ArrayInitialize(m_compHist,0);m_wholeChainLife=50.0;m_narrDir=0;m_legX=F72_NA;m_legPBdepth=0;m_narrative=50.0;m_lifeN=0;ArrayResize(m_lifeSeq,0); }
   void Update(BrainState &S,const SE_Out &canon,double high,double low,double close)
   {
      double cmpNow=f72_nz(canon.compIdx,0.0); double eRes=S.re_residualEnergyScore; int ownDir=S.waveDir;
      double ownOrig=canon.inv; double ownExt=ownDir==1?f72_nz(S.cycleHigh,high):ownDir==-1?f72_nz(S.cycleLow,low):close;
      double cmp5=m_compHist[5]; double cmpTighten=cmpNow-cmp5; int treeDepth=S.waveDepth;
      int budget=(int)MathMax(1,MathMin(4,1+MathRound(cmpNow/33.0))); bool recursionComplete=(budget>0&&treeDepth>=budget);
      bool attacking=ownDir==1?high>=f72_nz(ownExt,high):ownDir==-1?low<=f72_nz(ownExt,low):false;
      bool trendImp=(ownDir==1&&S.bullImpulse)||(ownDir==-1&&S.bearImpulse); bool progressing=attacking||trendImp;
      double retrX=(f72_isna(ownExt)||f72_isna(ownOrig)||ownExt==ownOrig)?50.0:MathMin(100.0,MathAbs(ownExt-close)/MathAbs(ownExt-ownOrig)*100.0);
      double cpForce=MathMax(0.0,MathMin(100.0,cmpNow*0.50+eRes*0.20-treeDepth*12.0+MathMax(0.0,cmpTighten)*0.8+8.0));
      string cpState=cpForce>=60.0?"PERSISTING":cpForce<=35.0?"LEAKING":"NEUTRAL";
      double life=MathMax(0.0,MathMin(100.0,cpForce*0.45+eRes*0.30+(cmpTighten>0.0?12.0:0.0)-(recursionComplete&&!progressing?25.0:0.0)-(cpState=="LEAKING"&&!progressing?20.0:0.0)+(progressing?28.0:0.0)+(retrX<25.0?16.0:retrX<45.0?6.0:retrX>75.0?-12.0:0.0)+10.0));
      if(ownDir!=m_narrDir){ m_narrDir=ownDir;m_legX=ownDir==1?high:ownDir==-1?low:F72_NA;m_legPBdepth=0;m_narrative=50.0;m_lifeN=0;ArrayResize(m_lifeSeq,0); }
      if(ownDir!=0&&!f72_isna(ownOrig))
      {
         bool newLegX=ownDir==1?high>f72_nz(m_legX,high):low<f72_nz(m_legX,low);
         if(newLegX){ if(m_legPBdepth>6.0){ bool sup=m_legPBdepth<=50.0&&cmpTighten>=-1.0; bool deg=m_legPBdepth>=62.0||cmpTighten<-3.0; int vote=sup?1:deg?-1:0;
               m_narrative=MathMax(0.0,MathMin(100.0,m_narrative+vote*12.0+(cmpTighten>0.0?3.0:-3.0)));
               int sz=m_lifeN;ArrayResize(m_lifeSeq,sz+1);m_lifeSeq[sz]=life;m_lifeN++; if(m_lifeN>5){for(int i=0;i<m_lifeN-1;i++)m_lifeSeq[i]=m_lifeSeq[i+1];m_lifeN--;ArrayResize(m_lifeSeq,m_lifeN);} }
            m_legX=ownDir==1?high:low;m_legPBdepth=0; }
         else { double pbd=MathAbs(f72_nz(m_legX,close)-ownOrig)>1e-9?MathAbs(f72_nz(m_legX,close)-close)/MathAbs(f72_nz(m_legX,close)-ownOrig)*100.0:0.0; m_legPBdepth=MathMax(m_legPBdepth,pbd); }
      }
      string narrState=m_narrative>=65.0?"STRENGTHENING":m_narrative<=35.0?"WEAKENING":"HOLDING";
      m_wholeChainLife=m_wholeChainLife+0.02*(life-m_wholeChainLife);
      double chainVitality=m_lifeN>=2?MathMax(0.0,MathMin(100.0,50.0+(m_lifeSeq[m_lifeN-1]-m_lifeSeq[0]))):m_wholeChainLife;
      string chainScope=life>=50.0?"healthy":chainVitality>=50.0?"CURVE only - chain intact":m_wholeChainLife>=45.0?"CHAIN weakening":"WHOLE CHAIN decaying";
      string aliveVerdict=(progressing&&life>=45.0)?"ALIVE - ATTACKING":life>=60.0?"ALIVE - HOLD":life<=32.0?"DEAD - FLIP":"WEAKENING - MANAGE";
      S.ownerDir=ownDir;S.treeDepth=treeDepth;S.life=life;S.cpForce=cpForce;S.cpState=cpState;S.gCompress=cmpNow;S.gResidual=eRes;S.narrative=m_narrative;S.narrState=narrState;S.chainVitality=chainVitality;S.wholeChainLife=m_wholeChainLife;S.chainScope=chainScope;S.aliveVerdict=aliveVerdict;
      for(int i=5;i>0;i--) m_compHist[i]=m_compHist[i-1]; m_compHist[0]=cmpNow;
   }
};

//============================== TimeIntel ===========================
class TimeIntel
{
private:
   string m_sym; int bias(ENUM_TIMEFRAMES tf,double close){ double op=iOpen(m_sym,tf,0);return(close>op?1:close<op?-1:0); }
public:
   void Init(string sym){ m_sym=sym; }
   void Update(BrainState &S,double close)
   {
      ENUM_TIMEFRAMES tf[5]={PERIOD_MN1,PERIOD_W1,PERIOD_D1,PERIOD_H4,PERIOD_H1}; int bull=0,bear=0;
      for(int i=0;i<5;i++){int b=bias(tf[i],close);if(b==1)bull++;else if(b==-1)bear++;}
      S.timeDir=bull>bear?1:bear>bull?-1:0; S.timeAlign=(bull+bear)>0?(double)MathMax(bull,bear)/(bull+bear)*100.0:50.0; S.timeConflict=100.0-S.timeAlign;
      bool h1Ht=iHigh(m_sym,PERIOD_H1,0)>iHigh(m_sym,PERIOD_H1,1); bool h1Lt=iLow(m_sym,PERIOD_H1,0)<iLow(m_sym,PERIOD_H1,1);
      double h1H=iHigh(m_sym,PERIOD_H1,0),h1L=iLow(m_sym,PERIOD_H1,0); double pos=(close-h1L)/MathMax(h1H-h1L,_Point);
      double lowProb=(h1Lt&&!h1Ht)?30.0:(h1Ht&&!h1Lt)?70.0:MathRound(pos*100.0);
      S.h1Timing=(h1Ht&&h1Lt)?"COMPLETION":lowProb>=55?"LOW FIRST":lowProb<=45?"HIGH FIRST":"BALANCED";
   }
};

//============================== NetworkEngine =======================
class NetworkEngine
{
private:
   string m_sym; double m_px[]; int m_dir[]; double m_sc[]; int m_wt[]; int m_state[]; int m_bar[]; int m_rev[]; int m_n; int m_barIndex;
   double m_lastTip[7]; ENUM_TIMEFRAMES m_tf[7]; int m_wtv[7];
   bool detect(ENUM_TIMEFRAMES tf,double wf,int lb,double &tip,double &mid,int &dir,double &score)
   {
      int need=lb+2; MqlRates r[]; if(CopyRates(m_sym,tf,1,need,r)<need) return(false);
      int n=ArraySize(r); double H=r[n-1].high,L=r[n-1].low,O=r[n-1].open,C=r[n-1].close; double rng=MathMax(H-L,1e-10);
      double pHi=-DBL_MAX,pLo=DBL_MAX; for(int i=n-1-lb;i<n-1;i++){ if(i>=0){pHi=MathMax(pHi,r[i].high);pLo=MathMin(pLo,r[i].low);} }
      double uw=(H-MathMax(O,C))/rng,lw=(MathMin(O,C)-L)/rng; bool localTop=true,localBot=true;
      for(int i=n-1-lb;i<n-1;i++){ if(i>=0){ if(r[i].high>H)localTop=false; if(r[i].low<L)localBot=false; } }
      bool bear=uw>=wf&&((H>=pHi&&C<pHi)||(localTop&&C<O)); bool bull=lw>=wf&&((L<=pLo&&C>pLo)||(localBot&&C>O));
      double atr=0; for(int i=1;i<n;i++) atr+=MathAbs(r[i].close-r[i-1].close); atr=MathMax(atr/MathMax(n-1,1),1e-10);
      if(bear){dir=-1;tip=H;double bH=MathMax(O,C);mid=bH+(tip-bH)*0.5;double wk=(tip-bH)/atr;score=20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0);return(true);}
      if(bull){dir=1;tip=L;double bL=MathMin(O,C);mid=tip+(bL-tip)*0.5;double wk=(bL-tip)/atr;score=20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0);return(true);}
      return(false);
   }
   double authority(int i){ return(m_sc[i]+m_wt[i]*4.0+m_rev[i]*3.0); }
   void addNode(double px,int dir,double sc,int wt)
   { int sz=m_n;ArrayResize(m_px,sz+1);ArrayResize(m_dir,sz+1);ArrayResize(m_sc,sz+1);ArrayResize(m_wt,sz+1);ArrayResize(m_state,sz+1);ArrayResize(m_bar,sz+1);ArrayResize(m_rev,sz+1);
     m_px[sz]=px;m_dir[sz]=dir;m_sc[sz]=sc;m_wt[sz]=wt;m_state[sz]=0;m_bar[sz]=m_barIndex;m_rev[sz]=0;m_n++;
     if(m_n>InpNodeMax){for(int j=0;j<m_n-1;j++){m_px[j]=m_px[j+1];m_dir[j]=m_dir[j+1];m_sc[j]=m_sc[j+1];m_wt[j]=m_wt[j+1];m_state[j]=m_state[j+1];m_bar[j]=m_bar[j+1];m_rev[j]=m_rev[j+1];}m_n--;ArrayResize(m_px,m_n);ArrayResize(m_dir,m_n);ArrayResize(m_sc,m_n);ArrayResize(m_wt,m_n);ArrayResize(m_state,m_n);ArrayResize(m_bar,m_n);ArrayResize(m_rev,m_n);} }
public:
   void Init(string sym){ m_sym=sym;m_n=0;m_barIndex=0;
      ENUM_TIMEFRAMES tfs[7]={PERIOD_MN1,PERIOD_W1,PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M15,PERIOD_M5}; int wts[7]={9,8,7,6,5,4,3};
      for(int i=0;i<7;i++){m_tf[i]=tfs[i];m_wtv[i]=wts[i];m_lastTip[i]=F72_NA;} }
   void Update(BrainState &S,double close)
   {
      m_barIndex++; int netBias=0;
      for(int i=0;i<7;i++){ double tip,mid,sc;int dir; if(detect(m_tf[i],InpWickFrac,InpFuStructLook,tip,mid,dir,sc)){ if(netBias==0)netBias=dir; if(f72_isna(m_lastTip[i])||MathAbs(tip-m_lastTip[i])>_Point){addNode(tip,dir,sc,m_wtv[i]);m_lastTip[i]=tip;} } }
      double ema50=close; if(netBias==0){ double e=0;MqlRates r[]; if(CopyRates(m_sym,_Period,1,50,r)>=50){for(int i=0;i<50;i++)e+=r[i].close;e/=50.0;ema50=e;} netBias=close>ema50?1:close<ema50?-1:0; }
      S.netBias=netBias; double atr=S.atr; double bullAuth=0,bearAuth=0; int elig=0;
      for(int i=0;i<m_n;i++){ if(m_state[i]!=2){ double np=m_px[i];int nd=m_dir[i]; if(nd==-1?close>np:close<np)m_state[i]=2; else { if(MathAbs(close-np)<atr*0.25)m_rev[i]++; } }
         if(m_state[i]!=2&&authority(i)>=InpAuthMin){ elig++; if(m_dir[i]==1)bullAuth+=authority(i); else bearAuth+=authority(i); } }
      S.eligNodes=elig; S.netPressure=(bullAuth+bearAuth)>0?(bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0.0; S.pdir=S.netPressure>12?1:S.netPressure<-12?-1:0;
   }
};

//============================== Senseei / DOE =======================
bool strHas(string s,string sub){ return(StringFind(s,sub)>=0); }

// --- RIE: Rotation Intelligence Engine (V72 Part 3) ---
void ComputeRIE(BrainState &S)
{
   bool impulse=S.bullImpulse||S.bearImpulse;
   S.rot_pressure=MathMin(100.0,S.obs_DecayScore*0.35+S.obs_AbsorptionScore*0.30+(S.convexityScore>40?S.convexityScore*0.20:0.0)+(S.obs_LiquidityScore>50?15.0:0.0));
   S.rot_controlStability=MathMin(100.0,S.obs_ExpansionScore*0.40+(S.efficiency>InpEffThresh?30.0:S.efficiency>InpEffThresh*0.7?15.0:0.0)+(S.ede_state<=2?30.0:S.ede_state<=3?15.0:0.0));
   S.rot_transferProbability=MathMin(100.0,S.rot_pressure*0.50+(100.0-S.rot_controlStability)*0.30+(S.re_resolutionState=="UNRESOLVED"?20.0:S.re_resolutionState=="PARTIALLY RESOLVED"?10.0:0.0));
   S.rot_emergingWaveStrength=MathMin(100.0,S.obs_DecayScore*0.40+(S.convexityScore>25?S.convexityScore*0.30:0.0)+(!impulse&&S.obs_AbsorptionScore>40?20.0:0.0));
   S.rot_state=S.rot_transferProbability>=75?"TRANSFER_IMMINENT":S.rot_transferProbability>=50?"CONTESTED":S.rot_transferProbability>=25?"SOFTENING":"STABLE";
}

// --- MCE: Multi-Timeframe Consensus (V72 Part 4) — 9 TF from 6 rungs + D/W/MN ---
void ComputeMCE(BrainState &S,int &ldir[],string sym)
{
   int dW=iClose(sym,PERIOD_D1,0)>iOpen(sym,PERIOD_D1,0)?1:iClose(sym,PERIOD_D1,0)<iOpen(sym,PERIOD_D1,0)?-1:0;
   int wW=iClose(sym,PERIOD_W1,0)>iOpen(sym,PERIOD_W1,0)?1:iClose(sym,PERIOD_W1,0)<iOpen(sym,PERIOD_W1,0)?-1:0;
   int mW=iClose(sym,PERIOD_MN1,0)>iOpen(sym,PERIOD_MN1,0)?1:iClose(sym,PERIOD_MN1,0)<iOpen(sym,PERIOD_MN1,0)?-1:0;
   int tf[9]; tf[0]=ldir[0];tf[1]=ldir[1];tf[2]=ldir[2];tf[3]=ldir[3];tf[4]=ldir[4];tf[5]=ldir[5];tf[6]=dW;tf[7]=wW;tf[8]=mW;
   int L0=S.waveDir; int agree=0; for(int i=0;i<9;i++) if(tf[i]==L0&&L0!=0) agree++;
   S.mce_alignmentScore=(double)agree/9.0*100.0; S.mce_dir=L0;
   int htfA=0; for(int i=4;i<9;i++) if(tf[i]==L0&&L0!=0) htfA++; S.mce_htfAlignmentScore=(double)htfA/5.0*100.0;   // H1,H4,D,W,MN
   int mtfA=0; for(int i=3;i<6;i++) if(tf[i]==L0&&L0!=0) mtfA++; S.mce_mtfAlignmentScore=(double)mtfA/3.0*100.0;   // M15,H1,H4
   int exA=0;  for(int i=0;i<3;i++) if(tf[i]==L0&&L0!=0) exA++;  S.mce_execAlignmentScore=(double)exA/3.0*100.0;    // M1,M3,M5
   S.mce_htfNarrative = (S.mce_htfAlignmentScore>=80&&L0==1)?"HTF Bullish Continuation":(S.mce_htfAlignmentScore>=80&&L0==-1)?"HTF Bearish Continuation":(S.mce_htfAlignmentScore>=60&&S.rot_transferProbability<40)?"HTF Trend Intact":(S.mce_htfAlignmentScore<40)?"HTF Contested - No Clear Bias":(S.mce_htfAlignmentScore>=50&&S.rot_transferProbability>=60)?"HTF Rotation Developing":"HTF Developing";
   string p=S.ie1a_currentPhase;
   S.mce_execNarrative = (p=="Demand Return"&&S.mce_execAlignmentScore>=60)?"Execution Aligned - Long Entry Window":(p=="Supply Return"&&S.mce_execAlignmentScore>=60)?"Execution Aligned - Short Entry Window":(S.mce_execAlignmentScore<40)?"Execution Conflict - Wait":"Execution Developing";
}

// --- FRZ <-> ERF unification + tertiary attractor (V72 Part 9 / 10.6) ---
void ComputeFRZUnify(BrainState &S,double close)
{
   S.frz_resolutionScore = S.re_resolutionState=="RESOLVED"?90.0:S.re_resolutionState=="PARTIALLY RESOLVED"?50.0+S.re_recursiveCompletionScore*0.40:20.0+S.ede_dissipationProgress*0.30;
   S.frz_residualEnergy = MathMax(0.0,100.0-S.frz_resolutionScore);
   S.frz_attractorWeight = S.frz_residualEnergy*0.50+S.frz_bestScore*0.30+(S.frz_bestStatus=="Open"?20.0:S.frz_bestStatus=="Partial"?10.0:0.0);
   S.frz_confidence = S.frz_bestScore*0.40+(S.frz_bestStatus=="Open"?30.0:S.frz_bestStatus=="Partial"?15.0:0.0)+(S.frz_bestTier=="T1"?30.0:S.frz_bestTier=="T2"?20.0:10.0);
   double atr=S.atr; double prim=S.eae_primaryAttractorPrice,sec=S.eae_secondaryAttractorPrice;
   if(S.master==0&&S.waveDir!=0) {} // keep
   int dir=S.waveDir;
   S.eae_tertiaryAttractorPrice = dir==0?F72_NA: dir==1? MathMax(f72_nz(prim,close),f72_nz(sec,close))+atr*2.0 : MathMin(f72_nz(prim,close),f72_nz(sec,close))-atr*2.0;
   S.eae_tertiaryAttractorScore = S.re_residualEnergyScore*0.30+(S.mce_htfAlignmentScore>=75?40.0:S.mce_htfAlignmentScore*0.30)+(S.re_resolutionState=="RESOLVED"?30.0:10.0);
   double zoneMid=(!f72_isna(S.frz_bestTop)&&!f72_isna(S.frz_bestBot))?(S.frz_bestTop+S.frz_bestBot)/2.0:F72_NA;
   S.frz_attractorConvergence = S.frz_activeCount>0&&!f72_isna(S.eae_primaryAttractorPrice)&&!f72_isna(zoneMid)&&MathAbs(S.eae_primaryAttractorPrice-zoneMid)/MathMax(atr,1e-10)<0.5;
}

// --- IE2: Invalidation Engine (V72 Part 11) ---
void ComputeIE2(BrainState &S,double close)
{
   double atr=S.atr; int dir=S.waveDir;
   S.inv_bullOrigin=!f72_isna(S.point4OriginLow)?S.point4OriginLow-atr*0.25:F72_NA;
   S.inv_bearOrigin=!f72_isna(S.point4OriginHigh)?S.point4OriginHigh+atr*0.25:F72_NA;
   S.inv_demandFail=(dir==1&&S.closeInside&&!f72_isna(S.flipBot))?S.flipBot-atr*0.10:F72_NA;
   S.inv_supplyFail=(dir==-1&&S.closeInside&&!f72_isna(S.flipTop))?S.flipTop+atr*0.10:F72_NA;
   if(dir==1)      S.inv_activeStop=MathMin(f72_nz(S.inv_bullOrigin,close-atr),f72_nz(S.inv_demandFail,f72_nz(S.inv_bullOrigin,close-atr)));
   else if(dir==-1)S.inv_activeStop=MathMax(f72_nz(S.inv_bearOrigin,close+atr),f72_nz(S.inv_supplyFail,f72_nz(S.inv_bearOrigin,close+atr)));
   else            S.inv_activeStop=F72_NA;
   S.inv_invalidated=!f72_isna(S.inv_activeStop)&&(dir==1?close<S.inv_activeStop:dir==-1?close>S.inv_activeStop:false);
   S.inv_riskPts=!f72_isna(S.inv_activeStop)?MathAbs(close-S.inv_activeStop):F72_NA;
   S.inv_riskATR=!f72_isna(S.inv_riskPts)?S.inv_riskPts/MathMax(atr,1e-10):F72_NA;
}

// --- TE: Target Engine (V72 Part 10) ---
void ComputeTE(BrainState &S,double close)
{
   double atr=S.atr; int dir=S.waveDir;
   S.te_tp1=!f72_isna(S.eae_secondaryAttractorPrice)?S.eae_secondaryAttractorPrice:(dir==1?close+atr:close-atr);
   S.te_tp2=!f72_isna(S.eae_primaryAttractorPrice)?S.eae_primaryAttractorPrice:(dir==1?close+atr*2.0:close-atr*2.0);
   S.te_tp3=!f72_isna(S.eae_tertiaryAttractorPrice)?S.eae_tertiaryAttractorPrice:(dir==1?close+atr*3.0:close-atr*3.0);
   S.te_tp1q=MathMin(100.0,S.eae_secondaryAttractorScore*0.40+(S.frz_attractorConvergence?40.0:S.frz_bestScore*0.25)+S.re_recursiveCompletionScore*0.15+S.mce_execAlignmentScore*0.20);
   S.te_tp2q=MathMin(100.0,S.eae_primaryAttractorScore*0.50+S.re_residualEnergyScore*0.30+S.mce_htfAlignmentScore*0.20);
   S.te_tp3q=MathMin(100.0,(S.eae_tertiaryAttractorScore>0?S.eae_tertiaryAttractorScore*0.60:20.0)+(S.mce_htfAlignmentScore>=80?40.0:S.mce_htfAlignmentScore*0.30));
   string p=S.ie1a_currentPhase;
   S.te_expectedPath=(S.re_resolutionState=="RESOLVED"&&S.mce_execAlignmentScore>=70)?"Direct":(p=="Demand Return"||p=="Supply Return")?"Direct":S.rot_transferProbability>50?"Retracement First":S.re_resolutionState=="UNRESOLVED"?"Range Then Breakout":"Direct";
   double rp=f72_nz(S.inv_riskPts,atr);
   S.te_rr1=MathAbs(S.te_tp1-close)/MathMax(rp,1e-10); S.te_rr2=MathAbs(S.te_tp2-close)/MathMax(rp,1e-10); S.te_rr3=MathAbs(S.te_tp3-close)/MathMax(rp,1e-10);
   S.te_rrGate=S.te_rr1>=1.5;
}

// --- NE: Narrative Engine (V72 Part 5) ---
void ComputeNE(BrainState &S)
{
   int dir=S.waveDir; double htf=S.mce_htfAlignmentScore,tp=S.rot_transferProbability; string p=S.ie1a_currentPhase;
   bool contUpPhase=(p=="Expansion"||p=="New High"||p=="Demand Return"), contDnPhase=(p=="Expansion"||p=="New Low"||p=="Supply Return");
   bool pullPhase=(p=="Retracement"||p=="HTF Flip Zone"||p=="Induction"||p=="Liquidation"||p=="Terminal Curve"||p=="Demand Return"||p=="Supply Return");
   string n;
   if(dir==1&&htf>=70&&contUpPhase&&tp<40) n="Bullish Continuation";
   else if(dir==-1&&htf>=70&&contDnPhase&&tp<40) n="Bearish Continuation";
   else if(dir==1&&pullPhase&&htf>=55) n="Bullish Pullback";
   else if(dir==-1&&pullPhase&&htf>=55) n="Bearish Pullback";
   else if(tp>=65&&dir==-1&&htf>=50) n="Bullish Rotation";
   else if(tp>=65&&dir==1&&htf>=50) n="Bearish Rotation";
   else if(S.rot_state=="CONTESTED"&&MathAbs(S.mce_alignmentScore-50.0)<15.0&&S.re_resolutionState=="UNRESOLVED") n="Range Development";
   else n="No Clear Narrative";
   S.ne_dominantNarrative=n;
   S.ne_narrativeStrength=S.mce_alignmentScore*0.40+S.rot_controlStability*0.30+(S.re_resolutionState=="RESOLVED"?30.0:S.re_resolutionState=="PARTIALLY RESOLVED"?15.0:0.0);
   S.ne_narrativeConflict=false;
}

// --- TQE: Trade Qualification Engine (V72 Part 6) ---
void ComputeTQE(BrainState &S)
{
   S.tqe_frzQuality=S.frz_activeCount>0?MathMin(100.0,S.frz_bestScore*0.50+(S.frz_bestTier=="T1"?40.0:S.frz_bestTier=="T2"?25.0:S.frz_bestTier=="T3"?10.0:0.0)+(S.frz_bestStatus=="Open"?10.0:S.frz_bestStatus=="Partial"?5.0:0.0)):0.0;
   S.tqe_liqQuality=MathMin(100.0,S.obs_LiquidityScore*0.50+((S.liqSweepBull||S.liqSweepBear)?30.0:0.0)+(S.liqVacuum?20.0:0.0));
   S.tqe_rawScore=S.ie1a_phaseConfidence*0.25+S.erf_confidence*0.15+S.tqe_frzQuality*0.15+S.mce_htfAlignmentScore*0.20+S.re_recursiveCompletionScore*0.10+S.tqe_liqQuality*0.15;
   S.tqe_grade=S.tqe_rawScore>=85?"A+":S.tqe_rawScore>=72?"A":S.tqe_rawScore>=58?"B":S.tqe_rawScore>=42?"C":"D";
   // attractor convergence promotes one letter; R:R<1.5 degrades one letter
   if(S.frz_attractorConvergence){ if(S.tqe_grade=="A")S.tqe_grade="A+"; else if(S.tqe_grade=="B")S.tqe_grade="A"; else if(S.tqe_grade=="C")S.tqe_grade="B"; else if(S.tqe_grade=="D")S.tqe_grade="C"; }
   if(!S.te_rrGate){ if(S.tqe_grade=="A+")S.tqe_grade="A"; else if(S.tqe_grade=="A")S.tqe_grade="B"; else if(S.tqe_grade=="B")S.tqe_grade="C"; else if(S.tqe_grade=="C")S.tqe_grade="D"; }
   S.tqe_readiness=S.ie1a_phaseConfidence>=50&&S.erf_confidence>=40&&S.mce_htfAlignmentScore>=50&&S.tqe_grade!="D";
   S.tqe_riskLevel=(S.rot_transferProbability>65||S.re_resolutionState=="UNRESOLVED")?"HIGH":(S.rot_transferProbability>35||S.tqe_rawScore<60)?"MEDIUM":"LOW";
}

void ComputeSenseei(BrainState &S,double close)
{
   // V72 decision layer (MCE already computed in Brain). Order: RIE -> FRZ/ERF unify -> IE2 -> TE -> NE -> TQE
   ComputeRIE(S); ComputeFRZUnify(S,close); ComputeIE2(S,close); ComputeTE(S,close); ComputeNE(S); ComputeTQE(S);
   S.attractorScore=S.eae_primaryAttractorScore; double residual=S.re_residualEnergyScore;
   int resCode=S.re_resolutionState=="RESOLVED"?2:S.re_resolutionState=="PARTIALLY RESOLVED"?1:0;
   int vt1=S.waveDir,vt2=S.fractalStackDir,vt3=S.netBias,vt4=S.pdir; int sum=vt1+vt2+vt3+vt4; int master=sum>0?1:sum<0?-1:0;
   int cast=(vt1!=0?1:0)+(vt2!=0?1:0)+(vt3!=0?1:0)+(vt4!=0?1:0);
   int forV=(vt1==master&&vt1!=0?1:0)+(vt2==master&&vt2!=0?1:0)+(vt3==master&&vt3!=0?1:0)+(vt4==master&&vt4!=0?1:0);
   double alignment=cast>0?(double)forV/cast*100.0:50.0; double conflict=cast>0?(double)(cast-forV)/cast*100.0:0.0;
   double threat=MathMax(0.0,MathMin(100.0,conflict*0.40+residual*0.28+S.timeConflict*0.12+(vt4!=0&&vt4!=master?18.0:0.0)+(resCode==1?10.0:0.0)));
   double confidence=MathMax(0.0,MathMin(100.0,alignment*0.40+S.timeAlign*0.12+S.fractalStackScore*0.18+S.attractorScore*0.15+MathMin(15.0,S.eligNodes*1.2)-threat*0.20));
   string p=S.ie1a_currentPhase;
   string timing=(strHas(p,"Absorption")||resCode==2)?"RESOLVED":S.waveProgress<15?"VERY EARLY":S.waveProgress<35?"EARLY":S.waveProgress<55?"DEVELOPING":S.waveProgress<80?"MID CYCLE":S.waveProgress<96?"LATE":"TERMINAL";
   string intent=conflict>55?"ABSORPTION":(strHas(p,"Expansion")&&!strHas(p,"Pre-Convexity")&&!strHas(p,"Induction")&&!strHas(p,"Liquidity"))?"EXPANSION":strHas(p,"Pre-Convexity")?"CONTINUATION":strHas(p,"Induction")?"RESOLUTION":strHas(p,"Liquidity")?"DELIVERY":(strHas(p,"New High")||strHas(p,"New Low"))?"DELIVERY":strHas(p,"Absorption")?"ABSORPTION":master==0?"BALANCE":"CONTINUATION";
   double oppScore=MathMax(0.0,MathMin(100.0,alignment*0.40+S.attractorScore*0.30+S.fractalStackScore*0.30-threat*0.35));
   string opportunity=master==0?"NONE":conflict>60?"DEVELOPING":oppScore<20?"NONE":oppScore<40?"DEVELOPING":oppScore<62?"GOOD":oppScore<82?"STRONG":"EXCEPTIONAL";
   string action=master==0?"WAIT":conflict>60?"WAIT":resCode==2?"MANAGE / EXIT":((opportunity=="STRONG"||opportunity=="EXCEPTIONAL")&&confidence>=InpMinConf&&threat<45)?"ATTACK":(opportunity=="GOOD"||opportunity=="STRONG")?"PREPARE":"WAIT";
   S.master=master;S.alignment=alignment;S.conflict=conflict;S.threat=threat;S.confidence=confidence;S.oppScore=oppScore;S.timing=timing;S.intent=intent;S.opportunity=opportunity;S.action=action;

   // ===== DOE — single canonical recommendation (V72 Part 12) =====
   double htf=S.mce_htfAlignmentScore;
   S.doe_bias=(S.waveDir==1&&htf>=75&&S.rot_controlStability>=65)?"Strong Bullish":(S.waveDir==1&&htf>=50)?"Bullish":(S.waveDir==-1&&htf>=75&&S.rot_controlStability>=65)?"Strong Bearish":(S.waveDir==-1&&htf>=50)?"Bearish":"Neutral";
   S.doe_tradeType=(S.ne_dominantNarrative=="Bullish Continuation"||S.ne_dominantNarrative=="Bearish Continuation")?"Continuation":(S.ne_dominantNarrative=="Bullish Pullback"||S.ne_dominantNarrative=="Bearish Pullback")?"Pullback":(S.ne_dominantNarrative=="Bullish Rotation"||S.ne_dominantNarrative=="Bearish Rotation")?"Rotation":S.ne_dominantNarrative=="Range Development"?"Range":(p=="New High"||p=="New Low")?"Breakout":"Wait";
   // gate chain
   string act;
   if(!S.tqe_readiness)            act="Wait";
   else if(!S.erf_entryGate)       act="Wait";
   else if(!S.te_rrGate)           act="Wait";
   else if(S.inv_invalidated)      act="No Trade";
   else if(p=="Demand Return"&&S.waveDir==1)  act="Long";
   else if(p=="Supply Return"&&S.waveDir==-1) act="Short";
   else if(S.rot_transferProbability>=75&&S.ne_dominantNarrative=="Bullish Rotation") act="Long";
   else if(S.rot_transferProbability>=75&&S.ne_dominantNarrative=="Bearish Rotation") act="Short";
   else act="Wait";
   S.doe_action=act;
   double cap=S.frz_attractorConvergence?95.0:88.0;
   S.doe_confidence=MathMin(S.tqe_rawScore*0.40+S.mce_alignmentScore*0.25+(S.frz_attractorConvergence?20.0:S.tqe_frzQuality*0.15)+S.ie1a_phaseConfidence*0.20,cap);
   S.doe_entryQuality=S.tqe_grade; S.doe_grade=S.tqe_grade;
   double atr=S.atr; bool frzProx=S.frz_activeCount>0&&!f72_isna(S.frz_distanceToZone)&&S.frz_distanceToZone<2.0&&S.frz_bestDir==S.waveDir; double mid;
   if(frzProx) mid=(S.frz_bestTop+S.frz_bestBot)/2.0;
   else if(p=="Demand Return"||p=="Supply Return") mid=(!f72_isna(S.flipTop)&&!f72_isna(S.flipBot))?(S.flipTop+S.flipBot)/2.0:close;
   else mid=close;
   S.doe_entryMid=mid;S.doe_entryHigh=mid+atr*0.30;S.doe_entryLow=mid-atr*0.30;
   S.doe_entryTrigger=frzProx?"Limit":(p=="Demand Return"||p=="Supply Return")?"LimitOnRetest":"Market";
   // Senseei cockpit action must not contradict DOE: ATTACK only when DOE fires an order
   if(S.action=="ATTACK"&&S.doe_action!="Long"&&S.doe_action!="Short") S.action="PREPARE";
   // traceability strings
   S.trc_decisionSource="IE1A:"+p+" | TQE:"+S.tqe_grade+" | NE:"+S.ne_dominantNarrative;
   S.trc_waveChain="Wave#"+(string)S.wr_activeWaveId+" (parent #"+(string)S.wr_parentWaveId+", root #"+(string)S.wr_rootWaveId+", depth "+(string)S.wr_waveDepth+")";
   S.trc_confidenceBreakdown="IE1A:"+DoubleToString(S.ie1a_phaseConfidence,0)+" ERF:"+DoubleToString(S.erf_confidence,0)+" FRZ:"+DoubleToString(S.tqe_frzQuality,0)+" MCE:"+DoubleToString(S.mce_htfAlignmentScore,0)+" RE:"+DoubleToString(S.re_recursiveCompletionScore,0)+" LIQ:"+DoubleToString(S.tqe_liqQuality,0);
}

//============================== Brain ===============================
class Brain
{
private:
   string m_sym; ENUM_TIMEFRAMES m_tf;
   Engine1A m_e1a; LiquidityEngine m_liq; WaveIntelEngine m_wi; SpawnEngine m_spawn; DIEEngine m_die;
   FRZEngine m_frz; CurveOrganism m_curve; TimeIntel m_time; NetworkEngine m_net;
   datetime m_lastBar; int m_structBias; double m_pConvMat; BrainState m_S;
   int m_wrNextId,m_wrActive,m_wrParent,m_wrRoot,m_wrDepth,m_prevDir,m_prevEdeState,m_dwrNextId,m_dwrActive;
   void m1flags(bool &eW,bool &cE,bool &iE,bool &lE,bool &aE)
   {
      eW=false;cE=false;iE=false;lE=false;aE=false; MqlRates r[]; int need=InpEffLen+5; if(CopyRates(m_sym,PERIOD_M1,1,need,r)<need) return; int n=ArraySize(r);
      double c=r[n-1].close,h=r[n-1].high,l=r[n-1].low;
      double v=(r[n-1].close-r[n-2].close); v=0.5*v+0.5*(r[n-2].close-r[n-3].close);
      double a=(r[n-1].close-r[n-2].close)-(r[n-2].close-r[n-3].close);
      double cv=a-((r[n-2].close-r[n-3].close)-(r[n-3].close-r[n-4].close));
      double mv=MathAbs(c-r[n-1-InpEffLen].close); double ps=0; for(int i=n-InpEffLen;i<n;i++) ps+=MathAbs(r[i].close-r[i-1].close);
      double e=ps>0?mv/ps:0.0; double atr=0; for(int i=1;i<n;i++) atr+=MathAbs(r[i].close-r[i-1].close); atr=MathMax(atr/(n-1),1e-10); double d=(h-l)/atr;
      bool mD=MathAbs(a)<MathAbs((r[n-2].close-r[n-3].close)-(r[n-3].close-r[n-4].close))*0.8;
      eW=e<InpEffThresh*0.7&&mD; cE=MathAbs(cv)>atr*InpConvMult*1.5&&mD; iE=e>InpEffThresh&&a<0&&v>0; lE=d>InpDispThresh*1.2&&mD; aE=e<InpEffThresh*0.5&&d<InpDispThresh*0.6;
   }
public:
   void Init(string sym,ENUM_TIMEFRAMES tf)
   {
      m_sym=sym;m_tf=tf;m_lastBar=0;m_structBias=0;m_pConvMat=0;
      m_wrNextId=1;m_wrActive=0;m_wrParent=0;m_wrRoot=0;m_wrDepth=0;m_prevDir=0;m_prevEdeState=0;m_dwrNextId=1;m_dwrActive=0;
      m_e1a.Init(sym,tf);m_liq.Init();m_wi.Init();m_spawn.Init();m_die.Init();m_frz.Init();m_curve.Init();m_time.Init(sym);m_net.Init(sym);
      m_S.flipTop=F72_NA;m_S.flipBot=F72_NA;m_S.point4OriginHigh=F72_NA;m_S.point4OriginLow=F72_NA;m_S.cycleHigh=F72_NA;m_S.cycleLow=F72_NA;
      m_S.inducZoneLow=F72_NA;m_S.inducZoneHigh=F72_NA;m_S.originToExtreme=F72_NA;m_S.availableSpace=F72_NA;m_S.eae_primaryAttractorPrice=F72_NA;m_S.eae_secondaryAttractorPrice=F72_NA;m_S.inv_activeStop=F72_NA;
      m_S.re_resolutionState="UNRESOLVED";m_S.ie1a_currentPhase="Point 4 Origin";
   }
   BrainState State(){ return(m_S); }
   bool OnNewBar()
   {
      datetime t1=iTime(m_sym,m_tf,1); if(t1==0||t1==m_lastBar) return(false); m_lastBar=t1;
      double o=iOpen(m_sym,m_tf,1),h=iHigh(m_sym,m_tf,1),l=iLow(m_sym,m_tf,1),c=iClose(m_sym,m_tf,1);
      double vol=(double)iTickVolume(m_sym,m_tf,1); double volAvg=0; { long vs=0; for(int i=1;i<=20;i++) vs+=iTickVolume(m_sym,m_tf,i); volAvg=(double)vs/20.0; }
      int barIndex=Bars(m_sym,m_tf);
      BrainState S;
      m_e1a.Update(); SE_Out canon=m_e1a.Canon();
      S.atr=canon.atr;S.velocity=canon.vel;S.acceleration=canon.acc;S.convSmooth=canon.convSmooth;S.efficiency=canon.eff;S.displacement=canon.disp;
      S.bullImpulse=canon.bullImp;S.bearImpulse=canon.bearImp;S.bullMomDecay=canon.bullDec;S.bearMomDecay=canon.bearDec;S.bullConvShift=canon.bullCS;S.bearConvShift=canon.bearCS;S.phys_vd70=canon.vd70;S.phys_vd50=canon.vd50;
      S.ie1a_currentPhase=m_e1a.CurrentPhase();S.ie1a_phaseConfidence=m_e1a.PhaseConfidence();S.ie1a_hypFamily=m_e1a.HypFamily();
      S.fractalStackDir=m_e1a.fractalStackDir;S.fractalStackScore=m_e1a.fractalStackScore;S.waveDir=m_e1a.CanonDir();
      bool isHH=!f72_isna(canon.curSH)&&!f72_isna(canon.prSH)&&canon.curSH>canon.prSH;
      bool isLH=!f72_isna(canon.curSH)&&!f72_isna(canon.prSH)&&canon.curSH<canon.prSH;
      bool isHL=!f72_isna(canon.curSL)&&!f72_isna(canon.prSL)&&canon.curSL>canon.prSL;
      bool isLL=!f72_isna(canon.curSL)&&!f72_isna(canon.prSL)&&canon.curSL<canon.prSL;
      if(InpUseStrictStruct){ if(isHH&&isHL)m_structBias=1; if(isLH&&isLL)m_structBias=-1; } else { if(canon.bos==1)m_structBias=1; if(canon.bos==-1)m_structBias=-1; }
      S.structBias=m_structBias;
      S.direction=m_S.direction;S.flipTop=m_S.flipTop;S.flipBot=m_S.flipBot;S.point4OriginHigh=m_S.point4OriginHigh;S.point4OriginLow=m_S.point4OriginLow;
      S.cycleHigh=m_S.cycleHigh;S.cycleLow=m_S.cycleLow;S.inducZoneLow=m_S.inducZoneLow;S.inducZoneHigh=m_S.inducZoneHigh;
      S.entryCycle=m_S.entryCycle;S.waveDepth=m_S.waveDepth;S.recursiveComplete=m_S.recursiveComplete;S.closeInside=m_S.closeInside;S.originToExtreme=m_S.originToExtreme;S.availableSpace=m_S.availableSpace;
      S.convexityMaturity=m_pConvMat;
      ComputeObservation(S);
      ComputeEnergy(S,c);
      m_liq.Update(S,h,l,c,vol,volAvg,barIndex);
      m_wi.Update(S,c); m_pConvMat=S.convexityMaturity;
      bool bullCH=(canon.ch==1),bearCH=(canon.ch==-1);
      m_spawn.Update(S,o,h,l,c,m_e1a.CanonDir(),canon.p4h,canon.p4l,bullCH,bearCH);
      int dir_tf1=m_e1a.ldir[3],dir_tf2=m_e1a.ldir[4]; int htfAlign=(dir_tf1+dir_tf2)>0?1:(dir_tf1+dir_tf2)<0?-1:0;
      bool m1ew,m1ce,m1ie,m1le,m1ae; m1flags(m1ew,m1ce,m1ie,m1le,m1ae);
      bool dirFUactive=(S.frz_activeCount>0&&S.frz_bestDir==S.direction);
      m_die.Update(S,c,htfAlign,dir_tf1,dir_tf2,m1ew,m1ce,m1ie,m1le,m1ae,dirFUactive);
      m_frz.Update(S,o,h,l,c);
      m_curve.Update(S,canon,h,l,c);
      m_time.Update(S,c);
      m_net.Update(S,c);
      ComputeMCE(S,m_e1a.ldir,m_sym);
      if(S.direction!=0 && (S.direction!=m_prevDir || S.recursiveJustFired)){
         m_wrParent=m_wrActive; m_wrActive=m_wrNextId; m_wrNextId++;
         m_wrDepth=S.recursiveJustFired?S.waveDepth:0;
         m_wrRoot=S.recursiveJustFired?(m_wrRoot>0?m_wrRoot:m_wrActive):m_wrActive;
      }
      m_prevDir=S.direction;
      S.wr_activeWaveId=m_wrActive;S.wr_parentWaveId=m_wrParent;S.wr_rootWaveId=m_wrRoot;S.wr_waveDepth=m_wrDepth;
      if(S.ede_state==4 && m_prevEdeState!=4){ m_dwrActive=m_dwrNextId; m_dwrNextId++; }
      m_prevEdeState=S.ede_state; S.dwr_activeId=m_dwrActive;
      ComputeSenseei(S,c);
      m_S=S; return(true);
   }
};

//============================== BODY: RiskManager ===================
class RiskManager
{
private:
   string m_sym;
public:
   void Init(string sym){ m_sym=sym; }
   double LotsFor(double entry,double stop,double riskPct)
   {
      double dist=MathAbs(entry-stop); if(dist<=0) return(0.0);
      double equity=AccountInfoDouble(ACCOUNT_EQUITY); double riskMoney=equity*riskPct/100.0;
      double tickVal=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_VALUE),tickSize=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_SIZE);
      if(tickVal<=0||tickSize<=0) return(0.0); double lossPerLot=dist/tickSize*tickVal; if(lossPerLot<=0) return(0.0);
      double lots=riskMoney/lossPerLot; double minL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN),maxL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MAX),step=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_STEP);
      if(step>0) lots=MathFloor(lots/step)*step; lots=MathMax(minL,MathMin(maxL,lots)); return(lots);
   }
   double OpenRiskPct(long magic)
   {
      double equity=AccountInfoDouble(ACCOUNT_EQUITY); if(equity<=0) return(0); double risk=0;
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue;
         double sl=PositionGetDouble(POSITION_SL); if(sl<=0)continue; double op=PositionGetDouble(POSITION_PRICE_OPEN),vol=PositionGetDouble(POSITION_VOLUME);
         double tickVal=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_VALUE),tickSize=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_SIZE);
         if(tickSize>0) risk+=MathAbs(op-sl)/tickSize*tickVal*vol; }
      return(risk/equity*100.0);
   }
};

//============================== BODY: Portfolio =====================
class Portfolio
{
private:
   string m_sym; double m_dayStartEquity; datetime m_dayStart;
public:
   void Init(string sym){ m_sym=sym;m_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);m_dayStart=0; }
   int OpenCount(long magic){ int n=0; for(int i=PositionsTotal()-1;i>=0;i--){ if(PositionGetTicket(i)==0)continue; if(PositionGetInteger(POSITION_MAGIC)==magic&&PositionGetString(POSITION_SYMBOL)==m_sym)n++; } return(n); }
   void RollDay(){ MqlDateTime dt;TimeToStruct(TimeCurrent(),dt);dt.hour=0;dt.min=0;dt.sec=0;datetime d0=StructToTime(dt); if(d0!=m_dayStart){m_dayStart=d0;m_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);} }
   bool DailyLossHit(){ if(m_dayStartEquity<=0)return(false); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return((m_dayStartEquity-eq)/m_dayStartEquity*100.0>=InpDailyLossCapPct); }
};

//============================== BODY: Executor ======================
class Executor
{
private:
   CTrade m_trade; string m_sym;
public:
   void Init(string sym,long magic,int slippage){ m_sym=sym;m_trade.SetExpertMagicNumber(magic);m_trade.SetDeviationInPoints(slippage);m_trade.SetTypeFillingBySymbol(sym);m_trade.SetAsyncMode(false); }
   bool Open(int dir,double lots,double sl,double tp,string comment)
   { if(lots<=0)return(false); double price=dir==1?SymbolInfoDouble(m_sym,SYMBOL_ASK):SymbolInfoDouble(m_sym,SYMBOL_BID);
     return(dir==1?m_trade.Buy(lots,m_sym,price,sl,tp,comment):m_trade.Sell(lots,m_sym,price,sl,tp,comment)); }
   void CloseAll(long magic){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)!=magic)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; m_trade.PositionClose(tk); } }
   void PartialClose(long magic,double fraction){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)!=magic)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue;
      double vol=PositionGetDouble(POSITION_VOLUME),step=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_STEP),minL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN);
      double cv=step>0?MathFloor(vol*fraction/step)*step:vol*fraction; if(cv>=minL&&(vol-cv)>=minL) m_trade.PositionClosePartial(tk,cv); } }
   void ModifyStop(long magic,double sl,double tp){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)!=magic)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue;
      double cSL=PositionGetDouble(POSITION_SL),cTP=PositionGetDouble(POSITION_TP); double nsl=sl>0?sl:cSL,ntp=tp>0?tp:cTP; if(MathAbs(nsl-cSL)>_Point||MathAbs(ntp-cTP)>_Point) m_trade.PositionModify(tk,nsl,ntp); } }
   int PositionDir(long magic){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)!=magic)continue; if(PositionGetString(POSITION_SYMBOL)!=m_sym)continue; return(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1); } return(0); }
};

//============================== BODY: PositionIntel =================
enum POS_ACTION { POS_HOLD, POS_REDUCE, POS_EXIT, POS_REVERSE };
class PositionIntel
{
public:
   POS_ACTION Decide(const BrainState &S,int posDir)
   {
      if(posDir==0) return(POS_HOLD);
      if(S.action=="MANAGE / EXIT"||S.re_resolutionState=="RESOLVED") return(POS_EXIT);
      if(S.life<=32.0&&S.master!=0&&S.master!=posDir) return(POS_REVERSE);
      if(S.chainScope=="WHOLE CHAIN decaying") return(POS_EXIT);
      if(S.life<45.0||S.narrState=="WEAKENING") return(POS_REDUCE);
      return(POS_HOLD);
   }
};

//============================== BODY: Journal =======================
class Journal
{
private:
   int m_fh; string m_file;
public:
   void Init(string sym)
   {
      m_file="F72Omega_"+sym+"_decisions.csv";
      m_fh=FileOpen(m_file,FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,';');
      if(m_fh!=INVALID_HANDLE){ FileSeek(m_fh,0,SEEK_END);
         if(FileSize(m_fh)==0) FileWrite(m_fh,"time","phase","phaseConf","waveDir","fractalDir","fractalScore","resolution","residual","attractor","life","aliveVerdict","chainScope","master","alignment","conflict","threat","confidence","opportunity","intent","timing","action","doe_bias","doe_action","doe_tradeType","grade","entryLow","entryHigh","stop","tp1","tp2","tp3","erfReadiness","erfGate","modelConf","predReliability","expectedNext","rotState","transferProb","mceHTF","mceAlign","narrative","tqeReady","tqeRisk","rrTP1","expPath","attrConv","decSource"); }
   }
   void Deinit(){ if(m_fh!=INVALID_HANDLE) FileClose(m_fh); }
   void Log(const BrainState &S)
   {
      if(m_fh==INVALID_HANDLE) return;
      FileWrite(m_fh,TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),S.ie1a_currentPhase,DoubleToString(S.ie1a_phaseConfidence,1),(string)S.waveDir,(string)S.fractalStackDir,DoubleToString(S.fractalStackScore,1),S.re_resolutionState,DoubleToString(S.re_residualEnergyScore,1),DoubleToString(S.attractorScore,1),DoubleToString(S.life,1),S.aliveVerdict,S.chainScope,(string)S.master,DoubleToString(S.alignment,1),DoubleToString(S.conflict,1),DoubleToString(S.threat,1),DoubleToString(S.confidence,1),S.opportunity,S.intent,S.timing,S.action,S.doe_bias,S.doe_action,S.doe_tradeType,S.doe_grade,DoubleToString(S.doe_entryLow,_Digits),DoubleToString(S.doe_entryHigh,_Digits),DoubleToString(S.inv_activeStop,_Digits),DoubleToString(S.te_tp1,_Digits),DoubleToString(S.te_tp2,_Digits),DoubleToString(S.te_tp3,_Digits),DoubleToString(S.erf_tradeReadiness,1),(string)S.erf_entryGate,DoubleToString(S.modelConfidence,1),DoubleToString(S.predReliability,1),S.expectedNextPhase,S.rot_state,DoubleToString(S.rot_transferProbability,0),DoubleToString(S.mce_htfAlignmentScore,0),DoubleToString(S.mce_alignmentScore,0),S.ne_dominantNarrative,(string)S.tqe_readiness,S.tqe_riskLevel,DoubleToString(S.te_rr1,2),S.te_expectedPath,(string)S.frz_attractorConvergence,S.trc_decisionSource);
      FileFlush(m_fh);
   }
   void Print(const BrainState &S)
   {
      PrintFormat("[F72] %s pc=%.0f | %s | DOE=%s bias=%s g=%s conf=%.0f | NE=%s | rot=%s/%.0f | mceHTF=%.0f | tqeRisk=%s rr1=%.2f | life=%.0f %s res=%s | stop=%.5f tp1=%.5f tp2=%.5f tp3=%.5f | erf=%.0f gate=%s",
         S.ie1a_currentPhase,S.ie1a_phaseConfidence,S.opportunity,S.doe_action,S.doe_bias,S.doe_grade,S.doe_confidence,S.ne_dominantNarrative,S.rot_state,S.rot_transferProbability,S.mce_htfAlignmentScore,S.tqe_riskLevel,S.te_rr1,S.life,S.aliveVerdict,S.re_resolutionState,S.inv_activeStop,S.te_tp1,S.te_tp2,S.te_tp3,S.erf_tradeReadiness,(S.erf_entryGate?"Y":"N"));
   }
};

//============================== EA ENTRY ============================
Brain         g_brain;
RiskManager   g_risk;
Portfolio     g_port;
Executor      g_exec;
PositionIntel g_posIntel;
Journal       g_journal;
string        g_sym;
int           g_lastEntryBar;
bool          g_scaledTP1;

int OnInit()
{
   g_sym=_Symbol;
   g_brain.Init(g_sym,InpExecTF);
   g_risk.Init(g_sym); g_port.Init(g_sym); g_exec.Init(g_sym,InpMagic,InpSlippagePts); g_journal.Init(g_sym);
   g_lastEntryBar=-100000; g_scaledTP1=false;
   PrintFormat("[F72 OMEGA] init on %s exec=%s trading=%s",g_sym,EnumToString(InpExecTF),(InpEnableTrading?"ON":"OBSERVE"));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ g_journal.Deinit(); }

void OnTick()
{
   g_port.RollDay();
   if(!g_brain.OnNewBar()) return;
   BrainState S=g_brain.State();
   if(InpVerboseJournal) g_journal.Print(S);
   g_journal.Log(S);
   if(!InpEnableTrading) return;

   int posDir=g_exec.PositionDir(InpMagic);
   int barIndex=Bars(g_sym,InpExecTF);

   if(posDir!=0)
   {
      POS_ACTION pa=g_posIntel.Decide(S,posDir);
      if(pa==POS_EXIT){ g_exec.CloseAll(InpMagic); return; }
      if(pa==POS_REVERSE){ g_exec.CloseAll(InpMagic); posDir=0; }
      else
      {
         if(pa==POS_REDUCE && !g_scaledTP1){ g_exec.PartialClose(InpMagic,InpTP1ClosePct/100.0); g_scaledTP1=true; }
         double newSL=!f72_isna(S.inv_activeStop)?S.inv_activeStop:0.0;
         double newTP=!f72_isna(S.te_tp2)?S.te_tp2:0.0;
         g_exec.ModifyStop(InpMagic,newSL,newTP);
         if(InpUseTP1 && !g_scaledTP1 && !f72_isna(S.te_tp1))
         {
            double bid=SymbolInfoDouble(g_sym,SYMBOL_BID),ask=SymbolInfoDouble(g_sym,SYMBOL_ASK);
            bool hitT1=posDir==1?bid>=S.te_tp1:ask<=S.te_tp1;
            if(hitT1){ g_exec.PartialClose(InpMagic,InpTP1ClosePct/100.0); g_scaledTP1=true; }
         }
         return;
      }
   }

   if(g_port.DailyLossHit()) return;
   if(g_port.OpenCount(InpMagic)>=InpMaxPositions) return;
   if(g_risk.OpenRiskPct(InpMagic)>=InpMaxRiskPctTotal) return;
   if(barIndex-g_lastEntryBar<InpBaseLockBars) return;

   int dir=0; if(S.doe_action=="Long")dir=1; if(S.doe_action=="Short")dir=-1;
   if(dir==0) return;
   if(f72_isna(S.inv_activeStop)) return;
   double entry=dir==1?SymbolInfoDouble(g_sym,SYMBOL_ASK):SymbolInfoDouble(g_sym,SYMBOL_BID);
   double stop=S.inv_activeStop;
   if((dir==1&&stop>=entry)||(dir==-1&&stop<=entry)) return;
   double tp=!f72_isna(S.te_tp2)?S.te_tp2:(dir==1?entry+(entry-stop)*2.0:entry-(stop-entry)*2.0);
   double riskPct=InpRiskPctPerTrade*MathMax(0.5,MathMin(1.0,S.doe_confidence/100.0+0.25));
   double lots=g_risk.LotsFor(entry,stop,riskPct);
   if(lots<=0) return;
   string cmt=StringFormat("F72 %s %s g%s c%.0f",S.doe_action,S.intent,S.doe_grade,S.doe_confidence);
   if(g_exec.Open(dir,lots,stop,tp,cmt)){ g_lastEntryBar=barIndex; g_scaledTP1=false;
      PrintFormat("[F72 OMEGA] ENTER %s %.2f @ %.5f sl=%.5f tp=%.5f | %s",(dir==1?"LONG":"SHORT"),lots,entry,stop,tp,cmt); }
}
//+------------------------------------------------------------------+
