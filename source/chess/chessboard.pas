
{**
@abstract(Unité contenant la classe TChessPosition.)
}
unit Chessboard;

interface

uses
  SysUtils, Classes, Math, ChessTypes, Fen, ChessUtils, MoveList;

type
  TChessPosition = class
    private
      FData: TPositionData;
      FCheck: boolean;
      FCastlingCheck: array[TCastling] of boolean;
      FList: TMoveList;
      FKingCheckedX: integer;
      FKingCheckedY: integer;
    public
      constructor Create; overload;
      constructor Create(const AFENRecord: string); overload;
      constructor Create(const AData: TPositionData); overload;
      destructor Destroy; override;
      function FENRecord(const AFrc: boolean = TRUE): string;
      function InsufficientMaterial: boolean;
      procedure GenerateMoves1(const AColor: TPieceColor);
      procedure GenerateMoves2(const AColor: TPieceColor);
      procedure GenerateMoves3(const AColor: TPieceColor);
      procedure GenerateCastlingMove(const ACastling: TCastling);
      function IsCheck(const AColor: TPieceColor): boolean;
      function IsCastlingCheck(const ACastling: TCastling): boolean;
      {** Procédure pour savoir si le joueur est en échec et s'il est empêché de roquer. }
      procedure SetVariables(const AShort: boolean);
      procedure DoMove(const AMove: {$IFDEF STRLIST}string{$ELSE}TMove{$ENDIF}; const APromo: TPieceType = ptQueen);
      procedure SetActiveColor(const AColor: TPieceColor);
      function ToStr(): string;
      property Data: TPositionData read FData;
      property List: TMoveList read FList;
      property Active: TPieceColor read FData.FActive write SetActiveColor;
      property Check: boolean read FCheck;
      property KingCheckedX: integer read FKingCheckedX;
      property KingCheckedY: integer read FKingCheckedY;
  end;

implementation

constructor TChessPosition.Create;
begin
  inherited Create;
  if FList = nil then
    FList := TMoveList.Create
  else
    FList.Clear;
  FKingCheckedX := 0;
  FKingCheckedY := 0;
end;

constructor TChessPosition.Create(const AFENRecord: string);
begin
  Create;
  FData := EncodePositionData(AFENRecord);
end;

constructor TChessPosition.Create(const AData: TPositionData);
begin
  Create;
  FData := AData;
end;

destructor TChessPosition.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TChessPosition.FENRecord(const AFrc: boolean): string;
begin
  result := DecodePositionData(FData, AFrc);
end;

function TChessPosition.InsufficientMaterial: boolean;
var
  x, y, n: integer;
begin
  result := FALSE;
  n := 0;
  for x := 1 to 8 do
    for y := 1 to 8 do
    begin
      case FData.FBoard[x, y].FType of
        ptPawn, ptRook, ptQueen:
          Exit;
        ptKnight, ptBishop:
          Inc(n);
      end;
      if n > 1 then
        Exit;
    end;
  result := TRUE;
end;

procedure TChessPosition.GenerateMoves1(const AColor: TPieceColor);
var
  x1, y1, x2, y2: integer;
  i, i1, i2: integer;
begin
  FList.Clear;
  i1 := 0;
  i2 := 0;
  for x1 := 1 to 8 do
    for y1 := 1 to 8 do
      if (FData.FBoard[x1, y1].FColor = AColor) then
        case FData.FBoard[x1, y1].FType of
          ptPawn:
            begin
              if AColor = pcWhite then
              begin
                i1 := 1;
                i2 := 2;
              end else
              begin
                i1 := 3;
                i2 := 4;
              end;
              for i := i1 to i2 do
                if TargetSquare(x1, y1, i, x2, y2)
                and (FData.FBoard[x2, y2].FColor = OtherColor(AColor))
                then
                  FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, [miCapture]);
            end;
          
          ptKnight:
            for i := 9 to 16 do
              if TargetSquare(x1, y1, i, x2, y2)
              and (FData.FBoard[x2, y2].FColor <> AColor) then
                FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, FData.FBoard[x2, y2].FColor = OtherColor(AColor));
          
          ptBishop, ptRook, ptQueen:
            begin
              case FData.FBoard[x1, y1].FType of
                ptBishop:
                  begin
                    i1 := 1;
                    i2 := 4;
                  end;
                ptRook:
                  begin
                    i1 := 5;
                    i2 := 8;
                  end;
                ptQueen:
                  begin
                    i1 := 1;
                    i2 := 8;
                  end;
              end;
              
              for i := i1 to i2 do
              begin
                x2 := x1;
                y2 := y1;
                repeat
                  if TargetSquare(x2, y2, i, x2, y2)
                  and (FData.FBoard[x2, y2].FColor <> AColor) then
                    FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, FData.FBoard[x2, y2].FColor = OtherColor(AColor))
                  else
                    Break;
                until FData.FBoard[x2, y2].FType <> ptNil;
              end;
            end;
          
          ptKing:
            for i := 1 to 8 do
              if TargetSquare(x1, y1, i, x2, y2)
              and (FData.FBoard[x2, y2].FColor <> AColor) then
                FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, FData.FBoard[x2, y2].FColor = OtherColor(AColor));
        end;
