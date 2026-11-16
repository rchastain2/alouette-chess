
{**
  @abstract(Génération des coups.)
  Génération des coups, et fonctions utilisées pour l'évaluation des coups.
}

unit MoveGen;

interface

uses
  Chess, Board;

{** Génération des coups. }
function GenerateMoves(const APos: TPosition; var AList: array of TMove; out ACount: integer; const AQuick: boolean = FALSE; const ExtraPawnMoves: boolean = FALSE): TBoard; overload;
{** Cases pouvant être atteintes. }
function GenerateMoves(const APos: TPosition): TBoard; overload;
{** Nombre de coups possibles. }
function GetMovesCount(const APos: TPosition): integer;
(*
{** Nombre de coups de pion possibles. }
function PawnMovesCount(const APos: TPosition): integer;
*)
{** Cases pouvant être prises par les pions. }
function PotentialPawnCaptures(const APos: TPosition): TBoard;
{** Pour savoir si le joueur est en échec. }
function IsCheck(const APos: TPosition): boolean;
(*
{** Nombre de cases accessibles. }
function CountTargets(const APos: TPosition): integer;
*)
{** Disposition des pions. }
function PawnStruct(const APos: TPosition): integer;

implementation

uses
  SysUtils, Bitboards{, Journal};

function GenerateMoves(const APos: TPosition; var AList: array of TMove; out ACount: integer; const AQuick: boolean; const ExtraPawnMoves: boolean): TBoard;
var
  LCnt: integer = 0;

  procedure SaveMove(const i, j: integer; const pt: TPieceType; const mt: TMoveTypeSet = []);
  begin
    SwitchOn(result, CIdxToSqr[j]);
    Inc(LCnt);
    if not AQuick then
      if LCnt <= Length(AList) then
        AList[Pred(LCnt)] := EncodeMove(i, j, pt, mt);
  end;

const
  CPawn: array[boolean] of TPieceType = (ptWhitePawn, ptBlackPawn);
var
{ Toutes les pièces. }
  LPieces: TBoard;
  i, j, k: integer;
  LTargets, LActive, LPassive: TBoard;
