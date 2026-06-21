//+------------------------------------------------------------------+
//|  Persistence.mqh — lightweight cross-restart state snapshot (BODY)|
//|  The stateful BRAIN engines retain state while the EA is loaded.  |
//|  This module persists the slow-moving adaptive scalars (the       |
//|  organism's "experience": modelConfidence, predReliability) and   |
//|  the last decision snapshot via terminal GlobalVariables, so the  |
//|  learnt confidence survives a restart. Extend to full registry    |
//|  serialization (Wave/Delivery registries) as needed.              |
//+------------------------------------------------------------------+
#ifndef F72_PERSISTENCE_MQH
#define F72_PERSISTENCE_MQH

#include "../Brain/BrainState.mqh"

class Persistence
{
private:
   string m_pfx;
public:
   void Init(string sym){ m_pfx="F72_"+sym+"_"; }

   void Save(const BrainState &S)
   {
      GlobalVariableSet(m_pfx+"modelConfidence",S.modelConfidence);
      GlobalVariableSet(m_pfx+"predReliability",S.predReliability);
      GlobalVariableSet(m_pfx+"wholeChainLife",S.wholeChainLife);
   }
   double LoadModelConfidence()
   {
      return(GlobalVariableCheck(m_pfx+"modelConfidence")?GlobalVariableGet(m_pfx+"modelConfidence"):50.0);
   }
};

#endif // F72_PERSISTENCE_MQH