end;

procedure TChessPosition.GenerateMoves2(const AColor: TPieceColor);
var
  x1, y1, x2, y2: integer;
  i, i1, i2: integer;
begin
  for x1 := 1 to 8 do
    for y1 := 1 to 8 do
      if FData.FBoard[x1, y1].FColor = AColor then
        case FData.FBoard[x1, y1].FType of
          ptPawn:
            begin
              if AColor = pcWhite then
              begin
                i1 := 1;
                i2 := 2;
              end else
              begin
                i1 := 3;
                i2 := 4;
              end;
              for i := i1 to i2 do
                if TargetSquare(x1, y1, i, x2, y2)
                and (FData.FBoard[x2, y2].FType = ptNil)
                and (SquareToStr(x2, y2) = FData.FEnPassant)
                then
                  FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, [miCapture]);
              
              if AColor = pcWhite then
                i := 7
              else
                i := 8;
              if TargetSquare(x1, y1, i, x2, y2)
              and (FData.FBoard[x2, y2].FType = ptNil) then
              begin
                FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, []);
                
                if (((AColor = pcWhite) and (y2 = 3)) or ((AColor = pcBlack) and (y2 = 6)))
                and TargetSquare(x2, y2, i, x2, y2)
                and (FData.FBoard[x2, y2].FType = ptNil) then
                  FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, []);
              end;
            end;
          ptKing:
            if AColor = pcWhite then
            begin
              if FData.FCastling[caWH] <> 0 then GenerateCastlingMove(caWH);
              if FData.FCastling[caWA] <> 0 then GenerateCastlingMove(caWA);
            end else
            begin
              if FData.FCastling[caBH] <> 0 then GenerateCastlingMove(caBH);
              if FData.FCastling[caBA] <> 0 then GenerateCastlingMove(caBA);
            end;
        end;
end;

procedure TChessPosition.GenerateMoves3(const AColor: TPieceColor);
var
  x1, y1, x2, y2: integer;
  i, i1, i2: integer;
begin
  for x1 := 1 to 8 do
    for y1 := 1 to 8 do
      if (FData.FBoard[x1, y1].FColor = AColor) then
        case FData.FBoard[x1, y1].FType of
          ptPawn:
            begin
              if AColor = pcWhite then
              begin
                i1 := 1;
                i2 := 2;
              end else
              begin
                i1 := 3;
                i2 := 4;
              end;
              for i := i1 to i2 do
                if TargetSquare(x1, y1, i, x2, y2)
                and (FData.FBoard[x2, y2].FColor = pcNil)
                then
                  FList.Append(x1, y1, x2, y2, FData.FBoard[x1, y1].FType, FData.FBoard[x1, y1].FColor, []);
            end;
        end;
