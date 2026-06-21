//+------------------------------------------------------------------+
//|  Network.mqh — Invisible Network Engine (V60 Part A)              |
//|  Cross-TF FU rejection-wick node registry, authority, netBias,    |
//|  node pressure (pdir). Feeds Senseei votes vt3 (netBias) & vt4.   |
//+------------------------------------------------------------------+
#ifndef F72_NETWORK_MQH
#define F72_NETWORK_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class NetworkEngine
{
private:
   string m_sym;
   // node registry
   double m_px[]; int m_dir[]; double m_sc[]; int m_wt[]; int m_state[]; int m_bar[]; int m_rev[]; int m_n;
   int    m_barIndex;
   double m_lastTip[7];      // dedup per TF weight slot
   ENUM_TIMEFRAMES m_tf[7]; int m_wtv[7];

   // f_fuPool: detect a confirmed FU rejection node on the last CLOSED bar of tf
   bool detect(ENUM_TIMEFRAMES tf,double wf,int lb,double &tip,double &mid,int &dir,double &score)
   {
      int need=lb+2; MqlRates r[]; if(CopyRates(m_sym,tf,1,need,r)<need) return(false);
      // r is series: index 0 = oldest of the copied window. Reorder: we want bar [1]=most recent closed.
      int n=ArraySize(r); double H=r[n-1].high,L=r[n-1].low,O=r[n-1].open,C=r[n-1].close;
      double rng=MathMax(H-L,1e-10);
      double pHi=-DBL_MAX,pLo=DBL_MAX; for(int i=n-1-lb;i<n-1;i++){ if(i>=0){pHi=MathMax(pHi,r[i].high);pLo=MathMin(pLo,r[i].low);} }
      double uw=(H-MathMax(O,C))/rng, lw=(MathMin(O,C)-L)/rng;
      bool localTop=true,localBot=true; for(int i=n-1-lb;i<n-1;i++){ if(i>=0){ if(r[i].high>H)localTop=false; if(r[i].low<L)localBot=false; } }
      bool bear=uw>=wf && ((H>=pHi&&C<pHi)||(localTop&&C<O));
      bool bull=lw>=wf && ((L<=pLo&&C>pLo)||(localBot&&C>O));
      double atr=0; for(int i=1;i<n;i++) atr+=MathAbs(r[i].close-r[i-1].close); atr=MathMax(atr/MathMax(n-1,1),1e-10);
      if(bear){ dir=-1; tip=H; double bH=MathMax(O,C); mid=bH+(tip-bH)*0.5; double wk=(tip-bH)/atr; score=20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0); return(true);}
      if(bull){ dir=1;  tip=L; double bL=MathMin(O,C); mid=tip+(bL-tip)*0.5; double wk=(bL-tip)/atr; score=20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0); return(true);}
      return(false);
   }
   double authority(int i){ return(m_sc[i]+m_wt[i]*4.0+m_rev[i]*3.0); }
   void addNode(double px,int dir,double sc,int wt)
   {
      int sz=m_n; ArrayResize(m_px,sz+1);ArrayResize(m_dir,sz+1);ArrayResize(m_sc,sz+1);ArrayResize(m_wt,sz+1);ArrayResize(m_state,sz+1);ArrayResize(m_bar,sz+1);ArrayResize(m_rev,sz+1);
      m_px[sz]=px;m_dir[sz]=dir;m_sc[sz]=sc;m_wt[sz]=wt;m_state[sz]=0;m_bar[sz]=m_barIndex;m_rev[sz]=0;m_n++;
      if(m_n>InpNodeMax){ for(int j=0;j<m_n-1;j++){m_px[j]=m_px[j+1];m_dir[j]=m_dir[j+1];m_sc[j]=m_sc[j+1];m_wt[j]=m_wt[j+1];m_state[j]=m_state[j+1];m_bar[j]=m_bar[j+1];m_rev[j]=m_rev[j+1];}
                          m_n--; ArrayResize(m_px,m_n);ArrayResize(m_dir,m_n);ArrayResize(m_sc,m_n);ArrayResize(m_wt,m_n);ArrayResize(m_state,m_n);ArrayResize(m_bar,m_n);ArrayResize(m_rev,m_n);}
   }
public:
   void Init(string sym){ m_sym=sym; m_n=0; m_barIndex=0;
      ENUM_TIMEFRAMES tfs[7]={PERIOD_MN1,PERIOD_W1,PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M15,PERIOD_M5};
      int wts[7]={9,8,7,6,5,4,3};
      for(int i=0;i<7;i++){ m_tf[i]=tfs[i]; m_wtv[i]=wts[i]; m_lastTip[i]=F72_NA; } }

   void Update(BrainState &S,double close)
   {
      m_barIndex++;
      int netBias=0;
      for(int i=0;i<7;i++)
      {
         double tip,mid,sc; int dir;
         if(detect(m_tf[i],InpWickFrac,InpFuStructLook,tip,mid,dir,sc))
         {
            if(netBias==0) netBias=dir;
            if(f72_isna(m_lastTip[i])||MathAbs(tip-m_lastTip[i])>_Point){ addNode(tip,dir,sc,m_wtv[i]); m_lastTip[i]=tip; }
         }
      }
      double ema50=iClose(m_sym,_Period,0); // fallback bias
      if(netBias==0){ double e=0; MqlRates r[]; if(CopyRates(m_sym,_Period,1,50,r)>=50){ for(int i=0;i<50;i++)e+=r[i].close; e/=50.0; ema50=e; } netBias=close>ema50?1:close<ema50?-1:0; }
      S.netBias=netBias;

      // update node states + tally authority
      double atr=S.atr; double bullAuth=0,bearAuth=0; int elig=0;
      for(int i=0;i<m_n;i++)
      {
         if(m_state[i]!=2)
         {
            double np=m_px[i]; int nd=m_dir[i];
            if(nd==-1? close>np : close<np) m_state[i]=2;     // consumed
            else { if(MathAbs(close-np)<atr*0.25) m_rev[i]++; }
         }
         if(m_state[i]!=2 && authority(i)>=InpAuthMin)
         {
            elig++; if(m_dir[i]==1) bullAuth+=authority(i); else bearAuth+=authority(i);
         }
      }
      S.eligNodes=elig;
      S.netPressure=(bullAuth+bearAuth)>0? (bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0.0;
      S.pdir = S.netPressure>12?1: S.netPressure<-12?-1:0;
   }
};

#endif // F72_NETWORK_MQH
