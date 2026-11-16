unit PixelLog;

{$mode objfpc}{$H+}

interface

var
  LogUci: boolean = FALSE;

procedure OpenLog(const APath: string);
procedure WriteLog(const AText: string);
procedure CloseLog;

implementation

uses
  SysUtils;

var
  LFile: TextFile;
  LOpen: boolean = FALSE;

procedure OpenLog(const APath: string);
begin
  AssignFile(LFile, APath);
  {$I-}
  Rewrite(LFile);
  {$I+}
  LOpen := IOResult = 0;
end;

procedure WriteLog(const AText: string);
begin
  if not LOpen then
    exit;
  WriteLn(LFile, FormatDateTime('hh:nn:ss.zzz', Now), ' ', AText);
  Flush(LFile);
end;

procedure CloseLog;
begin
  if not LOpen then
    exit;
  CloseFile(LFile);
  LOpen := FALSE;
end;

finalization
  CloseLog;
end.
