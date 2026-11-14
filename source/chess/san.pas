
{**
@abstract(Lecture du format @html(<a href="http://www.saremba.de/chessgml/standards/pgn/pgn-complete.htm#c8.2.3">SAN</a>) par les expressions régulières.)
}

unit San;

interface

uses
  ChessTypes;

function TryDecodeLan(const AMove: string; out x1, y1, x2, y2: integer; out APromotion: TPieceTypeWide): boolean; overload;
function TryDecodeSan(const AMove: string; out APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate: string): boolean; overload;

procedure TryDecodePiece(const APiece: string; out AType: TPieceTypeWide);
procedure TryDecodeDisambiguation(const ADisambiguation: string; out x, y: integer);
procedure TryDecodeSquare(const ASquare: string; out x, y: integer);

implementation

uses
  SysUtils, RegExpr;

const
  CFile = '([a-h])';
  CRank = '([1-8])';
  CSeparator = '[-x]?';
  CPromotion = '=?([nbrqNBRQ])?';
  CPatternLan = '^' + CFile + CRank + CSeparator + CFile + CRank + CPromotion;

  CFile2 = '[a-h]';
  CRank2 = '[1-8]';
  CPromotion2 = '[nbrqNBRQ]';
  CKingSideCastling = 'O-O|0-0';
  CQueenSideCastling = 'O-O-O|0-0-0';
  CPiece = '[PNBRQK]';
  CDisambiguation = CFile2 + '|' + CRank2 + '|' + CFile2 + CRank2;
  CCapture = 'x';
  CSquareOrCastling = CFile2 + CRank2 + '|' + CQueenSideCastling + '|' + CKingSideCastling;
  CCheckOrCheckmate = '[+#]';
  CSanMove =
    '^(' + CPiece            + ')?' +
    '(' + CDisambiguation   + ')?' +
    '(' + CCapture          + ')?' +
    '(' + CSquareOrCastling + ')' +
    '=?(' + CPromotion2        + ')?' +
    '(' + CCheckOrCheckmate + ')?';

function TryDecodeLan(const AMove: string; out x1, y1, x2, y2: integer; out APromotion: TPieceTypeWide): boolean;
var
  LExpr: TRegExpr;
begin
  LExpr := TRegExpr.Create(CPatternLan);
  with LExpr do
  try
    result := Exec(AMove);
    if result then
    begin
      x1 := Succ(Ord(Match[1][1]) - Ord('a'));
      y1 := Succ(Ord(Match[2][1]) - Ord('1'));
      x2 := Succ(Ord(Match[3][1]) - Ord('a'));
      y2 := Succ(Ord(Match[4][1]) - Ord('1'));
      
      if Length(Match[5]) = 0 then
        APromotion := ptNil
      else
        case UpCase(Match[5][1]) of
          'N': APromotion := ptKnight;
          'B': APromotion := ptBishop;
          'R': APromotion := ptRook;
          'Q': APromotion := ptQueen;
        end;
        
    end;
  finally
    LExpr.Free;
  end;
end;

function TryDecodeSan(const AMove: string; out APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate: string): boolean;
var
  LExpr: TRegExpr;
 {i: integer;}
begin
  //Write('    TryDecodeSan(', AMove, ') ');
  LExpr := TRegExpr.Create(CSanMove);
  with LExpr do
  try
    result := Exec(AMove);// WriteLn(result);
    if result then
    begin
      (*
      for i := 0 to 6 do
      begin
        WriteLn('Match[', i, ']=''', Match[i], '''');
        Flush(Output);
      end;
      *)
      APiece := Match[1];
      ADisambiguation := Match[2];
      ACapture := Match[3];
      ASquareOrCastling := Match[4];
      APromotion := Match[5];
      ACheckOrCheckmate := Match[6];
    end else
    begin
      APiece := EmptyStr;
      ADisambiguation := EmptyStr;
      ACapture := EmptyStr;
      ASquareOrCastling := EmptyStr;
      APromotion := EmptyStr;
      ACheckOrCheckmate := EmptyStr;
    end;
  finally
    LExpr.Free;
  end;
end;

procedure TryDecodePiece(const APiece: string; out AType: TPieceTypeWide);
begin
  AType := ptNil;
  if Length(APiece) > 0 then
    case APiece[1] of
      'P': AType := ptPawn;
      'N': AType := ptKnight;
      'B': AType := ptBishop;
      'R': AType := ptRook;
      'Q': AType := ptQueen;
      'K': AType := ptKing;
    end;
end;

procedure TryDecodeDisambiguation(const ADisambiguation: string; out x, y: integer);
var
  i: integer;
begin
  x := 0;
  y := 0;
  if Length(ADisambiguation) > 0 then
    for i := 1 to Length(ADisambiguation) do
      if ADisambiguation[i] in ['a'..'h'] then x := Succ(Ord(ADisambiguation[i]) - Ord('a')) else
      if ADisambiguation[i] in ['1'..'8'] then y := Succ(Ord(ADisambiguation[i]) - Ord('1'));
end;

procedure TryDecodeSquare(const ASquare: string; out x, y: integer);
begin
  if (Length(ASquare) = 2)
  and (ASquare[1] in ['a'..'h'])
  and (ASquare[2] in ['1'..'8']) then
  begin
    x := Ord(ASquare[1]) - Ord('a') + 1;
    y := Ord(ASquare[2]) - Ord('1') + 1;
  end else
  begin
    x := 0;
    y := 0;
  end;
end;

end.