end;

procedure TChessPosition.GenerateCastlingMove(const ACastling: TCastling);
const
  CMoveType: array[TCastling] of TMoveInfo = (miH_Castling, miA_Castling, miH_Castling, miA_Castling); 
var
  x, y, dx, xking, xrook, xkingdest, xrookdest: integer;
  c: TPieceColor;
  mis: TMoveInfoSet;
begin
  y := 0; dx := 0; xkingdest := 0; xrookdest := 0; c := pcWhite; mis := []; Include(mis, CMoveType[ACastling]);
  case ACastling of
    caWH: begin y := 1; dx := -1; xkingdest := 7; xrookdest := 6; c := pcWhite; end;
    caWA: begin y := 1; dx :=  1; xkingdest := 3; xrookdest := 4; c := pcWhite; end;
    caBH: begin y := 8; dx := -1; xkingdest := 7; xrookdest := 6; c := pcBlack; end;
    caBA: begin y := 8; dx :=  1; xkingdest := 3; xrookdest := 4; c := pcBlack; end;
  end;
  xrook := FData.FCastling[ACastling];
  xking := xrook;
  repeat
    xking := xking + dx;
  until (FData.FBoard[xking, y].FType = ptKing) and (FData.FBoard[xking, y].FColor = c);
  { Every square between the leftmost and the rightmost of the four squares must be empty, except those of the castling king and rook }
  for x := Min(Min(xking, xrook), Min(xkingdest, xrookdest)) to Max(Max(xking, xrook), Max(xkingdest, xrookdest)) do
    if (x <> xking) and (x <> xrook) and (FData.FBoard[x, y].FType <> ptNil) then
      Exit;

  if not FCastlingCheck[ACastling] then
    FList.Append(xking, y, xrook, y, FData.FBoard[xking, y].FType, FData.FBoard[xking, y].FColor, mis);
end;

function TChessPosition.IsCheck(const AColor: TPieceColor): boolean;
var
  i: integer;
  x2, y2: integer;
  m: TMove;
begin
  result := FALSE;
  for i := 0 to FList.Count - 1 do
  begin
    m := FList.GetMove(i);
    x2 := m.FX2;
    y2 := m.FY2;
    if (FData.FBoard[x2, y2].FType = ptKing)
    and (FData.FBoard[x2, y2].FColor = AColor) then
    begin
      result := TRUE;
      FKingCheckedX := x2;
      FKingCheckedY := y2;
    end;
  end;
end;

function TChessPosition.IsCastlingCheck(const ACastling: TCastling): boolean;
var
  x, y, dx, xdest: integer;
  c: TPieceColor;
 {x1, y1,}
  x2, y2: integer;
  i: integer;
  m: TMove;
begin
  y := 0; dx := 0; xdest := 0; c := pcWhite;
  case ACastling of
    caWH: begin y := 1; dx := -1; xdest := 7; c := pcWhite; end;
    caWA: begin y := 1; dx :=  1; xdest := 3; c := pcWhite; end;
    caBH: begin y := 8; dx := -1; xdest := 7; c := pcBlack; end;
    caBA: begin y := 8; dx :=  1; xdest := 3; c := pcBlack; end;
  end;
  x := FData.FCastling[ACastling];
  repeat
    x := x + dx;
  until (FData.FBoard[x, y].FType = ptKing) and (FData.FBoard[x, y].FColor = c);
  
  result := FALSE;
  i := 0;
  while (i < FList.Count) and not result do
  begin
    m := FList.GetMove(i);
   {x1 := m.FX1;
    y1 := m.FY1;}
    x2 := m.FX2;
    y2 := m.FY2;
    if (y2 = y)
    and (x2 >= Min(x, {FData.FCastling[ACastling]}xdest))
    and (x2 <= Max(x, {FData.FCastling[ACastling]}xdest)) then
      result := TRUE
    else
      Inc(i);
  end;
