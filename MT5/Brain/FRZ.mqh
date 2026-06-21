//+------------------------------------------------------------------+
//|  FRZ.mqh — Future Return Zone Engine (Letra Sections 17/18)       |
//|  4x25pt components, tiers T1-T4, parallel-array registry, Open/   |
//|  Partial/Mitigated/Invalidated lifecycle. F72 best-zone surface.  |
//+------------------------------------------------------------------+
#ifndef F72_FRZ_MQH
#define F72_FRZ_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class FRZEngine
{
private:
   double m_top[],m_bot[]; int m_bar[],m_dir[],m_score[]; string m_tier[],m_status[]; int m_n;
   double m_o[],m_h[],m_l[],m_c[]; int m_nb; int m_barIndex;
   double gO(int b){return(b<m_nb?m_o[b]:F72_NA);} double gC(int b){return(b<m_nb?m_c[b]:F72_NA);}
   double gH(int b){return(b<m_nb?m_h[b]:F72_NA);} double gL(int b){return(b<m_nb?m_l[b]:F72_NA);}
public:
   void Init(){ m_n=0;m_nb=0;m_barIndex=0;
      ArrayResize(m_top,0);ArrayResize(m_bot,0);ArrayResize(m_bar,0);ArrayResize(m_dir,0);ArrayResize(m_score,0);ArrayResize(m_tier,0);ArrayResize(m_status,0);
      ArrayResize(m_o,0);ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0); }
   void pushBar(double o,double h,double l,double c){int keep=10;
      ArrayResize(m_o,m_nb+1);ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);
      for(int i=m_nb;i>0;i--){m_o[i]=m_o[i-1];m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];}
      m_o[0]=o;m_h[0]=h;m_l[0]=l;m_c[0]=c;m_nb++;
      if(m_nb>keep){ArrayResize(m_o,keep);ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);m_nb=keep;} m_barIndex++; }

   void Update(BrainState &S,double o,double h,double l,double c)
   {
      pushBar(o,h,l,c);
      double atr=S.atr;
      double rng=h-l, body=MathAbs(c-o);
      double upW=h-MathMax(o,c), loW=MathMin(o,c)-l;
      // gap-confirmed (prev bar FU)
      double pRng=gH(1)-gL(1); double pBody=MathAbs(gC(1)-gO(1));
      double pUpW=gH(1)-MathMax(gO(1),gC(1)), pLoW=MathMin(gO(1),gC(1))-gL(1);
      double pBodyR=pRng>1e-10?pBody/pRng:0, pUpR=pRng>1e-10?pUpW/pRng:0, pLoR=pRng>1e-10?pLoW/pRng:0;
      bool bearGap = !f72_isna(gC(1)) && o<gC(1)-atr*0.05;
      bool bullGap = !f72_isna(gC(1)) && o>gC(1)+atr*0.05;
      bool isBearFU_prev = pRng>atr*0.5 && pBodyR>=InpFuMinBodyRatio && gC(1)<gO(1) && pUpR>=InpFuMinWickRatio && bearGap;
      bool isBullFU_prev = pRng>atr*0.5 && pBodyR>=InpFuMinBodyRatio && gC(1)>gO(1) && pLoR>=InpFuMinWickRatio && bullGap;
      bool inZone = !f72_isna(S.flipTop)&&!f72_isna(S.flipBot)&&c>=S.flipBot*0.98&&c<=S.flipTop*1.02;
      bool isBullFU = rng>atr*0.5 && (rng>0?body/rng:0)>=InpFuMinBodyRatio && c>o && (rng>0?loW/rng:0)>=InpFuMinWickRatio && inZone;
      bool isBearFU = rng>atr*0.5 && (rng>0?body/rng:0)>=InpFuMinBodyRatio && c<o && (rng>0?upW/rng:0)>=InpFuMinWickRatio && inZone;

      bool hasFU_gc=isBullFU_prev||isBearFU_prev;
      bool hasFU=hasFU_gc||isBullFU||isBearFU;
      bool fuBull=isBullFU_prev||isBullFU, fuBear=isBearFU_prev||isBearFU;
      bool hasImb=S.displacement>InpDispThresh;
      bool hasLiq=S.liqSweepBull||S.liqSweepBear||S.liqVacuum||(S.obs_LiquidityScore>55.0);
      bool hasDisp=S.bullImpulse||S.bearImpulse;
      int raw=(hasFU?25:0)+(hasImb?25:0)+(hasLiq?25:0)+(hasDisp?25:0);
      bool approved = !(S.liqHeat>60 && !(S.liqSweepBull||S.liqSweepBear));
      string tier = raw>=76?"T1": raw>=51?"T2": (raw>=26&&hasFU)?"T3": (raw>=26&&hasImb)?"T4":"-";

      int spawnDir = (S.direction==1||fuBull)&&!(S.direction==-1||fuBear)?1 : (S.direction==-1||fuBear)&&!(S.direction==1||fuBull)?-1 : S.direction!=0?S.direction:0;
      double zTop = spawnDir==1? MathMax(o,c):h;
      double zBot = spawnDir==1? l:MathMin(o,c);
      if(hasFU_gc){ zTop = spawnDir==1? gH(1):MathMax(gO(1),gC(1)); zBot = spawnDir==1? MathMin(gO(1),gC(1)):gL(1); }
      if(zTop<=zBot){ zTop=MathMax(o,MathMax(c,h)); zBot=MathMin(o,MathMin(c,l)); }
      // overlap dedup >50%
      bool overlaps=false;
      for(int i=0;i<m_n;i++){ double oh=MathMin(zTop,m_top[i]),olo=MathMax(zBot,m_bot[i]); double ov=MathMax(0.0,oh-olo); if(ov/MathMax(zTop-zBot,1e-10)>0.5){overlaps=true;break;} }
      bool spawn = approved && raw>=InpFrzMinScore && raw>0 && (hasFU||hasImb) && spawnDir!=0 && !overlaps;
      if(spawn)
      {
         int sz=m_n; ArrayResize(m_top,sz+1);ArrayResize(m_bot,sz+1);ArrayResize(m_bar,sz+1);ArrayResize(m_dir,sz+1);ArrayResize(m_score,sz+1);ArrayResize(m_tier,sz+1);ArrayResize(m_status,sz+1);
         m_top[sz]=zTop;m_bot[sz]=zBot;m_bar[sz]=m_barIndex;m_dir[sz]=spawnDir;m_score[sz]=raw;m_tier[sz]=tier;m_status[sz]="Open"; m_n++;
      }
      // lifecycle (iterate backwards)
      for(int i=m_n-1;i>=0;i--)
      {
         bool terminal=(m_status[i]=="Mitigated"||m_status[i]=="Invalidated");
         int age=m_barIndex-m_bar[i];
         if(!terminal)
         {
            bool wickIn=l<=m_top[i]&&h>=m_bot[i];
            bool closeIn=c>=m_bot[i]&&c<=m_top[i];
            bool invalid=(m_dir[i]==1&&c<m_bot[i]-atr*0.1)||(m_dir[i]==-1&&c>m_top[i]+atr*0.1);
            if(closeIn) m_status[i]="Mitigated"; else if(invalid) m_status[i]="Invalidated"; else if(wickIn&&m_status[i]=="Open") m_status[i]="Partial";
            terminal=(m_status[i]=="Mitigated"||m_status[i]=="Invalidated");
         }
         if(terminal||age>=InpFrzMaxBars)
         {
            for(int j=i;j<m_n-1;j++){m_top[j]=m_top[j+1];m_bot[j]=m_bot[j+1];m_bar[j]=m_bar[j+1];m_dir[j]=m_dir[j+1];m_score[j]=m_score[j+1];m_tier[j]=m_tier[j+1];m_status[j]=m_status[j+1];}
            m_n--; ArrayResize(m_top,m_n);ArrayResize(m_bot,m_n);ArrayResize(m_bar,m_n);ArrayResize(m_dir,m_n);ArrayResize(m_score,m_n);ArrayResize(m_tier,m_n);ArrayResize(m_status,m_n);
         }
      }
      // F72 best-zone surface
      S.frz_activeCount=m_n; int bi=-1; double bs=-1;
      for(int i=0;i<m_n;i++) if(m_score[i]>bs){bs=m_score[i];bi=i;}
      if(bi>=0){ S.frz_bestScore=m_score[bi]; S.frz_bestTier=m_tier[bi]; S.frz_bestStatus=m_status[bi]; S.frz_bestDir=m_dir[bi];
                 S.frz_bestTop=m_top[bi]; S.frz_bestBot=m_bot[bi]; S.frz_distanceToZone=MathAbs(c-(m_top[bi]+m_bot[bi])/2.0)/MathMax(atr,1e-10); }
      else { S.frz_bestScore=0;S.frz_bestTier="-";S.frz_bestStatus="-";S.frz_bestDir=0;S.frz_bestTop=F72_NA;S.frz_bestBot=F72_NA;S.frz_distanceToZone=F72_NA; }
   }
};

#endif // F72_FRZ_MQH
