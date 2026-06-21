//+------------------------------------------------------------------+
//|  Liquidity.mqh — Liquidity Heatmap Engine (Letra Section 10)      |
//|  Weighted, age-decaying density of swept pivots -> liqHeat,       |
//|  liqVacuum, sweeps, liqSweepOK. Stateful (registry of levels).    |
//+------------------------------------------------------------------+
#ifndef F72_LIQUIDITY_MQH
#define F72_LIQUIDITY_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class LiquidityEngine
{
private:
   double m_lvl[]; double m_wt[]; int m_age[];   // parallel registry
   int    m_n;
   double m_h[]; double m_l[]; double m_c[]; double m_vol[]; int m_nb;
   int    m_pvLen;
   double getH(int b){return(b<m_nb?m_h[b]:F72_NA);} 
   double getL(int b){return(b<m_nb?m_l[b]:F72_NA);} 
   double pivotHigh()
   { int L=m_pvLen; if(m_nb<2*L+1) return(F72_NA); double mid=m_h[L];
     for(int i=1;i<=L;i++){ if(m_h[L-i]>=mid||m_h[L+i]>=mid) return(F72_NA);} return(mid);}
   double pivotLow()
   { int L=m_pvLen; if(m_nb<2*L+1) return(F72_NA); double mid=m_l[L];
     for(int i=1;i<=L;i++){ if(m_l[L-i]<=mid||m_l[L+i]<=mid) return(F72_NA);} return(mid);}
public:
   double liqHeat; bool liqVacuum;
   void Init(){ m_pvLen=InpPivotLen; m_n=0; m_nb=0; liqHeat=0; liqVacuum=false;
                ArrayResize(m_lvl,0);ArrayResize(m_wt,0);ArrayResize(m_age,0);
                ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0);ArrayResize(m_vol,0); }
   void pushBar(double h,double l,double c,double v)
   { int keep=MathMax(2*m_pvLen+5,40);
     ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);ArrayResize(m_vol,m_nb+1);
     for(int i=m_nb;i>0;i--){m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];m_vol[i]=m_vol[i-1];}
     m_h[0]=h;m_l[0]=l;m_c[0]=c;m_vol[0]=v;m_nb++;
     if(m_nb>keep){ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);ArrayResize(m_vol,keep);m_nb=keep;} }

   void Update(BrainState &S,double h,double l,double c,double v,double volAvg,int barIndex)
   {
      pushBar(h,l,c,v);
      double atr=S.atr;
      double pH=pivotHigh(), pL=pivotLow();
      double volAtPiv = (m_pvLen<m_nb)? m_vol[m_pvLen] : v;
      double normVol = volAvg>0? volAtPiv/volAvg : 1.0;
      if(!f72_isna(pH)||!f72_isna(pL))
      {
         double lvl = !f72_isna(pH)? pH : pL;
         double swRng = (getH(m_pvLen)-getL(m_pvLen))/MathMax(atr,1e-10);
         int sz=m_n; ArrayResize(m_lvl,sz+1);ArrayResize(m_wt,sz+1);ArrayResize(m_age,sz+1);
         m_lvl[sz]=lvl; m_wt[sz]=normVol*swRng; m_age[sz]=barIndex-m_pvLen; m_n++;
         if(m_n>150){ for(int i=0;i<m_n-1;i++){m_lvl[i]=m_lvl[i+1];m_wt[i]=m_wt[i+1];m_age[i]=m_age[i+1];} m_n--; ArrayResize(m_lvl,m_n);ArrayResize(m_wt,m_n);ArrayResize(m_age,m_n);}
      }
      double wDensity=0,wAbove=0,wBelow=0;
      double rP=atr*InpLiqRadius, rW=atr*InpLiqRadius*3.0;
      for(int i=0;i<m_n;i++)
      {
         int age=barIndex-m_age[i]; double dcy=MathPow(InpLiqAgDecay,age);
         double dist=MathAbs(c-m_lvl[i]);
         if(dist<rP) wDensity+=m_wt[i]*dcy;
         if(dist<rW){ if(m_lvl[i]>c) wAbove+=m_wt[i]*dcy*(1.0-dist/rW); else wBelow+=m_wt[i]*dcy*(1.0-dist/rW); }
      }
      double raw=MathMin((wAbove+wBelow)/2.0,5.0)/5.0*100.0;
      liqHeat=MathMin(MathMax(raw,0.0),100.0); S.liqHeat=liqHeat;
      liqVacuum=(wDensity<0.5); S.liqVacuum=liqVacuum;

      double swH=-DBL_MAX,swL=DBL_MAX; for(int i=0;i<InpLiqSweepLook&&i<m_nb;i++){swH=MathMax(swH,m_h[i]);swL=MathMin(swL,m_l[i]);}
      S.liqSweepBull = !f72_isna(S.flipTop) && swH>S.flipTop;
      S.liqSweepBear = !f72_isna(S.flipBot) && swL<S.flipBot;
      S.liqSweepOK = (!InpRequireLiqSweep) ||
                     (S.direction==1 && (S.liqSweepBull||liqVacuum)) ||
                     (S.direction==-1 && (S.liqSweepBear||liqVacuum));
   }
};

#endif // F72_LIQUIDITY_MQH
