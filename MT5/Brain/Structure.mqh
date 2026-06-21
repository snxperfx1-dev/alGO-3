//+------------------------------------------------------------------+
//|  Structure.mqh — f_phys + f_se (THE sole lifecycle authority)     |
//|  Verbatim port of Letra/V60 f_phys physics primitives and the     |
//|  f_se fixed-TF structure engine + 14-phase state machine.         |
//|  One instance per fixed timeframe rung. Fed one CLOSED bar at a    |
//|  time via ProcessNewBar() in chronological order (Pine `var`       |
//|  per-bar semantics replicated with persistent class members).      |
//+------------------------------------------------------------------+
#ifndef F72_STRUCTURE_MQH
#define F72_STRUCTURE_MQH

#include "Params.mqh"

#define F72_NA  (EMPTY_VALUE)   // sentinel for "na"
bool   f72_isna(double v){ return(v==F72_NA || v>=EMPTY_VALUE*0.999 || !MathIsValidNumber(v)); }
double f72_nz(double v,double rep){ return(f72_isna(v)?rep:v); }

//--- Canonical phase code -> name (f_phaseStr, verbatim) -------------
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

//--- Output snapshot (mirrors the 21 f_se exports) -------------------
struct SE_Out
{
   int    dir;        // origin-based wave direction (_dirLabel)
   int    phase;      // dir-adjusted phase code (1..14)
   double curSH, curSL, prSH, prSL;
   int    bos;        // +1 bull / -1 bear / 0
   int    ch;         // +1 bull / -1 bear / 0  (CHoCH)
   double p4h, p4l;   // point-4 origin
   double inv;        // invalidation (origin)
   double tgt;        // projected target
   double ft, fb;     // flip-zone top/bottom
   double frzS;       // future-return-zone seed score
   double wp;         // wave progress 0..100
   double cm;         // convexity score 0..100
   double mf;         // model fit 0..100
   double compIdx;    // compression index 0..100
   int    recBrk;     // recursive Phase-2 CHoCH count
   double recDom;     // dominance transfer 0..100
   // physics primitives (exposed for the canonical observation layer)
   double atr, vel, acc, convSmooth, eff, disp;
   bool   bullImp, bearImp, bullDec, bearDec, bullCS, bearCS, vd70, vd50;
};

//+------------------------------------------------------------------+
class StructureEngine
{
private:
   // --- physics persistent state ---
   double m_atr;            bool m_atrInit;
   double m_velEma;         bool m_velInit;
   double m_prevVel, m_prevAcc, m_prevConv;
   double m_convSmEma;      bool m_convInit;
   double m_prevConvSm;
   // close/high/low ring buffers
   double m_close[];        // newest at index 0..  (we use push-back arrays)
   double m_high[];
   double m_low[];
   int    m_nbars;
   // --- structure persistent state (f_se vars) ---
   double m_curSH, m_curSL, m_prSH, m_prSL;
   double m_lastP, m_prevP; int m_lastD, m_prevD;
   int    m_dir;
   double m_ft, m_fb, m_p4h, m_p4l, m_inv, m_tgt, m_cycH, m_cycL;
   bool   m_bos1, m_bos2; double m_protSw, m_protSw2, m_indOrig, m_indExt; bool m_indBrk;
   int    m_lastDirSeen;
   int    m_recBrk; bool m_recArm;
   int    m_pst;

   int    m_pvLen;
   double m_convMult, m_effThresh, m_dispThresh, m_impMult, m_chBuf;
   int    m_effLen, m_atrLen;

   double getC(int back){ return( back<m_nbars ? m_close[back] : F72_NA ); }
   double getH(int back){ return( back<m_nbars ? m_high[back]  : F72_NA ); }
   double getL(int back){ return( back<m_nbars ? m_low[back]   : F72_NA ); }

