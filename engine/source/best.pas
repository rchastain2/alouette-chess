
{**
  @abstract(Recherche du meilleur coup.)
  Recherche du meilleur coup.
}

unit Best;

interface

uses
  Chess;

type
  TInfoProc = procedure(const AText: string);

function GetBestMove(const APos: TPosition; const AChess960: boolean; const ATime: integer; var AMove: string; const ARandom: boolean = FALSE; const ADepth: integer = 0): string;

var
  LFactorPawnMove,
  LFactorPawnStruct,
  LFactorTargets,
  LFactorCastling,
  LFactorEnPassant,
  LFactorCheck,
  LFactorProtect,
  LFactorAttack,
  LFactorPawnMobil,
  LFactorNewPos: integer;
  LStop: boolean = FALSE;
  LInfoProc: TInfoProc = nil;

implementation

uses
  SysUtils, Math, Move, MoveGen, Castling, Board, Bitboards, History{$IFDEF LOG_BEST}, Journal{$ENDIF}, PST;

var
  LEndTime: qword;
{$IFDEF LOG_BEST}
  LLog: TLog;
{$ENDIF}

type
  TEvalFunc = function(const APos: TPosition; const AMove: TMove): integer;

function TimeIsUp: boolean;
begin
  result := LStop or (GetTickCount64 >= LEndTime);
end;

function LegalityScore(const APos: TPosition; const AMove: TMove): integer;
var
  LPos: TPosition;
begin
  LPos := APos;
  result := 0;
  if DoMove(LPos, AMove) then
  begin
    LPos.Side := not LPos.Side;
    result := Ord(not IsCheck(LPos));
  end;
end;

const
  CMax = 99999;
  CMin = -1 * CMax;
  CMate = 90000;
  CMaxDepth = 64;
  CPieceValue: array[ptWhitePawn..ptQueen] of integer = (100, 100, 500, 320, 330, 900);
  
function MaterialAdvantage(const APos: TPosition): integer;
var
  LIdx: integer;
  LType: TPieceType;
  LPieces: TBoard;
begin
  if (APos.Pieces[APos.Side] and APos.Kings) = 0 then
    Exit(CMin);

  if (APos.Pieces[not APos.Side] and APos.Kings) = 0 then
    Exit(CMax);

  result := 0;

  LPieces := APos.Pieces[FALSE] and not APos.Kings;
  while LPieces <> 0 do
  begin
    LIdx := BsfQWord(QWord(LPieces));
    LType := PieceTypeIdx(APos, LIdx);
    Inc(result, CPieceValue[LType]);
    LPieces := LPieces and not CIdxToSqr[LIdx];
  end;

  LPieces := APos.Pieces[TRUE] and not APos.Kings;
  while LPieces <> 0 do
  begin
    LIdx := BsfQWord(QWord(LPieces));
    LType := PieceTypeIdx(APos, LIdx);
    Dec(result, CPieceValue[LType]);
    LPieces := LPieces and not CIdxToSqr[LIdx];
  end;

  if APos.Side then
    result := -1 * result;
end;

function AlphaBeta(const APos: TPosition; const ADepth: integer; AAlpha, ABeta: integer): integer;
var
  LMoves: array[0..255] of TMove;
  LCount, i: integer;
  LPos: TPosition;
  LScore: integer;
  LLegal: boolean;
