//+------------------------------------------------------------------+
//|                                                     F72Omega.mq5  |
//|   F72 OMEGA — synthetic trading organism (MT5 incarnation).       |
//|   BRAIN = recovered cognition (V60/F16 lifecycle authority +      |
//|   Letra energy/DIE + F72 decision surface). BODY = execution.     |
//|   The intelligence decides; the body never overrules it.          |
//|                                                                   |
//|   Lineage: F72 (ancestry) -> Letra 37 (evolution) -> V60/F16      |
//|   (final form, the precise lifecycle/phase authority used here).  |
//|   Nothing invented — see F72_OMEGA_MASTER_ARCHITECTURE.md.        |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "1.00"
#property strict

#include "Brain/Brain.mqh"
#include "Body/Risk.mqh"
#include "Body/Portfolio.mqh"
#include "Body/Executor.mqh"
#include "Body/PositionIntel.mqh"
#include "Body/Journal.mqh"

Brain          g_brain;
RiskManager    g_risk;
Portfolio      g_port;
Executor       g_exec;
PositionIntel  g_posIntel;
Journal        g_journal;

string         g_sym;
int            g_lastEntryBar;
bool           g_scaledTP1;
int            g_posDirAtEntry;

//+------------------------------------------------------------------+
int OnInit()
{
   g_sym=_Symbol;
   g_brain.Init(g_sym,InpExecTF);
   g_risk.Init(g_sym);
   g_port.Init(g_sym);
   g_exec.Init(g_sym,InpMagic,InpSlippagePts);
   g_journal.Init(g_sym);
   g_lastEntryBar=-100000; g_scaledTP1=false; g_posDirAtEntry=0;
   PrintFormat("[F72 OMEGA] initialised on %s exec=%s. Trading=%s",
               g_sym,EnumToString(InpExecTF),(InpEnableTrading?"ON":"OBSERVE"));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ g_journal.Deinit(); }

//+------------------------------------------------------------------+
void OnTick()
{
   g_port.RollDay();

   // BRAIN: recompute only on a freshly closed exec-TF bar
   if(!g_brain.OnNewBar()) return;
   BrainState S=g_brain.State();
   if(InpVerboseJournal) g_journal.Print(S);
   g_journal.Log(S);

   if(!InpEnableTrading) return;

   int posDir=g_exec.PositionDir(InpMagic);
   int barIndex=Bars(g_sym,InpExecTF);

   //============================ MANAGE OPEN POSITION ============================
   if(posDir!=0)
   {
      POS_ACTION pa=g_posIntel.Decide(S,posDir);
      if(pa==POS_EXIT)
      {
         g_exec.CloseAll(InpMagic);
         return;
      }
      if(pa==POS_REVERSE)
      {
         g_exec.CloseAll(InpMagic);
         // fall through to entry evaluation below (organism wants the other side)
         posDir=0;
      }
      else
      {
         if(pa==POS_REDUCE && !g_scaledTP1)
         {
            g_exec.PartialClose(InpMagic,InpTP1ClosePct/100.0);
            g_scaledTP1=true;
         }
         // trail stop to the organism's live invalidation; manage TP1 scale-out
         double newSL = !f72_isna(S.inv_activeStop)? S.inv_activeStop : 0.0;
         double newTP = !f72_isna(S.te_tp2)? S.te_tp2 : 0.0;
         g_exec.ModifyStop(InpMagic,newSL,newTP);

         if(InpUseTP1 && !g_scaledTP1 && !f72_isna(S.te_tp1))
         {
            double bid=SymbolInfoDouble(g_sym,SYMBOL_BID), ask=SymbolInfoDouble(g_sym,SYMBOL_ASK);
            bool hitT1 = posDir==1? bid>=S.te_tp1 : ask<=S.te_tp1;
            if(hitT1){ g_exec.PartialClose(InpMagic,InpTP1ClosePct/100.0); g_scaledTP1=true; }
         }
         return; // holding
      }
   }

   //============================ NEW ENTRY EVALUATION ============================
   if(g_port.DailyLossHit())                       return;
   if(g_port.OpenCount(InpMagic)>=InpMaxPositions) return;
   if(g_risk.OpenRiskPct(InpMagic)>=InpMaxRiskPctTotal) return;
   if(barIndex-g_lastEntryBar < InpBaseLockBars)   return;   // execution lock

   int dir=0;
   if(S.doe_action=="Long")  dir=1;
   if(S.doe_action=="Short") dir=-1;
   if(dir==0) return;

   if(f72_isna(S.inv_activeStop)) return;                    // no organism invalidation -> no trade
   double entry = dir==1? SymbolInfoDouble(g_sym,SYMBOL_ASK) : SymbolInfoDouble(g_sym,SYMBOL_BID);
   double stop  = S.inv_activeStop;
   // stop must be on the correct side
   if((dir==1 && stop>=entry) || (dir==-1 && stop<=entry)) return;

   double tp = !f72_isna(S.te_tp2)? S.te_tp2 : (dir==1? entry+(entry-stop)*2.0 : entry-(stop-entry)*2.0);

   // size scales with the organism's confidence (within the decision already made)
   double riskPct = InpRiskPctPerTrade * MathMax(0.5, MathMin(1.0, S.doe_confidence/100.0 + 0.25));
   double lots=g_risk.LotsFor(entry,stop,riskPct);
   if(lots<=0) return;

   string cmt=StringFormat("F72 %s %s g%s c%.0f",S.doe_action,S.intent,S.doe_grade,S.doe_confidence);
   if(g_exec.Open(dir,lots,stop,tp,cmt))
   {
      g_lastEntryBar=barIndex; g_scaledTP1=false; g_posDirAtEntry=dir;
      PrintFormat("[F72 OMEGA] ENTER %s %.2f lots @ %.5f sl=%.5f tp=%.5f | %s",
                  (dir==1?"LONG":"SHORT"),lots,entry,stop,tp,cmt);
   }
}
//+------------------------------------------------------------------+