   // ta.highest/lowest over window using the buffers (back 0 = current)
   double highest(int len)
   {
      double mx=-DBL_MAX; for(int i=0;i<len && i<m_nbars;i++) mx=MathMax(mx,m_high[i]); return(mx);
   }
   double lowest(int len)
   {
      double mn=DBL_MAX; for(int i=0;i<len && i<m_nbars;i++) mn=MathMin(mn,m_low[i]); return(mn);
   }
   // pivot high confirmed _pvLen bars back (strict max of 2*len+1 window)
   double pivotHigh()
   {
      int L=m_pvLen; if(m_nbars < 2*L+1) return(F72_NA);
      double mid=m_high[L];
      for(int i=1;i<=L;i++){ if(m_high[L-i]>=mid) return(F72_NA); if(m_high[L+i]>=mid) return(F72_NA); }
      return(mid);
   }
   double pivotLow()
   {
      int L=m_pvLen; if(m_nbars < 2*L+1) return(F72_NA);
      double mid=m_low[L];
      for(int i=1;i<=L;i++){ if(m_low[L-i]<=mid) return(F72_NA); if(m_low[L+i]<=mid) return(F72_NA); }
      return(mid);
   }

public:
   void Init(int pvLen,int effLen,int atrLen,double effT,double dispT,double convM,double impM,double chBuf)
   {
      m_pvLen=pvLen; m_effLen=effLen; m_atrLen=atrLen;
      m_effThresh=effT; m_dispThresh=dispT; m_convMult=convM; m_impMult=impM; m_chBuf=chBuf;
      m_atrInit=false; m_velInit=false; m_convInit=false;
      m_prevVel=0; m_prevAcc=0; m_prevConv=0; m_prevConvSm=0; m_velEma=0; m_convSmEma=0; m_atr=0;
      m_nbars=0; ArrayResize(m_close,0); ArrayResize(m_high,0); ArrayResize(m_low,0);
      m_curSH=F72_NA; m_curSL=F72_NA; m_prSH=F72_NA; m_prSL=F72_NA;
      m_lastP=F72_NA; m_prevP=F72_NA; m_lastD=0; m_prevD=0;
      m_dir=0; m_ft=F72_NA; m_fb=F72_NA; m_p4h=F72_NA; m_p4l=F72_NA; m_inv=F72_NA; m_tgt=F72_NA;
      m_cycH=F72_NA; m_cycL=F72_NA;
      m_bos1=false; m_bos2=false; m_protSw=F72_NA; m_protSw2=F72_NA; m_indOrig=F72_NA; m_indExt=F72_NA; m_indBrk=false;
      m_lastDirSeen=0; m_recBrk=0; m_recArm=true; m_pst=0;
   }

   // Push one closed bar (chronological). Maintains a trimmed history.
   void pushBar(double o,double h,double l,double c)
   {
      // shift: index 0 = current (newest)
      int keep=MathMax(2*m_pvLen+5, m_effLen+3); keep=MathMax(keep,40);
      ArrayResize(m_close,m_nbars+1); ArrayResize(m_high,m_nbars+1); ArrayResize(m_low,m_nbars+1);
      for(int i=m_nbars;i>0;i--){ m_close[i]=m_close[i-1]; m_high[i]=m_high[i-1]; m_low[i]=m_low[i-1]; }
      m_close[0]=c; m_high[0]=h; m_low[0]=l; m_nbars++;
      if(m_nbars>keep){ ArrayResize(m_close,keep); ArrayResize(m_high,keep); ArrayResize(m_low,keep); m_nbars=keep; }
   }

