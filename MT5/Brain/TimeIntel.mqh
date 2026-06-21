//+------------------------------------------------------------------+
//|  TimeIntel.mqh — Time Intelligence Engine (V60) — 5-cycle stack    |
//|  MN/W/D/H4/H1: bias, completion, alignment, conflict, h1 timing.  |
//+------------------------------------------------------------------+
#ifndef F72_TIMEINTEL_MQH
#define F72_TIMEINTEL_MQH

#include "BrainState.mqh"

class TimeIntel
{
private:
   string m_sym;
   int bias(ENUM_TIMEFRAMES tf,double close){ double op=iOpen(m_sym,tf,0); return(close>op?1:close<op?-1:0); }
public:
   void Init(string sym){ m_sym=sym; }
   void Update(BrainState &S,double close)
   {
      ENUM_TIMEFRAMES tf[5]={PERIOD_MN1,PERIOD_W1,PERIOD_D1,PERIOD_H4,PERIOD_H1};
      int bull=0,bear=0;
      for(int i=0;i<5;i++){ int b=bias(tf[i],close); if(b==1)bull++; else if(b==-1)bear++; }
      S.timeDir = bull>bear?1: bear>bull?-1:0;
      S.timeAlign = (bull+bear)>0? (double)MathMax(bull,bear)/(bull+bear)*100.0 : 50.0;
      S.timeConflict = 100.0-S.timeAlign;
      // H1 timing
      bool h1Ht=iHigh(m_sym,PERIOD_H1,0)>iHigh(m_sym,PERIOD_H1,1);
      bool h1Lt=iLow(m_sym,PERIOD_H1,0)<iLow(m_sym,PERIOD_H1,1);
      double h1O=iOpen(m_sym,PERIOD_H1,0),h1H=iHigh(m_sym,PERIOD_H1,0),h1L=iLow(m_sym,PERIOD_H1,0);
      double pos=(close-h1L)/MathMax(h1H-h1L,_Point);
      double lowProb = (h1Lt&&!h1Ht)?30.0:(h1Ht&&!h1Lt)?70.0:MathRound(pos*100.0);
      S.h1Timing = (h1Ht&&h1Lt)?"COMPLETION": lowProb>=55?"LOW FIRST": lowProb<=45?"HIGH FIRST":"BALANCED";
   }
};

#endif // F72_TIMEINTEL_MQH
