
{**
  @abstract(Programme principal du moteur d'échecs.)
  Interface du moteur d'échecs.
}

program Alouette;

uses
{$IFDEF UNIX}
  CThreads,
{$ENDIF}
  SysUtils, Uci;

begin
  RunUci(
    ChangeFileExt(ParamStr(0), '.cfg'),
    ExtractFilePath(ParamStr(0)),
    (ParamCount = 1) and ((ParamStr(1) = '-r') or (ParamStr(1) = '--random'))
  );
end.
