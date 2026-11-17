
{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

var
  SL: TStringList;
  i: integer;
  
begin
  SL := TStringList.Create;
  try
    SL.Sorted := TRUE;
    SL.LoadFromFile(ParamStr(1));
    
    for i := Pred(SL.Count) downto 0 do
      if not (Length(SL[i]) in [74, 79]) then
      begin
        WriteLn('DELETE "', SL[i], '"');
        SL.Delete(i);
      end;
    SL.SaveToFile(ParamStr(1));
  finally
    SL.Free;
  end;
end.
