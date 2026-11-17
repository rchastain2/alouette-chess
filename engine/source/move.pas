
{**
  @abstract(Déplacement des pièces.)
  Déplacement des pièces.
}

unit Move;

interface

uses
  Board, Chess;

{** Met à jour la position en fonction d'un coup présumé légal. }
function DoMove(var APos: TPosition; const AMove: TMove): boolean; overload;
function DoMove(var APos: TPosition; const AMove: string): boolean; overload;
function StrToMove(const APos: TPosition; const AMoveStr: string; out AMove: TMove): boolean;
function IsCastling(const APos: TPosition; const AMove: TMove): boolean;
procedure RenameCastling(var AMove: TMove);
function PieceTypeIdx(const APos: TPosition; const AIdx: integer): TWidePieceType;

implementation

uses
  SysUtils, Bitboards, MoveGen, Castling{$IFDEF DEBUG_}, Journal{$ENDIF};

{$IFDEF DEBUG_}
var LLog: TLog;
{$ENDIF}

function DoMove(var APos: TPosition; const AMove: TMove): boolean;
var
  LFr, LFrCol, LFrRow,
  LTo, LToCol, LToRow,
  LEPCapture: integer;
  LPType: TWidePieceType;
  LMType: TMoveTypeSet;
  LPreserve: boolean;
begin
  result := FALSE;
  
  DecodeMove(AMove, LFr, LTo, LPType, LMType);
  Assert(IsOnIdx(APos.Pieces[APos.Side], LFr));
  
  LPType := PieceTypeIdx(APos, LFr);
  Assert(LPType <> ptNil);
  
  LFrCol := LFr mod 8;
  LToCol := LTo mod 8;
  LFrRow := LFr div 8;
  LToRow := LTo div 8;
  LPreserve := FALSE;
  
  if LPType = ptKing then
  begin
    if IsOnIdx(APos.Rooks and APos.Pieces[APos.Side], LTo) then
    begin
      if LToCol = APos.Castling[APos.Side].HRook then
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Castling on H side: %s', [MoveToStr(AMove)]));
{$ENDIF}
        MovePieceIdx(APos.Rooks, APos.Pieces[APos.Side], LTo, CATCR[APos.Side]);
        LTo := ToIndex(CColG, LToRow);
        LPreserve := LFrCol = CATCR[APos.Side] mod 8;
      end else
      if LToCol = APos.Castling[APos.Side].ARook then
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Castling on A side: %s', [MoveToStr(AMove)]));
{$ENDIF}
        MovePieceIdx(APos.Rooks, APos.Pieces[APos.Side], LTo, CATCD[APos.Side]);
        LTo := ToIndex(CColC, LToRow);
        LPreserve := LFrCol = CATCD[APos.Side] mod 8;
      end else
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Impossible move: %s', [MoveToStr(AMove)]));
{$ENDIF}
        Exit;
      end;
    end else
    if Abs(LToCol - LFrCol) = 2 then
    begin
      if LToCol = CColG then
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Castling on king side: %s', [MoveToStr(AMove)]));
{$ENDIF}
        MovePieceIdx(APos.Rooks, APos.Pieces[APos.Side], CDTCR[APos.Side], CATCR[APos.Side]);
      end else
      if LToCol = CColC then
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Castling on queen side: %s', [MoveToStr(AMove)]));
{$ENDIF}
        MovePieceIdx(APos.Rooks, APos.Pieces[APos.Side], CDTCD[APos.Side], CATCD[APos.Side]);
      end else
      begin
{$IFDEF DEBUG_}
        LLog.LogLn(Format('[' + {$I %LINE%} + '] Impossible move: %s', [MoveToStr(AMove)]));
{$ENDIF}
        Exit;
      end;
    end;
    
    APos.Castling[APos.Side].HRook := CNil;
    APos.Castling[APos.Side].ARook := CNil;
    APos.KingSquare[APos.Side] := CIdxToSqr[LTo];
  end;
  
{ Si la pièce déplacée est une tour et que le mouvement a lieu sur la ligne de roque... }
  if (LPType = ptRook) and (LFrRow = CCastlingRow[APos.Side]) then
    with APos.Castling[APos.Side] do
      if LFrCol = HRook then
        HRook := CNil
      else
        if LFrCol = ARook then
          ARook := CNil;
  
{ S'il y a une pièce sur la case d'arrivée... }
  if IsOnIdx(APos.Pieces[not APos.Side], LTo) then
  begin
    if IsOnIdx(APos.Rooks, LTo)
    and (LToRow = CCastlingRow[not APos.Side]) then
      with APos.Castling[not APos.Side] do
        if LToCol = HRook then
          HRook := CNil
        else
        if LToCol = ARook then
          ARook := CNil;
    
    with APos do
    begin
      SwitchOffIdx(Pawns,   LTo);
      SwitchOffIdx(Rooks,   LTo);
      SwitchOffIdx(Knights, LTo);
      SwitchOffIdx(Bishops, LTo);
      SwitchOffIdx(Queens,  LTo);
      SwitchOffIdx(Kings,   LTo);
    end;
    SwitchOffIdx(APos.Pieces[not APos.Side], LTo);
  end;
  
{ Si la pièce déplacée est un pion... }
  if (LPType = ptWhitePawn) or (LPType = ptBlackPawn) then
  begin
  { Promotion. }
    if mtPromotion in LMType then
      if mtPromotionKnight in LMType then
      begin
        SwitchOffIdx(APos.Pawns, LFr);
        SwitchOnIdx(APos.Knights, LFr);
        LPType := ptKnight;
      end else
      if mtPromotionBishop in LMType then
      begin
        SwitchOffIdx(APos.Pawns, LFr);
        SwitchOnIdx(APos.Bishops, LFr);
        LPType := ptBishop;
      end else
      if mtPromotionRook in LMType then
      begin
        SwitchOffIdx(APos.Pawns, LFr);
        SwitchOnIdx(APos.Rooks, LFr);
        LPType := ptRook;
      end else
      begin
        SwitchOffIdx(APos.Pawns, LFr);
        SwitchOnIdx(APos.Queens, LFr);
        LPType := ptQueen;
      end
    else
    { Prise en passant. }
      if LTo = APos.EnPassant then
      begin
        LEPCapture := ToIndex(LToCol, LFrRow);
        SwitchOffIdx(APos.Pawns, LEPCapture);
        SwitchOffIdx(APos.Pieces[not APos.Side], LEPCapture);
      end;
  end;
  
  if ((LPType = ptWhitePawn)
  or  (LPType = ptBlackPawn))
  and (Abs(LToRow - LFrRow) = 2) then
  begin
    APos.EnPassant := ToIndex(LFrCol, LFrRow + (LToRow - LFrRow) div 2);
{$IFDEF DEBUG_}
    LLog.LogLn(Format('[' + {$I %LINE%} + '] En passant target square after %s: %s', [MoveToStr(AMove), SquareToStr(APos.EnPassant)]));
{$ENDIF}
  end else
    APos.EnPassant := CNil;
  
{ Déplacement de la pièce. }
  case LPType of
    ptWhitePawn,
    ptBlackPawn: MovePieceIdx(APos.Pawns,   APos.Pieces[APos.Side], LFr, LTo, LPreserve);
    ptRook:      MovePieceIdx(APos.Rooks,   APos.Pieces[APos.Side], LFr, LTo, LPreserve);
    ptKnight:    MovePieceIdx(APos.Knights, APos.Pieces[APos.Side], LFr, LTo, LPreserve);
    ptBishop:    MovePieceIdx(APos.Bishops, APos.Pieces[APos.Side], LFr, LTo, LPreserve);
    ptQueen:     MovePieceIdx(APos.Queens,  APos.Pieces[APos.Side], LFr, LTo, LPreserve);
    ptKing:      MovePieceIdx(APos.Kings,   APos.Pieces[APos.Side], LFr, LTo, LPreserve);
  end;

{ Changement du trait. }
  APos.Side := not APos.Side;
  
  result := TRUE;
end;

function DoMove(var APos: TPosition; const AMove: string): boolean;
var
  LMove: TMove;
begin
  result := StrToMove(APos, AMove, LMove) and DoMove(APos, LMove);
end;

function StrToMove(const APos: TPosition; const AMoveStr: string; out AMove: TMove): boolean;
var
  LMoves: array[0..255] of TMove;
  LCount, i, LFr, LTo: integer;
  LPos: TPosition;
  LStr: string;
  LRenamed: TMove;
begin
  result := FALSE;
  AMove := 0;
  Initialize(LMoves);
  GenerateMoves(APos, LMoves, LCount);
  GenerateCastling(APos, LMoves, LCount);
  for i := 0 to Pred(LCount) do
  begin
    LStr := MoveToStr(LMoves[i]);
    if (LStr <> AMoveStr) and (LStr <> Concat(AMoveStr, 'q')) then
    begin
      if not IsCastling(APos, LMoves[i]) then
        Continue;
      LRenamed := LMoves[i];
      RenameCastling(LRenamed);
      DecodeMove(LRenamed, LFr, LTo);
      if (Abs(LTo mod 8 - LFr mod 8) <> 2) or (MoveToStr(LRenamed) <> AMoveStr) then
        Continue;
    end;
    LPos := APos;
    if not DoMove(LPos, LMoves[i]) then
      Continue;
    LPos.Side := not LPos.Side;
    if IsCheck(LPos) then
      Continue;
    AMove := LMoves[i];
    Exit(TRUE);
  end;
end;

function IsCastling(const APos: TPosition; const AMove: TMove): boolean;
var
  LFr, LTo: integer;
  LWhite, LBlack: TBoard;
begin
  LWhite := APos.Pieces[FALSE];
  LBlack := APos.Pieces[TRUE];
  DecodeMove(AMove, LFr, LTo);
  result :=
    (IsOnIdx(LWhite, LFr) and IsOnIdx(LWhite, LTo)) or
    (IsOnIdx(LBlack, LFr) and IsOnIdx(LBlack, LTo));
{$IFDEF DEBUG_}
  if result then
    LLog.LogLn(Concat('[' + {$I %LINE%} + '] Castling move: ', MoveToStr(AMove)));
{$ENDIF}
end;

procedure RenameCastling(var AMove: TMove);
var
  LFr, LTo, LFrRow, LToRow, LToCol: integer;
{$IFDEF DEBUG_}
  LName: string;
{$ENDIF}
begin
  DecodeMove(AMove, LFr, LTo);
  Assert((LFr >= 0) and (LFr <= 63) and (LTo >= 0) and (LTo <= 63));
{$IFDEF DEBUG_}
  LName := Concat(CSqrToStr[LFr], CSqrToStr[LTo]);
{$ENDIF}
  LFrRow := LFr div 8;
  LToRow := LTo div 8;
  Assert((LToRow = LFrRow) and ((LFrRow = CRow1) or (LFrRow = CRow8)));
  if LTo mod 8 > LFr mod 8 then
    LToCol := CColG
  else
    LToCol := CColC;
  LTo := 8 * LToRow + LToCol;
  AMove := EncodeMove(LFr, LTo, ptKing, [mtCastling]);
{$IFDEF DEBUG_}
  LLog.LogLn(Format('[' + {$I %LINE%} + '] %s -> %s', [LName, Concat(CSqrToStr[LFr], CSqrToStr[LTo])]));
{$ENDIF}
end;

function PieceTypeIdx(const APos: TPosition; const AIdx: integer): TWidePieceType;
begin
  if      IsOnIdx(APos.Pawns,   AIdx) then if APos.Side then result := ptBlackPawn else result := ptWhitePawn
  else if IsOnIdx(APos.Rooks,   AIdx) then result := ptRook
  else if IsOnIdx(APos.Knights, AIdx) then result := ptKnight
  else if IsOnIdx(APos.Bishops, AIdx) then result := ptBishop
  else if IsOnIdx(APos.Queens,  AIdx) then result := ptQueen
  else if IsOnIdx(APos.Kings,   AIdx) then result := ptKing
  else
    result := ptNil;
end;

{$IFDEF DEBUG_}
initialization
  LLog := TLog.Create({$I %FILE%}, TRUE);
finalization
  LLog.Free;
{$ENDIF}
end.
