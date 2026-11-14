
{**
@abstract(Types utilisés pour la représentation du jeu.)
}
unit ChessTypes;

interface

type
  {** Type de la pièce, y compris la valeur "néant". }
  TPieceTypeWide = (ptPawn, ptKnight, ptBishop, ptRook, ptQueen, ptKing, ptNil);
  {** Type de la pièce. }
  TPieceType = ptPawn..ptKing;
  {** Couleur de la pièce, y compris la valeur "néant". }
  TPieceColorWide = (pcWhite, pcBlack, pcNil);
  {** Couleur de la pièce. }
  TPieceColor = pcWhite..pcBlack;
  {** Type et couleur d'une pièce. }
  TChessPiece = record
    FType: TPieceTypeWide;
    FColor: TPieceColorWide;
  end;
  {** Tableau de pièces. }
  TBoard = array[1..8, 1..8] of TChessPiece;
  {** Type de roque (blanc, noir, côté H, côté A). }
  TCastling = (caWH, caWA, caBH, caBA);
  {** Autorisation de roquer. Valeurs possible : 0 (roque interdit), 1 à 8 (roque autorisé). Les valeurs différentes de zéro indiquent la colonne sur laquelle se trouve la tour. }
  TCastlingRights = array[TCastling] of integer;
  {** Représentation de la position. }
  PPositionData = ^TPositionData;
  TPositionData = record
    FBoard: TBoard;
    FActive: TPieceColor;
    FCastling: TCastlingRights;
    FEnPassant: string;
    FHalfMoves: integer;
    FFullMove: integer;
  end;
  {** État du jeu. }
  TGameState = (gsProgress, gsCheckmate, gsStalemate, gsDraw);
  {** Type de coup. }
  TMoveInfo = (miCapture, miH_Castling, miA_Castling, miKnight, miBishop, miRook, miQueen);
  TMoveInfoSet = set of TMoveInfo;
  {** Coup. }
  PMove = ^TMove;
  TMove = record
    FX1, FY1, FX2, FY2: integer;
    FType: TPieceTypeWide;
    FColor: TPieceColorWide;
    FInfo: TMoveInfoSet;
  end;

const
  CPieceSymbol: array[TPieceColor, TPieceType] of char = (
    ('P', 'N', 'B', 'R', 'Q', 'K'),
    ('p', 'n', 'b', 'r', 'q', 'k')
  );
  CColorSymbol: array[TPieceColor] of char = ('w', 'b');
  CNoMove: TMove = (FX1: 0; FY1: 0; FX2: 0; FY2: 0; FType: ptNil; FColor: pcNil; FInfo: []);

function OtherColor(const AColor: TPieceColorWide): TPieceColorWide;
function ValidPromotionValue(const AValue: TPieceTypeWide): TPieceType;
function DataToStr(const AData: TPositionData): string;

implementation

uses
  SysUtils;
  
function OtherColor(const AColor: TPieceColorWide): TPieceColorWide;
begin
  if AColor = pcNil then
    result := pcNil
  else
    result := TPieceColor(1 - Ord(AColor));
end;

function ValidPromotionValue(const AValue: TPieceTypeWide): TPieceType;
begin
  if AValue in [ptKnight, ptBishop, ptRook, ptQueen] then
    result := TPieceType(AValue)
  else
    result := ptQueen;
end;

function DataToStr(const AData: TPositionData): string;
var
  x, y: integer;
begin
  result :=  '+   a b c d e f g h   +' + LineEnding + LineEnding;
  for y := 8 downto 1 do
  begin
    result := result + Chr(y + Ord('0')) + '   ';
    for x := 1 to 8 do
    begin
      if AData.FBoard[x, y].FColor = pcNil then
        if (x + y) mod 2 = 1 then
          result := result + '. '
        else
          result := result + ': '
      else
        result := result + CPieceSymbol[AData.FBoard[x, y].FColor, AData.FBoard[x, y].FType] + ' ';
    end;
    result := result + '  ' + Chr(y + Ord('0')) + LineEnding;
  end;
  result := result + LineEnding + '+   a b c d e f g h   +' + LineEnding + LineEnding;
  with AData do
    result := result + Format(
      '  * Active color: %s' + LineEnding +
      '  * Castling rights: %d %d %d %d' + LineEnding +
      '  * En passant: %s' + LineEnding +
      '  * Halfmoves clock: %d' + LineEnding +
      '  * Fullmove number: %d' + LineEnding,
      [
        CColorSymbol[FActive],
        FCastling[caWH],
        FCastling[caWA],
        FCastling[caBH],
        FCastling[caBA],
        FEnPassant,
        FHalfMoves,
        FFullMove
      ]
    );
end;

end.
