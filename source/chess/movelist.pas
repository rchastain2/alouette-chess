
{**
@abstract(Liste de coups.)
@longcode(#
  // chesstypes.pas
  
  TMoveInfo = (miCapture, miH_Castling, miA_Castling, miKnight, miBishop, miRook, miQueen);
  TMoveInfoSet = set of TMoveInfo;
  
  PMove = ^TMove;
  TMove = record
    FX1, FY1, FX2, FY2: integer;
    FType: TPieceTypeWide;
    FColor: TPieceColorWide;
    FInfo: TMoveInfoSet;
  end;
#)
}

unit MoveList;

interface

uses
  SysUtils, Classes, ChessTypes, San, ChessUtils;
  
type
  TMoveList = class
    private
      FList: TFPList;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Append(const AMove: TMove); overload;
      procedure Append(const AX1, AY1, AX2, AY2: integer; const AType: TPieceTypeWide; const AColor: TPieceColorWide; const AInfo: TMoveInfoSet); overload;
      procedure Append(const AX1, AY1, AX2, AY2: integer; const AType: TPieceTypeWide; const AColor: TPieceColorWide; const ACapture: boolean); overload;
      procedure Clear;
      function Count: integer;
      function GetMove(const AIndex: integer): TMove;
      function GetMoveStr(const AIndex: integer): string;
      function IndexOf(const AX1, AY1, AX2, AY2: integer; const APromotion: TPieceTypeWide): integer; overload;
      function IndexOf(const APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate: string): integer; overload;
      function IndexOf(const AMove: string): integer; overload;
  end;

const
  CNotFound = -1;
  
implementation
(*
uses
  ChessUtils;
*)

constructor TMoveList.Create;
begin
  inherited Create;
  FList := TFPList.Create;
end;

destructor TMoveList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TMoveList.Append(const AMove: TMove); overload;
var
  LPMove: PMove;
begin
  New(LPMove);
  LPMove^ := AMove;
  FList.Add(LPMove);
end;

procedure TMoveList.Append(const AX1, AY1, AX2, AY2: integer; const AType: TPieceTypeWide; const AColor: TPieceColorWide; const AInfo: TMoveInfoSet); overload;
var
  LMove: TMove;
begin
  LMove.FX1 := AX1;
  LMove.FY1 := AY1;
  LMove.FX2 := AX2;
  LMove.FY2 := AY2;
  LMove.FType := AType;
  LMove.FColor := AColor;
  LMove.FInfo := AInfo;
  Append(LMove);
end;

procedure TMoveList.Append(const AX1, AY1, AX2, AY2: integer; const AType: TPieceTypeWide; const AColor: TPieceColorWide; const ACapture: boolean);
var
  LInfo: TMoveInfoSet;
begin
  if ACapture then
    LInfo := [miCapture]
  else
    LInfo := [];
  Append(AX1, AY1, AX2, AY2, AType, AColor, LInfo);
end;

procedure TMoveList.Clear;
var
  i: integer;
begin
  while FList.Count > 0 do
  begin
    i := Pred(FList.Count);
    Dispose(PMove(FList.Items[i]));
    FList.Delete(i);
  end;
end;

function TMoveList.Count: integer;
begin
  result := FList.Count;
end;

function TMoveList.GetMove(const AIndex: integer): TMove;
begin
  if (AIndex >= 0) and (AIndex < FList.Count) then
    result := PMove(FList.Items[AIndex])^
  else
  begin
{$IFDEF LINUX}
    WriteLn(ErrOutput, '[TMoveList.GetMove] Index (', AIndex, ') out of bounds');
{$ENDIF}
    result := CNoMove;
  end;
end;

function TMoveList.GetMoveStr(const AIndex: integer): string;
var
  LMove: TMove;
begin
  LMove := GetMove(AIndex);
  result := MoveToStr(LMove);
end;

function TMoveList.IndexOf(const AX1, AY1, AX2, AY2: integer; const APromotion: TPieceTypeWide): integer;
var
  LMove: TMove;
  i: integer;
begin
  result := CNotFound;
  i := 0;
  while (i < FList.Count) and (result = CNotFound) do
  begin
    LMove := PMove(FList.Items[i])^;
    with LMove do if (FX1 = AX1) and (FY1 = AY1) and (FX2 = AX2) and (FY2 = AY2) then
      result := i;
    Inc(i);
  end;
end;

function TMoveList.IndexOf(const APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate: string): integer;
var
  LMove: TMove;
  i: integer;
  x1, y1, x2, y2: integer;
  LType: TPieceTypeWide;
  LCapture: boolean;
begin
  //WriteLn('    TMoveList.IndexOf(', APiece, ',', ADisambiguation, ',', ACapture, ',', ASquareOrCastling, ',', APromotion, ',', ACheckOrCheckmate, ') ');
  result := CNotFound;
  if (ASquareOrCastling = 'O-O') or (ASquareOrCastling = '0-0') then
  begin
    i := 0;
    while (i < FList.Count) and (result = CNotFound) do
    begin
      LMove := PMove(FList.Items[i])^;
      with LMove do if (FType = ptKing) and (miH_Castling in FInfo) then // miH_Castling, miA_Castling
        result := i;
      Inc(i);
    end;
  end else
    if (ASquareOrCastling = 'O-O-O') or (ASquareOrCastling = '0-0-0') then
    begin
      i := 0;
      while (i < FList.Count) and (result = CNotFound) do
      begin
        LMove := PMove(FList.Items[i])^;
        with LMove do if (FType = ptKing) and (miA_Castling in FInfo) then
          result := i;
        Inc(i);
      end;
    end else
    begin
      TryDecodePiece(APiece, LType);
      TryDecodeDisambiguation(ADisambiguation, x1, y1);
      LCapture := Length(ACapture) > 0;
      TryDecodeSquare(ASquareOrCastling, x2, y2);
      
      i := 0;
      while (i < FList.Count) and (result = CNotFound) do
      begin
        LMove := PMove(FList.Items[i])^;
        with LMove do if (FX2 = x2) and (FY2 = y2) then
        begin
          if (LType = ptNil) and (FType <> ptPawn) or (LType <> ptNil) and (FType <> LType) then
            //WriteLn('    [TMoveList.IndexOf line ', {$I %LINE%}, '] DIFF LType ', LType, ' FType ', FType)
          else if (x1 <> 0) and (FX1 <> x1) or (y1 <> 0) and (FY1 <> y1) then
            //WriteLn('    [TMoveList.IndexOf line ', {$I %LINE%}, '] DIFF x1 ', x1, ' FX1 ', FX1, ' y1 ', y1, ' FY1 ', FY1)
          else if (miCapture in FInfo) xor LCapture then
            //WriteLn('    [TMoveList.IndexOf line ', {$I %LINE%}, '] DIFF miCapture in FInfo ', miCapture in FInfo, ' LCapture ', LCapture)
          else
            result := i;
        end;
        Inc(i);
      end;
    end;
  //WriteLn('    [TMoveList.IndexOf ', {$I %LINE%}, '] result ', result);
end;

function TMoveList.IndexOf(const AMove: string): integer;
var
  x1, y1, x2, y2: integer;
  LPromotion: TPieceTypeWide;
  APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate: string;
begin
  result := CNotFound;
  if TryDecodeLan(AMove, x1, y1, x2, y2, LPromotion) then
    result := IndexOf(x1, y1, x2, y2, LPromotion)
  else
    if TryDecodeSan(AMove, APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate) then
      result := IndexOf(APiece, ADisambiguation, ACapture, ASquareOrCastling, APromotion, ACheckOrCheckmate);
end;

end.
