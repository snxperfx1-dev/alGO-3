//+------------------------------------------------------------------+
//|  Executor.mqh — order execution (BODY). Acts only on the BRAIN's  |
//|  doe_* decision object. Targets/stops are the organism's own      |
//|  attractors/invalidation — no invented levels.                    |
//+------------------------------------------------------------------+
#ifndef F72_EXECUTOR_MQH
#define F72_EXECUTOR_MQH

#include <Trade/Trade.mqh>
#include "../Brain/Params.mqh"

class Executor
{
private:
   CTrade  m_trade;
   string  m_sym;
public:
   void Init(string sym,long magic,int slippage)
   {
      m_sym=sym;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFillingBySymbol(sym);
      m_trade.SetAsyncMode(false);
   }
   CTrade* Trade(){ return(GetPointer(m_trade)); }

   bool Open(int dir,double lots,double sl,double tp,string comment)
   {
      if(lots<=0) return(false);
      double price = dir==1? SymbolInfoDouble(m_sym,SYMBOL_ASK) : SymbolInfoDouble(m_sym,SYMBOL_BID);
      bool ok = dir==1? m_trade.Buy(lots,m_sym,price,sl,tp,comment)
                      : m_trade.Sell(lots,m_sym,price,sl,tp,comment);
      return(ok);
   }

   void CloseAll(long magic)
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         m_trade.PositionClose(tk);
      }
   }

   void PartialClose(long magic,double fraction)
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         double vol=PositionGetDouble(POSITION_VOLUME);
         double step=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_STEP);
         double closeVol=MathFloor(vol*fraction/step)*step;
         double minL=SymbolInfoDouble(m_sym,SYMBOL_VOLUME_MIN);
         if(closeVol>=minL && (vol-closeVol)>=minL) m_trade.PositionClosePartial(tk,closeVol);
      }
   }

   void ModifyStop(long magic,double sl,double tp)
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         double curSL=PositionGetDouble(POSITION_SL), curTP=PositionGetDouble(POSITION_TP);
         double nsl = sl>0? sl:curSL; double ntp = tp>0? tp:curTP;
         if(MathAbs(nsl-curSL)>_Point || MathAbs(ntp-curTP)>_Point) m_trade.PositionModify(tk,nsl,ntp);
      }
   }

   int PositionDir(long magic)  // +1 long, -1 short, 0 none
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_sym) continue;
         return(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);
      }
      return(0);
   }
};

#endif // F72_EXECUTOR_MQH
