//+------------------------------------------------------------------+
//|  PositionIntel.mqh — Hold / Scale / Reduce / Reverse / Exit (BODY)|
//|  Reads the organism's Life, resolution, chain vitality and        |
//|  Senseei action. The body executes the organism's verdict.        |
//+------------------------------------------------------------------+
#ifndef F72_POSITIONINTEL_MQH
#define F72_POSITIONINTEL_MQH

#include "../Brain/BrainState.mqh"

enum POS_ACTION { POS_HOLD, POS_REDUCE, POS_EXIT, POS_REVERSE };

class PositionIntel
{
public:
   // posDir: current open direction (+1/-1/0)
   POS_ACTION Decide(const BrainState &S,int posDir)
   {
      if(posDir==0) return(POS_HOLD);
      // Organism says manage/exit (resolution complete)
      if(S.action=="MANAGE / EXIT" || S.re_resolutionState=="RESOLVED") return(POS_EXIT);
      // Curve is DEAD and ownership flipped against us -> reverse
      if(S.life<=32.0 && S.master!=0 && S.master!=posDir) return(POS_REVERSE);
      // Chain bled out -> exit (campaign late)
      if(S.chainScope=="WHOLE CHAIN decaying") return(POS_EXIT);
      // Weakening / narrative fading -> reduce
      if(S.life<45.0 || S.narrState=="WEAKENING") return(POS_REDUCE);
      return(POS_HOLD);
   }
};

#endif // F72_POSITIONINTEL_MQH
