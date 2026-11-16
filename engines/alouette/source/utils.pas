
{**
  @abstract(Fonctions pour l'analyse des commandes.)
  Fonctions pour l'analyse des commandes.
}

unit Utils;

interface

function BeginsWith(const ASubStr, AStr: string): boolean;
function WordsNumber(const AStr: string): integer;
function WordPresent(const AWord, AStr: string): boolean;
function GetWord(const AIndex: integer; const AStr: string): string;
function GetFen(const AStr: string): string;
function FixFen(const AStr: string; out AOld: string): string;
function IsChessMove(const AStr: string): boolean;
function GetGoParam(const AName, AStr: string; out AValue: integer): boolean;
function IsPerftCmd(const AStr: string; out ADepth: integer): boolean;
function IsUsualStartPos(const AStr: string): boolean;

implementation

uses
  SysUtils, StrUtils, Chess;

function BeginsWith(const ASubStr, AStr: string): boolean;
begin
  result := Pos(ASubStr, AStr) = 1;
end;

function WordsNumber(const AStr: string): integer;
begin
  result := WordCount(AStr, [' ']);
end;

function WordPresent(const AWord, AStr: string): boolean;
begin
  result := IsWordPresent(AWord, AStr, [' ']);
end;

function GetWord(const AIndex: integer; const AStr: string): string;
begin
  result := ExtractWord(AIndex, AStr, [' ']);
end;

function GetFen(const AStr: string): string;
// position fen qbbnnrkr/pppppppp/8/8/8/8/PPPPPPPP/QBBNNRKR w HFhf - 0 1 moves e2e4
begin
  result := Format('%s %s %s %s %s %s', [
    GetWord(3, AStr),
    GetWord(4, AStr),
    GetWord(5, AStr),
    GetWord(6, AStr),
    GetWord(7, AStr),
    GetWord(8, AStr)
  ]);
end;

function FixFen(const AStr: string; out AOld: string): string;
// qbbnnrkr/pppppppp/8/8/8/8/PPPPPPPP/QBBNNRKR w HFhf - 0 1
begin
  result := Format('%s %s %s %s %s %s', [
    GetWord(1, AStr),
    GetWord(2, AStr),
    'KQkq',
    GetWord(4, AStr),
    GetWord(5, AStr),
    GetWord(6, AStr)
  ]);
  AOld := GetWord(3, AStr);
end;

function IsChessMove(const AStr: string): boolean;
begin
  result := (Length(AStr) >= 4)
    and (AStr[1] in ['a'..'h'])
    and (AStr[2] in ['1'..'8'])
    and (AStr[3] in ['a'..'h'])
    and (AStr[4] in ['1'..'8']);
end;

function GetGoParam(const AName, AStr: string; out AValue: integer): boolean;
var
  i: integer;
begin
  AValue := 0;
  result := FALSE;
  for i := 2 to Pred(WordsNumber(AStr)) do
    if GetWord(i, AStr) = AName then
      Exit(TryStrToInt(GetWord(Succ(i), AStr), AValue));
end;

function IsPerftCmd(const AStr: string; out ADepth: integer): boolean;
var
  i: integer;
begin
  ADepth := 0;
  result := WordPresent('perft', AStr) and TryStrToInt(GetWord(2, AStr), i);
  if result then
    ADepth := i;
end;

function IsUsualStartPos(const AStr: string): boolean;
begin
  result :=
    (GetWord(1, AStr) = GetWord(1, CStartPos)) and
    (GetWord(2, AStr) = GetWord(2, CStartPos));
end;

end.