begin
  LPieces := APos.Pieces[FALSE] or APos.Pieces[TRUE];
  LActive := APos.Pieces[APos.Side];
  LPassive := APos.Pieces[not APos.Side];
  result := 0; { Damier vide. }
  i := BsfQWord(QWord(LActive));
  while LActive <> 0 do
  begin
  { Pion. }
    if IsOn(APos.Pawns, CIdxToSqr[i]) then
    begin
      k := 8 - 16 * Ord(APos.Side);
      j := i + k;
      if not IsOn(LPieces, CIdxToSqr[j]) then
      begin
        if ((j div 8 = 7) and not APos.Side)
        or ((j div 8 = 0) and APos.Side) then
        begin
          SaveMove(i, j, CPawn[APos.Side], [mtPromotion]);
          SaveMove(i, j, CPawn[APos.Side], [mtPromotion, mtPromotionKnight]);
          SaveMove(i, j, CPawn[APos.Side], [mtPromotion, mtPromotionBishop]);
          SaveMove(i, j, CPawn[APos.Side], [mtPromotion, mtPromotionRook]);
        end else
          SaveMove(i, j, CPawn[APos.Side]);
        if ((j div 8 = 2) and not APos.Side)
        or ((j div 8 = 5) and APos.Side) then
        begin
          j := j + k;
          if not IsOn(LPieces, CIdxToSqr[j]) then
            SaveMove(i, j, CPawn[APos.Side]);
        end;
      end;
    { Captures }
      if i mod 8 > 0 then
      begin
        j := Pred(i + k);
        if j = APos.EnPassant then
          SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtEnPassant])
        else
          if IsOn(LPassive, CIdxToSqr[j]) or ExtraPawnMoves then
            if ((j div 8 = 7) and not APos.Side)
            or ((j div 8 = 0) and APos.Side) then
            begin
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionKnight]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionBishop]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionRook]);
            end else
              SaveMove(i, j, CPawn[APos.Side], [mtCapture]);
      end;
      if i mod 8 < 7 then
      begin
        j := Succ(i + k);
        if j = APos.EnPassant then
          SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtEnPassant])
        else
          if IsOn(LPassive, CIdxToSqr[j]) or ExtraPawnMoves then
            if ((j div 8 = 7) and not APos.Side)
            or ((j div 8 = 0) and APos.Side) then
            begin
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionKnight]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionBishop]);
              SaveMove(i, j, CPawn[APos.Side], [mtCapture, mtPromotion, mtPromotionRook]);
            end else
              SaveMove(i, j, CPawn[APos.Side], [mtCapture]);
      end;
    end else
  { Tour. }
    if IsOn(APos.Rooks, CIdxToSqr[i]) then
    begin
      LTargets := CTargets[ptRook, i] and not APos.Pieces[APos.Side];
      j := BsfQWord(QWord(LTargets));
      while LTargets <> 0 do
      begin
        if (CPath[i, j] and LPieces) = 0 then
          if IsOn(LPassive, CIdxToSqr[j]) then
            SaveMove(i, j, ptRook, [mtCapture])
          else
            SaveMove(i, j, ptRook);
        LTargets := LTargets and not CIdxToSqr[j];
        j := BsfQWord(QWord(LTargets));
      end;
    end else
  { Cavalier. }
    if IsOn(APos.Knights, CIdxToSqr[i]) then
    begin
      LTargets := CTargets[ptKnight, i] and not APos.Pieces[APos.Side];
      j := BsfQWord(QWord(LTargets));
      while LTargets <> 0 do
      begin
        if IsOn(LPassive, CIdxToSqr[j]) then
          SaveMove(i, j, ptKnight, [mtCapture])
        else
          SaveMove(i, j, ptKnight);
        LTargets := LTargets and not CIdxToSqr[j];
        j := BsfQWord(QWord(LTargets));
      end;
    end else
  { Fou. }
    if IsOn(APos.Bishops, CIdxToSqr[i]) then
    begin
      LTargets := CTargets[ptBishop, i] and not APos.Pieces[APos.Side];
      j := BsfQWord(QWord(LTargets));
      while LTargets <> 0 do
      begin
        if (CPath[i, j] and LPieces) = 0 then
          if IsOn(LPassive, CIdxToSqr[j]) then
            SaveMove(i, j, ptBishop, [mtCapture])
          else
            SaveMove(i, j, ptBishop);
        LTargets := LTargets and not CIdxToSqr[j];
        j := BsfQWord(QWord(LTargets));
      end;
    end else
  { Dame. }
    if IsOn(APos.Queens, CIdxToSqr[i]) then
    begin
      LTargets := CTargets[ptQueen, i] and not APos.Pieces[APos.Side];
      j := BsfQWord(QWord(LTargets));
      while LTargets <> 0 do
      begin
        if (CPath[i, j] and LPieces) = 0 then
          if IsOn(LPassive, CIdxToSqr[j]) then
            SaveMove(i, j, ptQueen, [mtCapture])
          else
            SaveMove(i, j, ptQueen);
        LTargets := LTargets and not CIdxToSqr[j];
        j := BsfQWord(QWord(LTargets));
      end;
    end else
  { Roi. }
    if IsOn(APos.Kings, CIdxToSqr[i]) then
    begin
      LTargets := CTargets[ptKing, i] and not APos.Pieces[APos.Side];
      j := BsfQWord(QWord(LTargets));
      while LTargets <> 0 do
      begin
        if IsOn(LPassive, CIdxToSqr[j]) then
          SaveMove(i, j, ptKing, [mtCapture])
        else
          SaveMove(i, j, ptKing);
        LTargets := LTargets and not CIdxToSqr[j];
        j := BsfQWord(QWord(LTargets));
      end;
    end;
    LActive := LActive and not CIdxToSqr[i];
    i := BsfQWord(QWord(LActive));
  end;
  ACount := LCnt;
end;

function GenerateMoves(const APos: TPosition): TBoard;
var
  LList: array[0..0] of integer;
  LCount: integer;
begin
  Initialize(LList);
  result := GenerateMoves(APos, LList, LCount, TRUE);
end;

