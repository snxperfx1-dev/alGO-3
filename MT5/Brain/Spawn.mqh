//+------------------------------------------------------------------+
//|  Spawn.mqh — Wave Spawn Engine (Letra Section 13 / V60 Section 8) |
//|  Owns the wave context (direction, flip zone, point-4 origin,     |
//|  cycle extremes, entryCycle, waveDepth, recursion). M5-governed.  |
//+------------------------------------------------------------------+
#ifndef F72_SPAWN_MQH
#define F72_SPAWN_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class SpawnEngine
{
private:
   // wave context (var)
   int    m_dir, m_entryCycle, m_waveDepth, m_lastSpawnDir, m_waveGen;
   bool   m_isRecursive, m_recursiveComplete;
   double m_flipTop,m_flipBot,m_p4h,m_p4l,m_cycH,m_cycL;
   double m_fzIP,m_fzL,m_fzH;
   int    m_obBirthBar, m_contBar, m_p4Bar;
   int    m_recursiveFiredBar;
   // exec-TF pivot memory + history
   double m_h[],m_l[],m_c[]; int m_nb; int m_pvLen;
   double m_lastP,m_prevP; int m_lastD,m_prevD; int m_lastPBar,m_prevPBar;
   int    m_barIndex;

   double gH(int b){return(b<m_nb?m_h[b]:F72_NA);} double gL(int b){return(b<m_nb?m_l[b]:F72_NA);}
   double pivotHigh(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_h[L];for(int i=1;i<=L;i++)if(m_h[L-i]>=m||m_h[L+i]>=m)return(F72_NA);return(m);}
   double pivotLow(){int L=m_pvLen;if(m_nb<2*L+1)return(F72_NA);double m=m_l[L];for(int i=1;i<=L;i++)if(m_l[L-i]<=m||m_l[L+i]<=m)return(F72_NA);return(m);}
   double findInducPrice(int anchorRefBar,double top,double bot,int lookback)
   {
      double best=F72_NA,bestDist=F72_NA; int maxI=MathMin(lookback,m_barIndex-anchorRefBar);
      if(maxI>=1) for(int i=1;i<=maxI && i<m_nb;i++)
         if(m_h[i]<top && m_l[i]>bot){ double d=MathAbs((m_barIndex-i)-anchorRefBar); if(f72_isna(bestDist)||d<bestDist){bestDist=d;best=(m_h[i]+m_l[i])/2.0;} }
      return(best);
   }
   void spawnAt(int nd,double atr)
   {
      double top = nd==1? m_lastP : m_prevP;
      double bot = nd==1? m_prevP : m_lastP;
      int anch=m_prevPBar;
      double fzIP=findInducPrice(anch,MathMax(top,bot),MathMin(top,bot),InpInducLookback);
      m_dir=nd; m_flipTop=top; m_flipBot=bot; m_p4h=top; m_p4l=bot;
      m_p4Bar=m_barIndex; m_obBirthBar=m_barIndex; m_contBar=-1;
      m_fzIP=fzIP; m_fzL=!f72_isna(fzIP)?fzIP-atr*InpInducZoneWidth:F72_NA; m_fzH=!f72_isna(fzIP)?fzIP+atr*InpInducZoneWidth:F72_NA;
   }
public:
   void Init(){ m_dir=0;m_entryCycle=0;m_waveDepth=0;m_lastSpawnDir=0;m_waveGen=0;m_isRecursive=false;m_recursiveComplete=false;
                m_flipTop=F72_NA;m_flipBot=F72_NA;m_p4h=F72_NA;m_p4l=F72_NA;m_cycH=F72_NA;m_cycL=F72_NA;
                m_fzIP=F72_NA;m_fzL=F72_NA;m_fzH=F72_NA;m_obBirthBar=-1;m_contBar=-1;m_p4Bar=-1;m_recursiveFiredBar=-100000;
                m_nb=0;m_pvLen=InpPivotLen;m_lastP=F72_NA;m_prevP=F72_NA;m_lastD=0;m_prevD=0;m_lastPBar=-1;m_prevPBar=-1;m_barIndex=0;
                ArrayResize(m_h,0);ArrayResize(m_l,0);ArrayResize(m_c,0); }
   void pushBar(double h,double l,double c){int keep=MathMax(InpInducLookback+5,2*m_pvLen+5);
      ArrayResize(m_h,m_nb+1);ArrayResize(m_l,m_nb+1);ArrayResize(m_c,m_nb+1);
      for(int i=m_nb;i>0;i--){m_h[i]=m_h[i-1];m_l[i]=m_l[i-1];m_c[i]=m_c[i-1];}
      m_h[0]=h;m_l[0]=l;m_c[0]=c;m_nb++;
      if(m_nb>keep){ArrayResize(m_h,keep);ArrayResize(m_l,keep);ArrayResize(m_c,keep);m_nb=keep;} m_barIndex++; }

   void Update(BrainState &S,double o,double h,double l,double c,int l0dir,double l0p4h,double l0p4l,
               bool bullCH,bool bearCH)
   {
      pushBar(h,l,c);
      double atr=S.atr;
      m_recursiveComplete=m_recursiveComplete; // persist
      bool recJustFired=false;

      // pivot memory
      double pH=pivotHigh(),pL=pivotLow();
      double eP=F72_NA;int eD=0;int eBar=m_barIndex-m_pvLen;
      if(!f72_isna(pH)){eP=pH;eD=1;} else if(!f72_isna(pL)){eP=pL;eD=-1;}
      if(eD!=0){m_prevP=m_lastP;m_prevPBar=m_lastPBar;m_prevD=m_lastD;m_lastP=eP;m_lastPBar=eBar;m_lastD=eD;}

      // primary spawn (M5-governed)
      bool allowSpawn = l0dir!=0 && l0dir!=m_dir && !f72_isna(m_lastP) && !f72_isna(m_prevP);
      if(allowSpawn)
      {
         spawnAt(l0dir,atr);
         if(!f72_isna(l0p4h)) { m_flipTop=l0p4h; m_p4h=l0p4h; }
         if(!f72_isna(l0p4l)) { m_flipBot=l0p4l; m_p4l=l0p4l; }
         m_lastSpawnDir=l0dir; m_cycH=h; m_cycL=l; m_isRecursive=false; m_entryCycle=0; m_waveDepth=0;
      }
      if(m_dir==1)  m_cycH=f72_isna(m_cycH)?h:MathMax(m_cycH,h);
      if(m_dir==-1) m_cycL=f72_isna(m_cycL)?l:MathMin(m_cycL,l);

      bool nearFlip = !f72_isna(m_flipTop)&&!f72_isna(m_flipBot)&&c<=m_flipTop*1.02&&c>=m_flipBot*0.98;
      bool closeInside = !f72_isna(m_flipTop)&&c<=m_flipTop&&c>=m_flipBot;

      // recursive trigger
      bool priceInDemand = !f72_isna(m_flipBot)&&l<m_flipBot&&(!f72_isna(m_p4h)&&l<=m_p4h);
      bool priceInSupply = !f72_isna(m_flipTop)&&h>m_flipTop&&(!f72_isna(m_p4l)&&h>=m_p4l);
      bool trueChBull = m_dir==1 && priceInDemand && S.bullImpulse && S.liqSweepOK;
      bool trueChBear = m_dir==-1&& priceInSupply && S.bearImpulse && S.liqSweepOK;
      bool structFlipBull = m_dir==1 && S.bullConvShift && S.structBias==-1;
      bool structFlipBear = m_dir==-1&& S.bearConvShift && S.structBias== 1;
      string p=S.ie1a_currentPhase;
      bool recursiveTrigger = (trueChBull||trueChBear||structFlipBull||structFlipBear) &&
                              (p=="Demand Return"||p=="Supply Return") && S.demandReturnBelief>40 && m_dir!=0 && !f72_isna(m_flipTop);
      if(recursiveTrigger && (m_barIndex-m_recursiveFiredBar)>InpResetBars)
      {
         recJustFired=true; m_recursiveFiredBar=m_barIndex; m_recursiveComplete=true;
         m_waveGen++; m_entryCycle=MathMin(m_entryCycle+1,4); m_isRecursive=true; m_waveDepth=m_entryCycle;
         int nextDir = l0dir!=0? l0dir : ((S.bullImpulse||S.bullConvShift)?1:-1);
         spawnAt(nextDir,atr); m_lastSpawnDir=nextDir; m_dir = l0dir!=0? l0dir : nextDir;
         m_cycH=h; m_cycL=l; m_contBar=m_barIndex;
      }

      // safe reset (hard invalidation or stalled-opposing soft reset, gated by suppressRotation)
      bool bullInvalid = m_dir==1 && c<m_flipBot-atr*0.5;
      bool bearInvalid = m_dir==-1&& c>m_flipTop+atr*0.5;
      bool opposingMove= (m_dir==1&&S.bearImpulse)||(m_dir==-1&&S.bullImpulse);
      int barsSinceCont = m_contBar>=0? m_barIndex-m_contBar : (m_obBirthBar>=0? m_barIndex-m_obBirthBar:0);
      bool hardInvalid=bullInvalid||bearInvalid;
      bool softReset = barsSinceCont>InpResetBars && opposingMove && (p!="Demand Return"&&p!="Supply Return") &&
                       S.demandReturnBelief<30 && S.expansionBelief<30 && !S.erf_suppressRotation;
      if(m_dir!=l0dir && (hardInvalid||softReset))
      {
         m_dir=0;m_lastSpawnDir=0;m_flipTop=F72_NA;m_flipBot=F72_NA;m_contBar=-1;m_obBirthBar=-1;
         m_isRecursive=false;m_entryCycle=0;m_waveDepth=0;m_recursiveComplete=false;
      }

      // publish to state
      S.direction=m_dir; S.entryCycle=m_entryCycle; S.waveDepth=m_waveDepth;
      S.isRecursiveWave=m_isRecursive; S.recursiveComplete=m_recursiveComplete; S.recursiveJustFired=recJustFired;
      S.flipTop=m_flipTop; S.flipBot=m_flipBot; S.point4OriginHigh=m_p4h; S.point4OriginLow=m_p4l;
      S.cycleHigh=m_cycH; S.cycleLow=m_cycL; S.inducZoneLow=m_fzL; S.inducZoneHigh=m_fzH; S.closeInside=closeInside;

      // geometry helpers consumed by WaveIntel/Senseei
      if(!f72_isna(m_p4h)&&!f72_isna(m_p4l)){ double org=m_dir==1?m_p4l:m_p4h; double ext=m_dir==1?f72_nz(m_cycH,org):f72_nz(m_cycL,org); S.originToExtreme=MathAbs(ext-org);} else S.originToExtreme=F72_NA;
      S.flipzoneWidth=(!f72_isna(m_flipTop)&&!f72_isna(m_flipBot))?m_flipTop-m_flipBot:F72_NA;
      if(!f72_isna(m_flipTop)&&!f72_isna(m_flipBot)){double fzMid=(m_flipTop+m_flipBot)/2.0;S.availableSpace=MathMin(MathAbs(c-fzMid)/MathMax(atr*4.0,1e-10)*100.0,100.0);} else S.availableSpace=F72_NA;
   }
};

#endif // F72_SPAWN_MQH