begin
  { Profondeur atteinte ou temps écoulé : évaluation du point de vue du camp au trait }
  if (ADepth = 0) or TimeIsUp then
    Exit(MaterialAdvantage(APos));

  { Coups pseudo-légaux : la légalité est vérifiée dans la boucle }
  GenerateMoves(APos, LMoves, LCount);
  GenerateCastling(APos, LMoves, LCount);

  LLegal := FALSE;
  result := CMin;

  for i := 0 to Pred(LCount) do
  begin
    LPos := APos;

    { Coup impossible, ne devrait pas arriver }
    if not DoMove(LPos, LMoves[i]) then
      Continue;

    { DoMove a changé le trait : on le rend au joueur pour voir si son roi est en prise }
    LPos.Side := not LPos.Side;
    if IsCheck(LPos) then
      Continue;

    { Trait à l'adversaire }
    LPos.Side := not LPos.Side;
    LLegal := TRUE;

    { Le score de l'adversaire est l'opposé du nôtre : la fenêtre est inversée }
    LScore := -AlphaBeta(LPos, ADepth - 1, -ABeta, -AAlpha);

    { Meilleur score pour ce nœud }
    if LScore > result then
      result := LScore;

    { Relèvement de la borne inférieure }
    if result > AAlpha then
      AAlpha := result;

    { Coupure : l'adversaire a déjà mieux ailleurs et évitera cette position }
    if AAlpha >= ABeta then
      Break;
  end;

  { Aucun coup légal : la partie est finie. Plus ADepth est grand, plus le mat est proche. }
  if not LLegal then
    { Échec et mat }
    if IsCheck(APos) then
      result := -CMate - ADepth
    { Pat }
    else
      result := 0;
end;

function SearchMove(const APos: TPosition; const AMove: TMove; const ADepth: integer): integer;
var
  LPos: TPosition;
begin
  LPos := APos;
  if DoMove(LPos, AMove) then
    result := -AlphaBeta(LPos, ADepth - 1, CMin, CMax)
  else
    result := CMin;
end;

function TieBreakScore(const APos: TPosition; const AMove: TMove): integer;
const
  CCaptureRank: array[ptWhitePawn..ptKing] of integer = (1, 1, 4, 2, 3, 5, 6);
var
  LFr, LTo: integer;
  LPieceType, LCapturedPieceType: TWidePieceType;
  LMoveType: TMoveTypeSet;
  LPos: TPosition;
  LCastling, LEnPassant, LCheck, LTargets, LProtect, LAttack, LPawnStruct, LPawnMobil, LPawnMove, LNewPos, LCapture: integer;
{$IFDEF LOG_BEST}
  LMoveStr: string;
{$ENDIF}
  LPST: integer;
begin
  DecodeMove(AMove, LFr, LTo, LPieceType, LMoveType);
  
  LPawnMove := Ord(LPieceType in [ptWhitePawn, ptBlackPawn]);
  
  LPST := 0;
  if APos.Side then
    case LPieceType of
      ptKing:      LPST := PST_BK[LTo] - PST_BK[LFr];
      ptRook:      LPST := PST_BR[LTo] - PST_BR[LFr];
      ptQueen:     LPST := PST_BQ[LTo] - PST_BQ[LFr];
      ptKnight:    LPST := PST_BN[LTo] - PST_BN[LFr];
      ptBishop:    LPST := PST_BB[LTo] - PST_BB[LFr];
      ptBlackPawn: LPST := PST_BP[LTo] - PST_BP[LFr];
    end
  else
    case LPieceType of
      ptKing:      LPST := PST_WK[LTo] - PST_WK[LFr];
      ptRook:      LPST := PST_WR[LTo] - PST_WR[LFr];
      ptQueen:     LPST := PST_WQ[LTo] - PST_WQ[LFr];
      ptKnight:    LPST := PST_WN[LTo] - PST_WN[LFr];
      ptBishop:    LPST := PST_WB[LTo] - PST_WB[LFr];
      ptWhitePawn: LPST := PST_WP[LTo] - PST_WP[LFr];
    end;
  if mtPromotion in LMoveType then
    LPST := 0
  else
    LPST := Sign(LPST);
  
  LCastling := Ord(mtCastling in LMoveType);
  LEnPassant := Ord(mtEnPassant in LMoveType);
  
  if mtEnPassant in LMoveType then
    LCapture := 1
  else if mtCapture in LMoveType then
  begin
    LCapturedPieceType := PieceTypeIdx(APos, LTo);
    LCapture := CCaptureRank[LCapturedPieceType] - CCaptureRank[LPieceType] + CCaptureRank[ptKing];
  end else
    LCapture := 0;
  
  LCheck := 0;
  LProtect := 0;
  LAttack := 0;
  LPawnStruct := 0;
  LTargets := 0;
  LPawnMobil := 0;
  LNewPos := 0;
  LPos := APos;
  if DoMove(LPos, AMove) then
  begin
    LCheck := Ord(IsCheck(LPos));
    LPos.Side := not LPos.Side;
    LProtect := 0;
    LAttack := 0;
    LPawnStruct := PawnStruct(LPos);
    LTargets := {CountTargets(LPos)}0;
    LPawnMobil := {PawnMovesCount(LPos)}0;
    LPos.Side := not LPos.Side;
    LNewPos := Ord(not FindInHistory(LPos));
  end else
    Assert(FALSE, 'Cannot do move');
{$IFDEF LOG_BEST}
  LMoveStr := MoveToStr(AMove);
{$ENDIF}
  LPawnMove   := LFactorPawnMove   * LPawnMove;
  LCastling   := LFactorCastling   * LCastling;
  LEnPassant  := LFactorEnPassant  * LEnPassant;
  LCheck      := LFactorCheck      * LCheck;
  LProtect    := LFactorProtect    * LProtect;
  LAttack     := LFactorAttack     * LAttack;
  LTargets    := LFactorTargets    * LTargets;
  LPawnStruct := LFactorPawnStruct * LPawnStruct;
  LPawnMobil  := LFactorPawnMobil  * LPawnMobil;
  LNewPos     := LFactorNewPos     * LNewPos;
  
{$IFDEF LOG_BEST}
  LLog.LogLn(Format(
    '| %-5s |  %d  |  %d  |  %d  |  %d  |  %2d |  %2d |  %2d |',
    [LMoveStr, LCastling, LEnPassant, LCheck, LNewPos, LPST, LPawnStruct, LCapture]
  ));
{$ENDIF}
  
  result :=
    LPST
  + LPawnMove
  + LCastling
  + LEnPassant
  + LCheck
  + LProtect
  + LAttack
  + LTargets
  + LPawnStruct
  + LPawnMobil
  + LNewPos
  + LCapture
  ;
end;

procedure SortMoves(var AMoves: array of TMove; var AValues: array of integer; const ACount: integer);

  procedure Swap(var AArr: array of integer; const AIdx: integer); overload;
  var
    LAux: integer;
  begin
    LAux           := AArr[AIdx];
    AArr[AIdx]     := AArr[AIdx + 1];
    AArr[AIdx + 1] := LAux;
  end;

  procedure Swap(var AArr: array of TMove; const AIdx: integer); overload;
  var
    LAux: TMove;
  begin
    LAux           := AArr[AIdx];
    AArr[AIdx]     := AArr[AIdx + 1];
    AArr[AIdx + 1] := LAux;
  end;

var
  LIdx: integer;
  LDone: boolean;
begin
  repeat
    LDone := TRUE;
    for LIdx := 0 to ACount - 2 do
      if AValues[LIdx] < AValues[LIdx + 1] then
      begin
        Swap(AMoves, LIdx);
        Swap(AValues, LIdx);
        LDone := FALSE;
      end;
  until LDone;
end;

function CountBestMoves(const AValues: array of integer; const ACount: integer): integer;
begin
  result := 1;
  while (result < ACount) and (AValues[result] = AValues[0]) do
    Inc(result);
end;

function GetBestMove(const APos: TPosition; const AChess960: boolean; const ATime: integer; var AMove: string; const ARandom: boolean; const ADepth: integer): string;
var
  LMoves: array[0..255] of TMove;
  LScores: array[0..255] of integer;
  LCount: integer;
  LStartTime: qword;

  procedure SelectBestMoves;
  var
    LMove: TMove;
  begin
    SortMoves(LMoves, LScores, LCount);
{$IFDEF LOG_BEST}
    LLog.LogLn(LMoves, LScores, LCount);
{$ENDIF}
    LCount := CountBestMoves(LScores, LCount);
    LMove := LMoves[Random(LCount)];
    if IsCastling(APos, LMove) and not AChess960 then
      RenameCastling(LMove);
    AMove := MoveToStr(LMove);
  end;

  procedure Evaluate(AFunc: TEvalFunc);
  var
    i: integer;
  begin
    for i := 0 to Pred(LCount) do
      LScores[i] := AFunc(APos, LMoves[i]);
    SelectBestMoves;
  end;
  
  procedure IterativeSearch;
  var
    LDepth, LMaxDepth, i: integer;
    LDepthScores: array[0..255] of integer;
    LComplete: boolean;

    procedure SendInfo;
    var
      LBest, LPlies, j: integer;
      LMove: TMove;
      LScoreStr: string;
    begin
      if not Assigned(LInfoProc) then
        Exit;
      LBest := 0;
      for j := 1 to Pred(LCount) do
        if LScores[j] > LScores[LBest] then
          LBest := j;
      if Abs(LScores[LBest]) >= CMate then
      begin
        LPlies := LDepth - (Abs(LScores[LBest]) - CMate);
        if LScores[LBest] > 0 then
          LScoreStr := Format('mate %d', [Succ(LPlies) div 2])
        else
          LScoreStr := Format('mate %d', [-(LPlies div 2)]);
      end else
        LScoreStr := Format('cp %d', [LScores[LBest]]);
      LMove := LMoves[LBest];
      if IsCastling(APos, LMove) and not AChess960 then
        RenameCastling(LMove);
      LInfoProc(Format('info depth %d score %s time %d pv %s', [LDepth, LScoreStr, GetTickCount64 - LStartTime, MoveToStr(LMove)]));
    end;

  begin
    for i := 0 to Pred(LCount) do
      LScores[i] := 0;

    if (ADepth >= 1) and (ADepth <= CMaxDepth) then
      LMaxDepth := ADepth
    else
      LMaxDepth := CMaxDepth;

    LDepth := 1;
    repeat
      LComplete := TRUE;
      for i := 0 to Pred(LCount) do
      begin
       {if GetTickCount64 >= LEndTime then
        begin
          LComplete := FALSE;
          Break;
        end;}
        LDepthScores[i] := SearchMove(APos, LMoves[i], LDepth);
        if TimeIsUp then
        begin
          LComplete := FALSE;
          Break;
        end;
      end;
      if LComplete then
      begin
        for i := 0 to Pred(LCount) do
          LScores[i] := LDepthScores[i];
        SendInfo;
        Inc(LDepth);
      end;
    until not LComplete or (LDepth > LMaxDepth);

    SelectBestMoves;
  end;

begin
  Initialize(LMoves);
  LStartTime := GetTickCount64;
  LEndTime := LStartTime + ATime;
{$IFDEF LOG_BEST}
  LLog.LogLn(Concat('Position: ', DecodePosition(APos)));
  LLog.LogLn(Format('Time available: %d ms', [ATime]));
{$ENDIF}
  GenerateMoves(APos, LMoves, LCount);
  GenerateCastling(APos, LMoves, LCount);
  if LCount > 0 then
    Evaluate(@LegalityScore);
  if (LCount = 0) or (LScores[0] = 0) then
  begin
    AMove := '0000';
    Exit(AMove);
  end;
  if ARandom then
    Exit(AMove);
  IterativeSearch;
{$IFDEF LOG_BEST}
  LLog.LogLn('| Move  | Cast | EnPa | Chec | NewP | PST  | Stru | Capt |');
{$ENDIF}
  Evaluate(@TieBreakScore);
{$IFDEF LOG_BEST}
  LLog.UpdateFile;
{$ENDIF}
  result := AMove;
end;

{$IFDEF LOG_BEST}
initialization
  LLog := TLog.Create({$I %FILE%}, TRUE);
finalization
  LLog.Free;
{$ENDIF}
end.
