//+------------------------------------------------------------------+
//|  Risk.mqh — position sizing + invalidation stop (BODY).           |
//|  Stop = organism's own invalidation (se5_inv). Sizing scales      |
//|  within the decision the BRAIN already made; never overrules it.  |
//+------------------------------------------------------------------+
#ifndef F72_RISK_MQH
#define F72_RISK_MQH

#include "../Brain/Params.mqh"

class RiskManager
{
private:
   string m_sym;
public:
   void Init(string sym){ m_sym=sym; }

   // lots for a given entry/stop distance and risk fraction of equity
   double LotsFor(double entry,double stop,double riskPct)
   {
      double dist=MathAbs(entry-stop); if(dist<=0) return(0.0);
      double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney=equity*riskPct/100.0;
      double tickVal=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_VALUE);
      double tickSize=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_SIZE);
      if(tickVal<=0||tickSize<=0) return(0.0);
      double lossPerLot=dist/tickSize*tickVal;
      if(lossPerLot<=0) return(0.0);
      double lots=riskMoney/lossPerLot;
      double minL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN);
      double maxL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MAX);
      double step=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_STEP);
      lots=MathFloor(lots/step)*step;
      lots=MathMax(minL,MathMin(maxL,lots));
      return(lots);
   }

   // aggregate open risk % of equity for this EA's positions
   double OpenRiskPct(long magic)
   {
      double equity=AccountInfoDouble(ACCOUNT_EQUITY); if(equity<=0) return(0);
      double risk=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         double sl=PositionGetDouble(POSITION_SL); if(sl<=0) continue;
         double op=PositionGetDouble(POSITION_PRICE_OPEN);
         double vol=PositionGetDouble(POSITION_VOLUME);
         double tickVal=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_VALUE);
         double tickSize=SymbolInfoDouble(m_sym,SYMBOL_TRADE_TICK_SIZE);
         if(tickSize>0) risk+=MathAbs(op-sl)/tickSize*tickVal*vol;
      }
      return(risk/equity*100.0);
   }
};

#endif // F72_RISK_MQH
