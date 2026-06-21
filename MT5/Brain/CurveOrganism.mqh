//+------------------------------------------------------------------+
//|  CurveOrganism.mqh — F72 Curve / Life / Compression Persistence / |
//|  Narrative Lineage / Chain Vitality (V60). "Is the trade alive?"  |
//+------------------------------------------------------------------+
#ifndef F72_CURVE_MQH
#define F72_CURVE_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

class CurveOrganism
{
private:
   double m_compHist[6]; int m_ch;
   double m_wholeChainLife;
   int    m_narrDir; double m_legX, m_legPBdepth, m_narrative;
   double m_lifeSeq[]; int m_lifeN;
public:
   void Init(){ ArrayInitialize(m_compHist,0); m_ch=0; m_wholeChainLife=50.0; m_narrDir=0; m_legX=F72_NA; m_legPBdepth=0; m_narrative=50.0; m_lifeN=0; ArrayResize(m_lifeSeq,0); }

   void Update(BrainState &S,const SE_Out &canon,double high,double low,double close)
   {
      double cmpNow=f72_nz(canon.compIdx,0.0);
      double eRes=S.re_residualEnergyScore;
      int ownDir=S.waveDir;
      double ownOrig=canon.inv;
      double ownExt = ownDir==1? f72_nz(S.cycleHigh,high): ownDir==-1? f72_nz(S.cycleLow,low): close;
      double cmp5=m_compHist[5];
      double cmpTighten=cmpNow-cmp5;
      int treeDepth=S.waveDepth;
      int budget=(int)MathMax(1,MathMin(4,1+MathRound(cmpNow/33.0)));
      bool recursionComplete=(budget>0 && treeDepth>=budget);
      bool attacking = ownDir==1? high>=f72_nz(ownExt,high): ownDir==-1? low<=f72_nz(ownExt,low):false;
      bool trendImp = (ownDir==1&&S.bullImpulse)||(ownDir==-1&&S.bearImpulse);
      bool progressing=attacking||trendImp;
      double retrX = (f72_isna(ownExt)||f72_isna(ownOrig)||ownExt==ownOrig)?50.0:MathMin(100.0,MathAbs(ownExt-close)/MathAbs(ownExt-ownOrig)*100.0);

      double cpForce=MathMax(0.0,MathMin(100.0,cmpNow*0.50+eRes*0.20-treeDepth*12.0+MathMax(0.0,cmpTighten)*0.8+8.0));
      string cpState=cpForce>=60.0?"PERSISTING":cpForce<=35.0?"LEAKING":"NEUTRAL";
      double life=MathMax(0.0,MathMin(100.0, cpForce*0.45+eRes*0.30+(cmpTighten>0.0?12.0:0.0)
                  -(recursionComplete&&!progressing?25.0:0.0)-(cpState=="LEAKING"&&!progressing?20.0:0.0)
                  +(progressing?28.0:0.0)+(retrX<25.0?16.0:retrX<45.0?6.0:retrX>75.0?-12.0:0.0)+10.0));

      // narrative lineage
      if(ownDir!=m_narrDir){ m_narrDir=ownDir; m_legX=ownDir==1?high:ownDir==-1?low:F72_NA; m_legPBdepth=0; m_narrative=50.0; m_lifeN=0; ArrayResize(m_lifeSeq,0); }
      if(ownDir!=0 && !f72_isna(ownOrig))
      {
         bool newLegX = ownDir==1? high>f72_nz(m_legX,high): low<f72_nz(m_legX,low);
         if(newLegX)
         {
            if(m_legPBdepth>6.0)
            {
               bool sup=m_legPBdepth<=50.0&&cmpTighten>=-1.0;
               bool deg=m_legPBdepth>=62.0||cmpTighten<-3.0;
               int vote=sup?1:deg?-1:0;
               m_narrative=MathMax(0.0,MathMin(100.0,m_narrative+vote*12.0+(cmpTighten>0.0?3.0:-3.0)));
               int sz=m_lifeN; ArrayResize(m_lifeSeq,sz+1); m_lifeSeq[sz]=life; m_lifeN++;
               if(m_lifeN>5){ for(int i=0;i<m_lifeN-1;i++) m_lifeSeq[i]=m_lifeSeq[i+1]; m_lifeN--; ArrayResize(m_lifeSeq,m_lifeN); }
            }
            m_legX=ownDir==1?high:low; m_legPBdepth=0;
         }
         else
         {
            double pbd=MathAbs(f72_nz(m_legX,close)-ownOrig)>1e-9?MathAbs(f72_nz(m_legX,close)-close)/MathAbs(f72_nz(m_legX,close)-ownOrig)*100.0:0.0;
            m_legPBdepth=MathMax(m_legPBdepth,pbd);
         }
      }
      string narrState=m_narrative>=65.0?"STRENGTHENING":m_narrative<=35.0?"WEAKENING":"HOLDING";

      // chain vitality
      m_wholeChainLife=m_wholeChainLife+0.02*(life-m_wholeChainLife);
      double chainVitality = m_lifeN>=2? MathMax(0.0,MathMin(100.0,50.0+(m_lifeSeq[m_lifeN-1]-m_lifeSeq[0]))) : m_wholeChainLife;
      string chainScope = life>=50.0?"healthy": chainVitality>=50.0?"CURVE only - chain intact": m_wholeChainLife>=45.0?"CHAIN weakening":"WHOLE CHAIN decaying";
      string aliveVerdict = (progressing&&life>=45.0)?"ALIVE - ATTACKING": life>=60.0?"ALIVE - HOLD": life<=32.0?"DEAD - FLIP": "WEAKENING - MANAGE";

      // publish
      S.ownerDir=ownDir; S.treeDepth=treeDepth; S.life=life; S.cpForce=cpForce; S.cpState=cpState;
      S.gCompress=cmpNow; S.gResidual=eRes; S.narrative=m_narrative; S.narrState=narrState;
      S.chainVitality=chainVitality; S.wholeChainLife=m_wholeChainLife; S.chainScope=chainScope; S.aliveVerdict=aliveVerdict;

      // shift compression history
      for(int i=5;i>0;i--) m_compHist[i]=m_compHist[i-1]; m_compHist[0]=cmpNow;
   }
};

#endif // F72_CURVE_MQH