end;

procedure TChessPosition.SetVariables(const AShort: boolean);
begin
  GenerateMoves1(OtherColor(FData.FActive));
  FCheck := IsCheck(FData.FActive);
  if not FCheck then
  begin
    FKingCheckedX := 0;
    FKingCheckedY := 0;
  end;
  if AShort then
    Exit;
  GenerateMoves3(OtherColor(FData.FActive));
  if FData.FActive = pcWhite then
  begin
    FCastlingCheck[caWH] := (FData.FCastling[caWH] = 0) or FCheck or IsCastlingCheck(caWH);
    FCastlingCheck[caWA] := (FData.FCastling[caWA] = 0) or FCheck or IsCastlingCheck(caWA);
  end else
  begin
    FCastlingCheck[caBH] := (FData.FCastling[caBH] = 0) or FCheck or IsCastlingCheck(caBH);
    FCastlingCheck[caBA] := (FData.FCastling[caBA] = 0) or FCheck or IsCastlingCheck(caBA);
  end;
end;

procedure TChessPosition.DoMove(const AMove: {$IFDEF STRLIST}string{$ELSE}TMove{$ENDIF}; const APromo: TPieceType = ptQueen);
  procedure MovePiece(x1, y1, x2, y2: integer);
  begin
    Assert((x1 >= 1) and (x1 <= 8));
    Assert((y1 >= 1) and (y1 <= 8));
    Assert((x2 >= 1) and (x2 <= 8));
    Assert((y2 >= 1) and (y2 <= 8));
    FData.FBoard[x2, y2] := FData.FBoard[x1, y1];
    FData.FBoard[x1, y1].FType := ptNil;
    FData.FBoard[x1, y1].FColor := pcNil;
  end;
  procedure MoveTwoPieces(x1, y1, x2, y2, x3, y3, x4, y4: integer);
  var
    LRook, LKing: TChessPiece;
  begin
    Assert((x1 >= 1) and (x1 <= 8));
    Assert((y1 >= 1) and (y1 <= 8));
    Assert((x2 >= 1) and (x2 <= 8));
    Assert((y2 >= 1) and (y2 <= 8));
    Assert((x3 >= 1) and (x3 <= 8));
    Assert((y3 >= 1) and (y3 <= 8));
    Assert((x4 >= 1) and (x4 <= 8));
    Assert((y4 >= 1) and (y4 <= 8));
    LKing := FData.FBoard[x1, y1];
    LRook := FData.FBoard[x3, y3];
    FData.FBoard[x1, y1].FType := ptNil;
    FData.FBoard[x1, y1].FColor := pcNil;
    FData.FBoard[x3, y3].FType := ptNil;
    FData.FBoard[x3, y3].FColor := pcNil;
    FData.FBoard[x2, y2] := LKing;
    FData.FBoard[x4, y4] := LRook;
  end;
var
  x1, y1, x2, y2: integer;