function GetMovesCount(const APos: TPosition): integer;
var
  LList: array[0..0] of integer;
begin
  Initialize(LList);
  GenerateMoves(APos, LList, result, TRUE);
end;

(*
function PawnMovesCount(const APos: TPosition): integer;
var
  LList: array[byte] of integer;
  LCount, i: integer;
begin
  Initialize(LList);
  GenerateMoves(APos, LList, LCount);
  result := 0;
  for i := 0 to Pred(LCount) do
    if PieceType(LList[i]) in [ptWhitePawn, ptBlackPawn] then
      Inc(result);
end;
*)

function PotentialPawnCaptures(const APos: TPosition): TBoard;
var
  LPawnType: TPieceType;
  LPawns, LTargets: TBoard;
  LFr, LTo: integer;
begin
  if APos.Side then
    LPawnType := ptBlackPawn
  else
    LPawnType := ptWhitePawn;
  result := 0; { Damier vide. }

  LPawns := APos.Pieces[APos.Side] and APos.Pawns;
  while LPawns <> 0 do
  begin
    LFr := BsfQWord(QWord(LPawns)); LPawns := LPawns and not CIdxToSqr[LFr];
    
    LTargets := CTargets[LPawnType, LFr];
    while LTargets <> 0 do
    begin
      LTo := BsfQWord(QWord(LTargets)); LTargets := LTargets and not CIdxToSqr[LTo];
      
      if not IsOn(APos.Pieces[APos.Side], CIdxToSqr[LTo]) then
          SwitchOn(result, CIdxToSqr[LTo]);
    end;
  end;
end;

function IsCheck(const APos: TPosition): boolean;
var
  LPos: TPosition;
begin
  LPos := APos;
  LPos.Side := not LPos.Side;
  result := (GenerateMoves(LPos) and LPos.Kings) <> 0;
end;

(*
function CountTargets(const APos: TPosition): integer;
var
  LFr, LTo: integer;
  LPieceType: TPieceType;
  LPieces, LTargets: TBoard;
begin
  result := 0;
  LPieces := APos.Pieces[APos.Side];
  while LPieces <> 0 do
  begin
    LFr := BsfQWord(QWord(LPieces)); LPieces := LPieces and not CIdxToSqr[LFr];
    LPieceType := PieceTypeIdx(APos, LFr);
    LTargets := CTargets[LPieceType, LFr] and not APos.Pieces[APos.Side];
    if LPieceType in [ptWhitePawn, ptBlackPawn, ptKnight] then
      Inc(result, PopCnt(QWord(LTargets)))
    else
      if LPieceType in [ptBishop, ptRook, ptQueen] then
        while LTargets <> 0 do
        begin
          LTo := BsfQWord(QWord(LTargets)); LTargets := LTargets and not CIdxToSqr[LTo];
          if (CPath[LFr, LTo] and (APos.Pieces[APos.Side] or APos.Pieces[not APos.Side])) = 0 then
            Inc(result);
        end;
  end;
end;
*)

function PawnStruct(const APos: TPosition): integer;
var
  LActivePawns: TBoard;
  i, j, k: integer;
begin
  result := 0;
  LActivePawns := APos.Pieces[APos.Side] and APos.Pawns;
  while LActivePawns <> 0 do
  begin
    i := BsfQWord(QWord(LActivePawns)); LActivePawns := LActivePawns and not CIdxToSqr[i];
    k := 16 * Ord(APos.Side) - 8;
  { Protection côté A. }
    if i mod 8 > 0 then
    begin
      j := Pred(i + k);
      if IsOn(APos.Pieces[APos.Side] and APos.Pawns, CIdxToSqr[j]) then
        Inc(result);
    end;
  { Protection côté H. }
    if i mod 8 < 7 then
    begin
      j := Succ(i + k);
      if IsOn(APos.Pieces[APos.Side] and APos.Pawns, CIdxToSqr[j]) then
        Inc(result);
    end;
  { Colonne sans pion adverse. }
    if (APos.Pieces[not APos.Side] and APos.Pawns and CCol[i mod 8]) = 0 then
      Inc(result, 0);
  end;
end;

end.