   void ProcessNewBar(double o,double h,double l,double c,SE_Out &out)
   {
      pushBar(o,h,l,c);

      // ---------------- PHYSICS (f_phys, verbatim) ----------------
      double tr;
      double prevC=getC(1);
      if(f72_isna(prevC)) tr=h-l; else tr=MathMax(h-l,MathMax(MathAbs(h-prevC),MathAbs(l-prevC)));
      if(!m_atrInit){ m_atr=h-l; m_atrInit=true; }
      else m_atr=(m_atr*(m_atrLen-1)+tr)/m_atrLen;       // Wilder RMA (ta.atr)
      double diff = f72_isna(prevC)? 0.0 : c-prevC;
      if(!m_velInit){ m_velEma=diff; m_velInit=true; } else m_velEma=m_velEma+0.5*(diff-m_velEma); // ema len3
      double vel=m_velEma;
      double acc=vel-m_prevVel;
      double conv=acc-m_prevAcc;
      if(!m_convInit){ m_convSmEma=conv; m_convInit=true; } else m_convSmEma=m_convSmEma+0.5*(conv-m_convSmEma);
      double csm=m_convSmEma;
      // efficiency
      double cE=getC(m_effLen);
      double mv = f72_isna(cE)? 0.0 : MathAbs(c-cE);
      double ps=0; for(int i=0;i<m_effLen;i++){ double a=getC(i), b=getC(i+1); if(!f72_isna(a)&&!f72_isna(b)) ps+=MathAbs(a-b); }
      double eff = ps>0? mv/ps : 0.0;
      double disp=(h-l)/MathMax(m_atr,1e-10);
      double cth=m_atr*m_convMult;
      bool bImp = eff>m_effThresh && vel>m_prevVel && acc>0 && c>o && disp>m_dispThresh;
      bool rImp = eff>m_effThresh && vel<m_prevVel && acc<0 && c<o && disp>m_dispThresh;
      bool bDec = MathAbs(acc)<MathAbs(m_prevAcc)*0.8 && vel>0;
      bool rDec = MathAbs(acc)<MathAbs(m_prevAcc)*0.8 && vel<0;
      bool bCS  = csm> cth && m_prevConvSm<= cth;
      bool rCS  = csm<-cth && m_prevConvSm>=-cth;
      bool vd70 = MathAbs(vel)<MathAbs(m_prevVel)*0.7;
      bool vd50 = MathAbs(vel)<MathAbs(m_prevVel)*0.5;

      // ---------------- STRUCTURE (f_se, verbatim) ----------------
      double pH=pivotHigh();
      double pL=pivotLow();
      if(!f72_isna(pH)){ m_prSH = f72_isna(m_curSH)? pH : m_curSH; m_curSH=pH; }
      if(!f72_isna(pL)){ m_prSL = f72_isna(m_curSL)? pL : m_curSL; m_curSL=pL; }
      // pivot memory for OB origin
      double eP=F72_NA; int eD=0;
      if(!f72_isna(pH)){ eP=pH; eD=1; } else if(!f72_isna(pL)){ eP=pL; eD=-1; }
      if(eD!=0){ m_prevP=m_lastP; m_prevD=m_lastD; m_lastP=eP; m_lastD=eD; }

      bool bullBOS = !f72_isna(m_prSH) && c>m_prSH;
      bool bearBOS = !f72_isna(m_prSL) && c<m_prSL;
      bool bullCH  = !f72_isna(m_prSH) && c>m_prSH+m_atr*m_chBuf;
      bool bearCH  = !f72_isna(m_prSL) && c<m_prSL-m_atr*m_chBuf;
      bool eLong  = !f72_isna(pH) && m_prevD==-1 && (pH-m_prevP)>m_atr*m_impMult;
      bool eShort = !f72_isna(pL) && m_prevD== 1 && (m_prevP-pL)>m_atr*m_impMult;

      bool hasCtx = m_dir!=0 && !f72_isna(m_ft);
      bool flipDn = m_dir==1  && bearCH;
      bool flipUp = m_dir==-1 && bullCH;
      bool isRev  = (eLong&&m_dir==-1)||(eShort&&m_dir==1)||flipUp||flipDn;
      bool spawn  = (eLong||eShort||flipUp||flipDn) && (!hasCtx||isRev);
      if(spawn)
      {
         int nd = eLong?1: eShort?-1: flipUp?1:-1;
         double hi=MathMax(m_lastP,m_prevP), lo=MathMin(m_lastP,m_prevP);
         m_dir=nd; m_ft=hi; m_fb=lo; m_p4h=hi; m_p4l=lo; m_cycH=h; m_cycL=l;
         m_inv = nd==1? lo : hi;
         double rng = (!f72_isna(m_prSH)&&!f72_isna(m_prSL))? MathAbs(m_prSH-m_prSL) : m_atr*5.0;
         m_tgt = nd==1? f72_nz(hi,c)+rng : f72_nz(lo,c)-rng;
      }
      if(m_dir==1)  m_cycH = f72_isna(m_cycH)? h : MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL = f72_isna(m_cycL)? l : MathMin(m_cycL,l);

      int bosOut = bullBOS?1: bearBOS?-1:0;
      int chOut  = bullCH?1: bearCH?-1:0;

      bool rst = (m_dir!=m_lastDirSeen);
      m_lastDirSeen=m_dir;
      if(rst){ m_bos1=false; m_bos2=false; m_protSw=F72_NA; m_protSw2=F72_NA; m_indOrig=F72_NA; m_indExt=F72_NA; m_indBrk=false; }
      if(m_dir==1  && !f72_isna(pL)){ m_protSw2=m_protSw; m_protSw=pL; }
      if(m_dir==-1 && !f72_isna(pH)){ m_protSw2=m_protSw; m_protSw=pH; }
      bool oppBOS = (m_dir==1 && !f72_isna(m_protSw) && c<m_protSw) || (m_dir==-1 && !f72_isna(m_protSw) && c>m_protSw);
      if(!m_bos1 && oppBOS){ m_bos1=true; m_indOrig = m_dir==1? f72_nz(m_cycH,h) : f72_nz(m_cycL,l); }
      if(m_bos1 && !m_bos2 && oppBOS && !f72_isna(m_protSw2) && (m_dir==1? c<m_protSw2 : c>m_protSw2)) m_bos2=true;
      if(m_bos1 && m_dir==1)  m_indExt = f72_isna(m_indExt)? c : MathMin(m_indExt,c);
      if(m_bos1 && m_dir==-1) m_indExt = f72_isna(m_indExt)? c : MathMax(m_indExt,c);
      if(m_bos2 && !f72_isna(m_indOrig))
      {
         if(m_dir==1  && c>m_indOrig) m_indBrk=true;
         if(m_dir==-1 && c<m_indOrig) m_indBrk=true;
      }

      double convScore=MathMin(MathAbs(csm)/MathMax(m_atr*m_convMult,1e-10)*50.0,100.0);
      double expScore =MathMin(eff/MathMax(m_effThresh,1e-10)*50.0 + disp/MathMax(m_dispThresh,1e-10)*50.0,100.0);
      double absScore =(eff<m_effThresh*0.7 && MathAbs(vel)<MathAbs(m_prevVel)*0.6)? 60.0+convScore*0.4 : convScore*0.3;
      bool momExpStrong = eff>m_effThresh*0.75 && (m_dir==1? vel>0 : vel<0);
      bool momDecaying  = m_dir==1? bDec : rDec;
      bool momCounter   = m_dir==1? rImp : bImp;
      bool momExhaust   = eff<m_effThresh*0.65 && absScore>40.0;
      bool physConvexDevel = convScore>35.0;
      bool physTransfer    = convScore>48.0 || absScore>40.0;
      bool physCapacityLow = absScore>45.0 || eff<m_effThresh*0.6;

      int wdir = !f72_isna(m_inv)? (c>m_inv?1: c<m_inv?-1:m_dir) : m_dir;
      bool atFlip = !f72_isna(m_ft)&&!f72_isna(m_fb)&&c<=m_ft&&c>=m_fb;
      bool expanding = momExpStrong||eLong||eShort||(wdir==1? bImp:rImp);
      bool atExtreme = wdir==1? h>=f72_nz(m_cycH,h) : wdir==-1? l<=f72_nz(m_cycL,l) : false;
      double extr = wdir==1? f72_nz(m_cycH,c) : f72_nz(m_cycL,c);
      bool extended = !f72_isna(m_inv) && MathAbs(extr-m_inv)>m_atr*1.5;
      double fzMid = (!f72_isna(m_ft)&&!f72_isna(m_fb))? (m_ft+m_fb)/2.0 : F72_NA;
      double retrFrac = (!f72_isna(fzMid)&&MathAbs(extr-fzMid)>1e-10)? MathAbs(extr-c)/MathAbs(extr-fzMid) : 0.0;
      double compIdx = MathMin(100.0,MathMax(0.0,(1.0-MathMin(disp/MathMax(m_dispThresh,1e-10),1.0))*60.0 + (1.0-MathMin(eff/MathMax(m_effThresh,1e-10),1.0))*40.0));

      bool phase2CH = (m_dir==1&&bearCH)||(m_dir==-1&&bullCH);
      if(rst || (atExtreme&&extended)){ m_recBrk=0; m_recArm=true; }
      if((m_dir==1&&!f72_isna(pH))||(m_dir==-1&&!f72_isna(pL))) m_recArm=true;
      if((phase2CH||oppBOS)&&m_recArm&&!atExtreme){ m_recBrk++; m_recArm=false; }
      double recDom=MathMin(100.0,MathMax(m_recBrk*(30.0-compIdx*0.15),retrFrac*80.0));
      bool transferDone = recDom>=50.0;

      if(rst) m_pst=0;
      if(m_dir!=0 && !rst)
      {
         if(m_pst==0 && expanding) m_pst=1;
         if(m_pst==1 && !atExtreme && momDecaying && physConvexDevel) m_pst=2;
         if(m_pst==2 && !atExtreme && momCounter && physTransfer) m_pst=3;
         if(m_pst==3 && !atExtreme && (m_bos1||m_bos2||m_indBrk) && physTransfer) m_pst=4;
         if(m_pst>=1 && m_pst<=7 && atExtreme && extended) m_pst=5;
         if(m_pst==5 && !atExtreme && (m_recBrk>=1||momExhaust)) m_pst=7;
         if(m_pst==7 && transferDone) m_pst=8;
         if(m_pst==8 && atFlip) m_pst=9;
         if(m_pst==9 && ((m_dir==1&&bImp)||(m_dir==-1&&rImp))) m_pst=10;
         if(m_pst==10 && (oppBOS||physCapacityLow)) m_pst=11;
         if(m_pst==11 && ((m_dir==1&&l<m_fb)||(m_dir==-1&&h>m_ft))) m_pst=12;
         if(m_pst==12 && ((m_dir==1&&bullCH)||(m_dir==-1&&bearCH))) m_pst=13;
      }
      int phase=m_pst;
      if(phase==5 && m_dir==-1) phase=6;
      if(phase==13 && m_dir==-1) phase=14;
      double wp = m_pst==0?5.0: m_pst==1?15.0: m_pst==2?25.0: m_pst==3?33.0: m_pst==4?42.0: m_pst==5?55.0: m_pst==7?65.0: m_pst==8?75.0: m_pst==9?85.0: m_pst==10?90.0: m_pst==11?94.0: m_pst==12?97.0:100.0;
      double cm=MathMin(convScore,100.0);
      double mf=MathMin(MathMax(expScore,MathMax(absScore,convScore))*0.70 + (m_dir!=0?30.0:0.0),100.0);
      double frzS=MathMin((eLong||eShort?50.0:0.0)+expScore*0.30+convScore*0.20,100.0);

      // ---- commit physics history for next bar ----
      m_prevVel=vel; m_prevAcc=acc; m_prevConv=conv; m_prevConvSm=csm;

      // ---- fill output ----
      out.dir=wdir; out.phase=phase;
      out.curSH=m_curSH; out.curSL=m_curSL; out.prSH=m_prSH; out.prSL=m_prSL;
      out.bos=bosOut; out.ch=chOut; out.p4h=m_p4h; out.p4l=m_p4l; out.inv=m_inv; out.tgt=m_tgt;
      out.ft=m_ft; out.fb=m_fb; out.frzS=frzS; out.wp=wp; out.cm=cm; out.mf=mf;
      out.compIdx=compIdx; out.recBrk=m_recBrk; out.recDom=recDom;
      out.atr=m_atr; out.vel=vel; out.acc=acc; out.convSmooth=csm; out.eff=eff; out.disp=disp;
      out.bullImp=bImp; out.bearImp=rImp; out.bullDec=bDec; out.bearDec=rDec;
      out.bullCS=bCS; out.bearCS=rCS; out.vd70=vd70; out.vd50=vd50;
   }
};

#endif // F72_STRUCTURE_MQH