begin
  (*
  WriteLn('TChessPosition.DoMove(', DebugMove(AMove), ')');
  *)
  {$IFDEF STRLIST}
  StrToMove(AMove, x1, y1, x2, y2);
  {$ELSE}
  x1 := AMove.FX1;
  y1 := AMove.FY1;
  x2 := AMove.FX2;
  y2 := AMove.FY2;
  {$ENDIF}
  
  if FData.FBoard[x1, y1].FType = ptNil then
    Exit;
  
  if FData.FBoard[x1, y1].FType = ptRook then
    if (y1 = 1) and (FData.FBoard[x1, y1].FColor = pcWhite) then
    begin
      if x1 = FData.FCastling[caWH] then FData.FCastling[caWH] := 0;
      if x1 = FData.FCastling[caWA] then FData.FCastling[caWA] := 0;
    end else
    if (y1 = 8) and (FData.FBoard[x1, y1].FColor = pcBlack) then
    begin
      if x1 = FData.FCastling[caBH] then FData.FCastling[caBH] := 0;
      if x1 = FData.FCastling[caBA] then FData.FCastling[caBA] := 0;
    end;
  
  if FData.FBoard[x2, y2].FType = ptRook then
    if (y2 = 1) and (FData.FBoard[x1, y1].FColor = pcBlack) then
    begin
      if x2 = FData.FCastling[caWH] then FData.FCastling[caWH] := 0;
      if x2 = FData.FCastling[caWA] then FData.FCastling[caWA] := 0;
    end else
    if (y2 = 8) and (FData.FBoard[x1, y1].FColor = pcWhite) then
    begin
      if x2 = FData.FCastling[caBH] then FData.FCastling[caBH] := 0;
      if x2 = FData.FCastling[caBA] then FData.FCastling[caBA] := 0;
    end;
  
  if (FData.FBoard[x1, y1].FType = ptPawn) and (Abs(y2 - y1) = 2) then
    FData.FEnPassant := SquareToStr(x1, y1 - 2 * Ord(FData.FActive) + 1)
  else
    FData.FEnPassant := '-';
  
  if (FData.FBoard[x1, y1].FType = ptKing)
  and (FData.FBoard[x1, y1].FColor <> FData.FBoard[x2, y2].FColor) then
    if FData.FBoard[x1, y1].FColor = pcWhite then
    begin
      FData.FCastling[caWH] := 0;
      FData.FCastling[caWA] := 0;
    end else
    begin
      FData.FCastling[caBH] := 0;
      FData.FCastling[caBA] := 0;
    end;
  
  if (FData.FBoard[x1, y1].FType = ptPawn) and (x2 <> x1) and (FData.FBoard[x2, y2].FType = ptNil) then
  begin
    FData.FBoard[x2, y1].FColor := pcNil;
    FData.FBoard[x2, y1].FType := ptNil;
  end;
  
  if (FData.FBoard[x1, y1].FType = ptPawn)
  or (FData.FBoard[x2, y2].FType <> ptNil)
  and not (FData.FBoard[x1, y1].FColor = FData.FBoard[x2, y2].FColor) then
    FData.FHalfMoves := 0
  else
    Inc(FData.FHalfMoves);
  
  if FData.FActive = pcBlack then
    Inc(FData.FFullMove);
  
  if (FData.FBoard[x1, y1].FType = ptPawn) and ((y2 = 1) or (y2 = 8)) then
    FData.FBoard[x1, y1].FType := APromo;
  
  if  (FData.FBoard[x1, y1].FType = ptKing)
  and (FData.FBoard[x2, y2].FType = ptRook)
  and (FData.FBoard[x1, y1].FColor = FData.FBoard[x2, y2].FColor) then
    if (FData.FBoard[x1, y1].FColor = pcWhite) then
    begin
      if x2 > x1
      then MoveTwoPieces(x1, y1, 7, y2, FData.FCastling[caWH], 1, 6, 1)
      else MoveTwoPieces(x1, y1, 3, y2, FData.FCastling[caWA], 1, 4, 1);
      FData.FCastling[caWH] := 0;
      FData.FCastling[caWA] := 0;
    end else
    begin
      if x2 > x1
      then MoveTwoPieces(x1, y1, 7, y2, FData.FCastling[caBH], 8, 6, 8)
      else MoveTwoPieces(x1, y1, 3, y2, FData.FCastling[caBA], 8, 4, 8);
      FData.FCastling[caBH] := 0;
      FData.FCastling[caBA] := 0;
    end
  else
    MovePiece(x1, y1, x2, y2);
  
  FData.FActive := OtherColor(FData.FActive);
end;

procedure TChessPosition.SetActiveColor(const AColor: TPieceColor);
begin
  FData.FActive := AColor;
end;

function TChessPosition.ToStr(): string;
begin
  result := DataToStr(FData);
end;

end.
