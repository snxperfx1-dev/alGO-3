//+------------------------------------------------------------------+
//|  Portfolio.mqh — exposure & daily-loss guard (BODY).              |
//|  Mechanical safety only — never produces a signal or bias.        |
//+------------------------------------------------------------------+
#ifndef F72_PORTFOLIO_MQH
#define F72_PORTFOLIO_MQH

#include "../Brain/Params.mqh"

class Portfolio
{
private:
   string   m_sym;
   double   m_dayStartEquity;
   datetime m_dayStart;
public:
   void Init(string sym){ m_sym=sym; m_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); m_dayStart=0; }

   int OpenCount(long magic)
   {
      int n=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(PositionGetTicket(i)==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)==magic && PositionGetString(POSITION_SYMBOL)==m_sym) n++;
      }
      return(n);
   }

   void RollDay()
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); dt.hour=0;dt.min=0;dt.sec=0;
      datetime d0=StructToTime(dt);
      if(d0!=m_dayStart){ m_dayStart=d0; m_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY); }
   }

   bool DailyLossHit()
   {
      if(m_dayStartEquity<=0) return(false);
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double ddPct=(m_dayStartEquity-eq)/m_dayStartEquity*100.0;
      return(ddPct>=InpDailyLossCapPct);
   }
};

#endif // F72_PORTFOLIO_MQH
