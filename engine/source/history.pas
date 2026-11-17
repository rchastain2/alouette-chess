
unit History;

interface

uses
  Chess;

procedure ClearHistory;
procedure AppendToHistory(const APos: TPosition);
function FindInHistory(const APos: TPosition): boolean;

implementation

uses
  Classes;
  
var
  LList: TStringList;

procedure ClearHistory;
begin
  LList.Clear;
end;

procedure AppendToHistory(const APos: TPosition);
begin
  LList.Add(DecodePosition(APos));
end;

function FindInHistory(const APos: TPosition): boolean;
begin
  result := LList.IndexOf(DecodePosition(APos)) > -1;
end;

initialization
  LList := TStringList.Create;
  LList.Sorted := FALSE;

finalization
  LList.Free;

end.
