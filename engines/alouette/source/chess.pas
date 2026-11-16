
{**
  @abstract(Lecture et écriture d'une position dans une chaîne de caractères au format EPD.)
  Les quatre groupes de caractères d'une chaîne EPD correspondent aux quatre premiers groupes de caractères d'une chaîne @html(<a href="http://kirill-kryukov.com/chess/doc/fen.html">FEN</a>).
}

unit Chess;

interface

uses
  Board, Bitboards;

const
  CWhite = FALSE;
  CBlack = TRUE;
  CNil = -1;
  
type
  {**
    Droit de roquer.
    Lorsque le roque est permis, la variable indique la colonne où se trouve la tour (de 0 à 7).
    Lorsque le roque est interdit, la variable reçoit la valeur -1 (CNil).
  }
  TCastlingData = record
    HRook,
    ARook: integer;
  end;
  
  TCastling = array[boolean] of TCastlingData;
  
  TPosition = record
    Pieces: array[boolean] of TBoard;
    Pawns,
    Rooks,
    Knights,
    Bishops,
    Queens,
    Kings: TBoard;
    Side: boolean;
    Castling: TCastling;
    EnPassant: integer;
    KingSquare: array[boolean] of TBoard;
  end;
  
const
  CNewPos: TPosition = (
    Pieces: (0, 0);
    Pawns: 0;
    Rooks: 0;
    Knights: 0;
    Bishops: 0;
    Queens: 0;
    Kings: 0;
    Side: FALSE;
    Castling: (
      (HRook: CNil; ARook: CNil),
      (HRook: CNil; ARook: CNil)
    );
    EnPassant: CNil;
    KingSquare: (0, 0)
  );

const
  CStartPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -';
  CColC = 2;
  CColD = 3;
  CColE = 4;
  CColF = 5;
  CColG = 6;
  CRow1 = 0;
  CRow8 = 7;
  CCastlingRow: array[boolean] of integer = (CRow1, CRow8);
  
type
  TRookSquare = array[boolean] of integer;
  
const
  CATCR: TRookSquare = (F1, F8); { Arrivée tour côté roi.  }
  CATCD: TRookSquare = (D1, D8); { Arrivée tour côté dame. }
  CDTCR: TRookSquare = (H1, H8); { Départ tour côté roi.   }
  CDTCD: TRookSquare = (A1, A8); { Départ tour côté dame.  }

function IsValidFen(const AFen: string): boolean;
function EncodePosition(const APos: string = CStartPos; const AChess960: boolean = FALSE): TPosition;
function DecodePosition(const APos: TPosition; const AChess960: boolean = FALSE): string;
function SquareToCol(const ASqr: TBoard): integer;
function PosToText(const APos: TPosition): string;

implementation

uses
  SysUtils, Classes;

const
  CSideSymbol: array[boolean] of char = ('w', 'b');
  
procedure InitializeCastling(out ACastling: TCastling);
begin
  ACastling[CWhite].HRook := CNil;
  ACastling[CWhite].ARook := CNil;
  ACastling[CBlack].HRook := CNil;
  ACastling[CBlack].ARook := CNil;
end;

function DecodeTraditionalCastlingString(const ACastlingStr: string): TCastling;
begin
  InitializeCastling(result);
  if Pos('K', ACastlingStr) > 0 then result[CWhite].HRook := 7;
  if Pos('Q', ACastlingStr) > 0 then result[CWhite].ARook := 0;
  if Pos('k', ACastlingStr) > 0 then result[CBlack].HRook := 7;
  if Pos('q', ACastlingStr) > 0 then result[CBlack].ARook := 0;
end;

function DecodeCastlingString(const ACastlingStr: string; const APos: TPosition): TCastling;
const
  CChar: array[boolean, 0..7] of char = (
    ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'),
    ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h')
  );
  CKingSide: array[boolean] of char = ('K', 'k');
  CQueenSide: array[boolean] of char = ('Q', 'q');
var
  LColor: boolean;
  LColumn, LKingCol, LRow: integer;
  LRooks: TBoard;
begin
  InitializeCastling(result);
  for LColor := CWhite to CBlack do
    if APos.KingSquare[LColor] <> 0 then
    begin
      LKingCol := SquareToCol(APos.KingSquare[LColor]);
      LRow := CCastlingRow[LColor];
      LRooks := APos.Rooks and APos.Pieces[LColor];
      for LColumn := 7 downto Succ(LKingCol) do if Pos(CChar[LColor, LColumn], ACastlingStr) > 0 then begin result[LColor].HRook := LColumn; Break; end;
      for LColumn := 0     to Pred(LKingCol) do if Pos(CChar[LColor, LColumn], ACastlingStr) > 0 then begin result[LColor].ARook := LColumn; Break; end;
      if (result[LColor].HRook = CNil) and (Pos(CKingSide[LColor], ACastlingStr) > 0) then
        for LColumn := 7 downto Succ(LKingCol) do if IsOn(LRooks, CCrdToSqr[LColumn, LRow]) then begin result[LColor].HRook := LColumn; Break; end;
      if (result[LColor].ARook = CNil) and (Pos(CQueenSide[LColor], ACastlingStr) > 0) then
        for LColumn := 0     to Pred(LKingCol) do if IsOn(LRooks, CCrdToSqr[LColumn, LRow]) then begin result[LColor].ARook := LColumn; Break; end;
    end;
end;

function EncodeCastlingString(const ACastling: TCastling; const AChess960: boolean = FALSE): string;
begin
  result := '';
  if AChess960 then
  begin
    with ACastling[CWhite] do begin
      if (HRook >= 0) and (HRook <= 7) then result := Concat(result, Chr(HRook + Ord('A')));
      if (ARook >= 0) and (ARook <= 7) then result := Concat(result, Chr(ARook + Ord('A')));
    end;
    with ACastling[CBlack] do begin
      if (HRook >= 0) and (HRook <= 7) then result := Concat(result, Chr(HRook + Ord('a')));
      if (ARook >= 0) and (ARook <= 7) then result := Concat(result, Chr(ARook + Ord('a')));
    end;
  end else
  begin
    if ACastling[CWhite].HRook <> CNil then result := Concat(result, 'K');
    if ACastling[CWhite].ARook <> CNil then result := Concat(result, 'Q');
    if ACastling[CBlack].HRook <> CNil then result := Concat(result, 'k');
    if ACastling[CBlack].ARook <> CNil then result := Concat(result, 'q');
  end;
  if result = '' then
    result := '-';
end;

function SquareToCol(const ASqr: TBoard): integer;
var
  x: integer;
begin
  result := CNil;
  x := 0;
  while (result = CNil) and (x <= 7) do
    if IsOn(CCol[x], ASqr) then
      result := x
    else
      Inc(x);
end;
  
function IsValidFen(const AFen: string): boolean;
var
  LFields: TStringList;
  LBoard, LEnPassant: string;
  x, y, i: integer;
begin
  result := FALSE;
  LFields := TStringList.Create;
  try
    LFields.DelimitedText := AFen;
    if not (LFields.Count in [4, 6]) then
      Exit;
    LBoard := LFields[0];
    x := 0;
    y := 7;
    for i := 1 to Length(LBoard) do
      case LBoard[i] of
        '/':
          begin
            if (x <> 8) or (y = 0) then
              Exit;
            x := 0;
            Dec(y);
          end;
        '1'..'8':
          Inc(x, Ord(LBoard[i]) - Ord('0'));
        'P', 'R', 'N', 'B', 'Q', 'K', 'p', 'r', 'n', 'b', 'q', 'k':
          Inc(x);
        else
          Exit;
      end;
    if (x <> 8) or (y <> 0) then
      Exit;
    if (LFields[1] <> CSideSymbol[CWhite]) and (LFields[1] <> CSideSymbol[CBlack]) then
      Exit;
    LEnPassant := LFields[3];
    result := (LEnPassant = '-')
      or (Length(LEnPassant) = 2) and (LEnPassant[1] in ['a'..'h']) and (LEnPassant[2] in ['1'..'8']);
  finally
    LFields.Free;
  end;
end;

function EncodePosition(const APos: string; const AChess960: boolean): TPosition;
const
  CEpdCount = 4;
  CFenCount = 6;
var
  x, y, i: integer;
  c: char;
  LSqr: TBoard;
begin
  result := CNewPos;
  with TStringList.Create, result do
  begin
    DelimitedText := APos;
    Assert(Count in [CEpdCount, CFenCount]);
    begin
      x := 0;
      y := 7;
      i := 1;
      while i <= Length(Strings[0]) do
      begin
        c := Strings[0][i];
        case c of
          '/':
            begin
              x := 0;
              Dec(y);
            end;
          '1'..'8':
            while c > '0' do
            begin
              Inc(x);
              Dec(c);
            end;
        else
          begin
            LSqr := CCrdToSqr[x, y];
            SwitchOn(Pieces[c in ['a'..'z']], LSqr);
            case UpCase(c) of
              'P': SwitchOn(Pawns, LSqr);
              'R': SwitchOn(Rooks, LSqr);
              'N': SwitchOn(Knights, LSqr);
              'B': SwitchOn(Bishops, LSqr); 
              'Q': SwitchOn(Queens, LSqr);
              'K':
                begin
                  SwitchOn(Kings, LSqr);
                  KingSquare[c = 'k'] := LSqr;
                end;
            end;
            Inc(x);
          end;
        end;
        Inc(i);
      end;
      Side := Strings[1] = CSideSymbol[CBlack];
      if AChess960 then
        Castling := DecodeCastlingString(Strings[2], result)
      else
        Castling := DecodeTraditionalCastlingString(Strings[2]);
      if Strings[3] = '-' then
        EnPassant := CNil
      else
        EnPassant := DecodeSquareName(Strings[3]);
    end;
    Free;
  end;
end;

function DecodePosition(const APos: TPosition; const AChess960: boolean): string;
var
  x, y, n: integer;
  c: char;
  LEnPassantStr: string;
begin
  result := '';
  with APos do
  begin
    x := 0;
    y := 7;
    while y >= 0 do
    begin
      if (Pieces[FALSE] or Pieces[TRUE]) and CCrdToSqr[x, y] = 0 then
      begin
        n := 0;
        while (x + n <= 7) and ((Pieces[FALSE] or Pieces[TRUE]) and CCrdToSqr[x + n, y] = 0) do
          Inc(n);
        result := Concat(result, IntToStr(n));
        Inc(x, n);
      end else
      begin
        c := '?';
        if IsOn(Pawns,        CCrdToSqr[x, y]) then c := 'P' else
        if IsOn(Rooks,        CCrdToSqr[x, y]) then c := 'R' else
        if IsOn(Knights,      CCrdToSqr[x, y]) then c := 'N' else
        if IsOn(Bishops,      CCrdToSqr[x, y]) then c := 'B' else
        if IsOn(Queens,       CCrdToSqr[x, y]) then c := 'Q' else
        if IsOn(Kings,        CCrdToSqr[x, y]) then c := 'K';
        if IsOn(Pieces[TRUE], CCrdToSqr[x, y]) then
          c := Chr(Ord(c) + 32);
        result := Concat(result, c);
        Inc(x);
      end;
      if x > 7 then
      begin
        if y > 0 then
          result := Concat(result, '/');
        x := 0;
        Dec(y);
      end;
    end;
    if EnPassant = CNil then
      LEnPassantStr := '-'
    else
      LEnPassantStr := CSqrToStr[EnPassant];
    result := Format(
      '%s %s %s %s',
      [
        result,
        CSideSymbol[Side],
        EncodeCastlingString(Castling, AChess960),
        LEnPassantStr
      ]
    );
  end;
end;

function PosToText(const APos: TPosition): string;
const
  CActive: array[boolean] of string = ('', ' *');
const
  CFormat =
    '+  A B C D E F G H  +%s'+ LineEnding +
    '8 |%s|%s|%s|%s|%s|%s|%s|%s| 8'+ LineEnding +
    '7 |%s|%s|%s|%s|%s|%s|%s|%s| 7'+ LineEnding +
    '6 |%s|%s|%s|%s|%s|%s|%s|%s| 6'+ LineEnding +
    '5 |%s|%s|%s|%s|%s|%s|%s|%s| 5'+ LineEnding +
    '4 |%s|%s|%s|%s|%s|%s|%s|%s| 4'+ LineEnding +
    '3 |%s|%s|%s|%s|%s|%s|%s|%s| 3'+ LineEnding +
    '2 |%s|%s|%s|%s|%s|%s|%s|%s| 2'+ LineEnding +
    '1 |%s|%s|%s|%s|%s|%s|%s|%s| 1'+ LineEnding +
    '+  A B C D E F G H  +%s'+ LineEnding +
    'Castling: %s'+ LineEnding +
    'En passant: %s'+ LineEnding +
    'FEN: %s';
var
  x, y: integer;
  c: array[0..7, 0..7] of char;
  i: integer;
  s: string;
begin
  for y := 7 downto 0 do
    for x := 0 to 7 do
    begin
      i := 8 * y + x;
      c[x, y] := '?';
      if IsOnIdx(APos.Pawns,   i) then c[x, y] := 'p' else
      if IsOnIdx(APos.Rooks,   i) then c[x, y] := 'r' else
      if IsOnIdx(APos.Knights, i) then c[x, y] := 'n' else
      if IsOnIdx(APos.Bishops, i) then c[x, y] := 'b' else
      if IsOnIdx(APos.Queens,  i) then c[x, y] := 'q' else
      if IsOnIdx(APos.Kings,   i) then c[x, y] := 'k' else
        if (x + y) mod 2 = 1 then
          c[x, y] := '.'
        else
        c[x, y] := ':';
      if IsOnIdx(APos.Pieces[FALSE], i) then
        c[x, y] := UpCase(c[x, y]);
    end;
    if APos.EnPassant = CNil then
      s := '-'
    else
      s := CSqrToStr[APos.EnPassant];
  result := Format(CFormat, [
    CActive[APos.Side],
    c[0, 7], c[1, 7], c[2, 7], c[3, 7], c[4, 7], c[5, 7], c[6, 7], c[7, 7],
    c[0, 6], c[1, 6], c[2, 6], c[3, 6], c[4, 6], c[5, 6], c[6, 6], c[7, 6],
    c[0, 5], c[1, 5], c[2, 5], c[3, 5], c[4, 5], c[5, 5], c[6, 5], c[7, 5],
    c[0, 4], c[1, 4], c[2, 4], c[3, 4], c[4, 4], c[5, 4], c[6, 4], c[7, 4],
    c[0, 3], c[1, 3], c[2, 3], c[3, 3], c[4, 3], c[5, 3], c[6, 3], c[7, 3],
    c[0, 2], c[1, 2], c[2, 2], c[3, 2], c[4, 2], c[5, 2], c[6, 2], c[7, 2],
    c[0, 1], c[1, 1], c[2, 1], c[3, 1], c[4, 1], c[5, 1], c[6, 1], c[7, 1],
    c[0, 0], c[1, 0], c[2, 0], c[3, 0], c[4, 0], c[5, 0], c[6, 0], c[7, 0],
    CActive[not APos.Side],
    EncodeCastlingString(APos.Castling, TRUE),
    s,
    DecodePosition(APos, TRUE)
  ]);
end;

end.

