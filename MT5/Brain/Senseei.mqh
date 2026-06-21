//+------------------------------------------------------------------+
//|  Senseei.mqh — Meta-Intelligence / Decision Output (V60 Part D)   |
//|  Four votes -> master, alignment, conflict, threat, confidence,   |
//|  timing, intent, opportunity, ACTION. Mapped to F72 DOE surface.  |
//|  This is the ONLY actionable output. The body never overrules it. |
//+------------------------------------------------------------------+
#ifndef F72_SENSEEI_MQH
#define F72_SENSEEI_MQH

#include "BrainState.mqh"
#include "Structure.mqh"

bool strHas(string s,string sub){ return(StringFind(s,sub)>=0); }

void ComputeSenseei(BrainState &S,double close)
{
   // attractor score from EAE (V60 Part C)
   S.attractorScore = S.eae_primaryAttractorScore;
   double residual  = S.re_residualEnergyScore;
   int    resCode   = S.re_resolutionState=="RESOLVED"?2: S.re_resolutionState=="PARTIALLY RESOLVED"?1:0;

   // four votes
   int vt1=S.waveDir, vt2=S.fractalStackDir, vt3=S.netBias, vt4=S.pdir;
   int sum=vt1+vt2+vt3+vt4;
   int master=sum>0?1:sum<0?-1:0;
   int cast=(vt1!=0?1:0)+(vt2!=0?1:0)+(vt3!=0?1:0)+(vt4!=0?1:0);
   int forV=(vt1==master&&vt1!=0?1:0)+(vt2==master&&vt2!=0?1:0)+(vt3==master&&vt3!=0?1:0)+(vt4==master&&vt4!=0?1:0);
   double alignment=cast>0?(double)forV/cast*100.0:50.0;
   double conflict =cast>0?(double)(cast-forV)/cast*100.0:0.0;
   double threat=MathMax(0.0,MathMin(100.0, conflict*0.40+residual*0.28+S.timeConflict*0.12+(vt4!=0&&vt4!=master?18.0:0.0)+(resCode==1?10.0:0.0)));
   double confidence=MathMax(0.0,MathMin(100.0, alignment*0.40+S.timeAlign*0.12+S.fractalStackScore*0.18+S.attractorScore*0.15+MathMin(15.0,S.eligNodes*1.2)-threat*0.20));

   string p=S.ie1a_currentPhase;
   string timing = (strHas(p,"Absorption")||resCode==2)?"RESOLVED": S.waveProgress<15?"VERY EARLY": S.waveProgress<35?"EARLY": S.waveProgress<55?"DEVELOPING": S.waveProgress<80?"MID CYCLE": S.waveProgress<96?"LATE":"TERMINAL";
   string intent = conflict>55?"ABSORPTION":
        (strHas(p,"Expansion")&&!strHas(p,"Pre-Convexity")&&!strHas(p,"Induction")&&!strHas(p,"Liquidity"))?"EXPANSION":
        strHas(p,"Pre-Convexity")?"CONTINUATION": strHas(p,"Induction")?"RESOLUTION": strHas(p,"Liquidity")?"DELIVERY":
        (strHas(p,"New High")||strHas(p,"New Low"))?"DELIVERY": strHas(p,"Absorption")?"ABSORPTION": master==0?"BALANCE":"CONTINUATION";

   double oppScore=MathMax(0.0,MathMin(100.0, alignment*0.40+S.attractorScore*0.30+S.fractalStackScore*0.30-threat*0.35));
   string opportunity = master==0?"NONE": conflict>60?"DEVELOPING": oppScore<20?"NONE": oppScore<40?"DEVELOPING": oppScore<62?"GOOD": oppScore<82?"STRONG":"EXCEPTIONAL";
   string action = master==0?"WAIT": conflict>60?"WAIT": resCode==2?"MANAGE / EXIT":
        ((opportunity=="STRONG"||opportunity=="EXCEPTIONAL")&&confidence>=InpMinConf&&threat<45)?"ATTACK":
        (opportunity=="GOOD"||opportunity=="STRONG")?"PREPARE":"WAIT";

   // publish Senseei
   S.master=master; S.alignment=alignment; S.conflict=conflict; S.threat=threat; S.confidence=confidence;
   S.oppScore=oppScore; S.timing=timing; S.intent=intent; S.opportunity=opportunity; S.action=action;

   // ----- F72 DOE surface (same values, F72 vocabulary) -----
   S.doe_bias = (master==1 && S.timeAlign>=75 && S.fractalStackScore>=65)?"Strong Bullish":
                master==1?"Bullish":
                (master==-1 && S.timeAlign>=75 && S.fractalStackScore>=65)?"Strong Bearish":
                master==-1?"Bearish":"Neutral";
   S.doe_confidence=confidence;
   S.doe_tradeType = (S.narrState=="STRENGTHENING")? "Continuation":
        strHas(p,"Retracement")? "Pullback": (S.recursiveJustFired)? "Rotation":
        (strHas(p,"New High")||strHas(p,"New Low"))?"Breakout": conflict>55?"Range":"Continuation";

   // ERF gate is the organism's own readiness pre-condition (preserved verbatim)
   bool gate = S.erf_entryGate;
   if(action=="ATTACK" && gate && master==1)       S.doe_action="Long";
   else if(action=="ATTACK" && gate && master==-1) S.doe_action="Short";
   else if(action=="MANAGE / EXIT")                S.doe_action="Manage";
   else if(action=="PREPARE" && gate)              S.doe_action="Prepare";
   else                                            S.doe_action="Wait";

   // entry zone (FRZ best in proximity & aligned, else Demand/Supply flip zone)
   double atr=S.atr;
   bool frzProx = S.frz_activeCount>0 && !f72_isna(S.frz_distanceToZone) && S.frz_distanceToZone<2.0 && S.frz_bestDir==master;
   double mid;
   if(frzProx) mid=(S.frz_bestTop+S.frz_bestBot)/2.0;
   else if(p=="Demand Return"||p=="Supply Return") mid=(!f72_isna(S.flipTop)&&!f72_isna(S.flipBot))?(S.flipTop+S.flipBot)/2.0:close;
   else mid=close;
   S.doe_entryMid=mid; S.doe_entryHigh=mid+atr*0.30; S.doe_entryLow=mid-atr*0.30;
   S.doe_entryTrigger = frzProx?"Limit": (p=="Demand Return"||p=="Supply Return")?"LimitOnRetest":"Market";

   // invalidation stop = organism's own origin (se5_inv) with F72 buffer
   double origin = !f72_isna(S.flipBot)&&master==1? S.flipBot : !f72_isna(S.flipTop)&&master==-1? S.flipTop : F72_NA;
   if(!f72_isna(origin)) S.inv_activeStop = master==1? origin-atr*InpStopBufferATR : origin+atr*InpStopBufferATR;
   else S.inv_activeStop=F72_NA;

   // targets (TE): TP1=secondary attractor, TP2=primary attractor, TP3=projected target / extension
   S.te_tp1 = !f72_isna(S.eae_secondaryAttractorPrice)? S.eae_secondaryAttractorPrice : F72_NA;
   S.te_tp2 = !f72_isna(S.eae_primaryAttractorPrice)?   S.eae_primaryAttractorPrice   : F72_NA;
   double ext = master==1? close+atr*3.0 : close-atr*3.0;
   S.te_tp3 = ext;
   if(f72_isna(S.te_tp1)) S.te_tp1 = master==1? close+atr*1.0 : close-atr*1.0;
   if(f72_isna(S.te_tp2)) S.te_tp2 = master==1? close+atr*2.0 : close-atr*2.0;
}

#endif // F72_SENSEEI_MQH
