//+------------------------------------------------------------------+
//|  Journal.mqh — decision logging + persistence/replay (BODY).      |
//|  Writes a structured CSV of every decision (replay/audit/DB) and  |
//|  prints the decision breakdown. Computes nothing cognitive.       |
//+------------------------------------------------------------------+
#ifndef F72_JOURNAL_MQH
#define F72_JOURNAL_MQH

#include "../Brain/BrainState.mqh"

class Journal
{
private:
   int    m_fh;
   string m_file;
public:
   void Init(string sym)
   {
      m_file="F72Omega_"+sym+"_decisions.csv";
      m_fh=FileOpen(m_file,FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,';');
      if(m_fh!=INVALID_HANDLE)
      {
         FileSeek(m_fh,0,SEEK_END);
         if(FileSize(m_fh)==0)
            FileWrite(m_fh,"time","phase","phaseConf","waveDir","fractalDir","fractalScore",
                      "resolution","residual","attractor","life","aliveVerdict","chainScope",
                      "master","alignment","conflict","threat","confidence","opportunity",
                      "intent","timing","action","doe_bias","doe_action","doe_tradeType","grade",
                      "entryLow","entryHigh","stop","tp1","tp2","tp3","erfReadiness","erfGate",
                      "modelConf","predReliability","expectedNext");
      }
   }
   void Deinit(){ if(m_fh!=INVALID_HANDLE) FileClose(m_fh); }

   void Log(const BrainState &S)
   {
      if(m_fh!=INVALID_HANDLE)
      {
         FileWrite(m_fh,
            TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
            S.ie1a_currentPhase,DoubleToString(S.ie1a_phaseConfidence,1),
            (string)S.waveDir,(string)S.fractalStackDir,DoubleToString(S.fractalStackScore,1),
            S.re_resolutionState,DoubleToString(S.re_residualEnergyScore,1),DoubleToString(S.attractorScore,1),
            DoubleToString(S.life,1),S.aliveVerdict,S.chainScope,
            (string)S.master,DoubleToString(S.alignment,1),DoubleToString(S.conflict,1),
            DoubleToString(S.threat,1),DoubleToString(S.confidence,1),S.opportunity,
            S.intent,S.timing,S.action,S.doe_bias,S.doe_action,S.doe_tradeType,S.doe_grade,
            DoubleToString(S.doe_entryLow,_Digits),DoubleToString(S.doe_entryHigh,_Digits),
            DoubleToString(S.inv_activeStop,_Digits),DoubleToString(S.te_tp1,_Digits),
            DoubleToString(S.te_tp2,_Digits),DoubleToString(S.te_tp3,_Digits),
            DoubleToString(S.erf_tradeReadiness,1),(string)S.erf_entryGate,
            DoubleToString(S.modelConfidence,1),DoubleToString(S.predReliability,1),S.expectedNextPhase);
         FileFlush(m_fh);
      }
   }

   void Print(const BrainState &S)
   {
      PrintFormat("[F72] %s conf=%.0f | %s/%s | dir=%d frac=%.0f%% | %s res=%s resid=%.0f | life=%.0f %s | conf=%.0f threat=%.0f opp=%s | DOE=%s(%s) grade=%s | stop=%.5f tp1=%.5f tp2=%.5f | erfRdy=%.0f gate=%s mc=%.0f",
            S.ie1a_currentPhase,S.ie1a_phaseConfidence,S.opportunity,S.action,
            S.waveDir,S.fractalStackScore,S.intent,S.re_resolutionState,S.re_residualEnergyScore,
            S.life,S.aliveVerdict,S.confidence,S.threat,S.opportunity,
            S.doe_action,S.doe_bias,S.doe_grade,S.inv_activeStop,S.te_tp1,S.te_tp2,
            S.erf_tradeReadiness,(S.erf_entryGate?"Y":"N"),S.modelConfidence);
   }
};

#endif // F72_JOURNAL_MQH
