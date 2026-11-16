
unit Journal;

interface

uses
  SysUtils, Board;
  
type
  TLog = class
  private
    FFile: TextFile;
    FTimePrefix: boolean;
  public
    constructor Create(const AUnitName: string; const ARewrite: boolean = FALSE; const ATimePrefix: boolean = FALSE);
    destructor Destroy; override;
    procedure LogLn(const AText: string; const AFlush: boolean = FALSE); overload;
    procedure LogLn(const AMoves: array of TMove; const ACount: integer; const AFlush: boolean = FALSE); overload;
    procedure LogLn(const AMoves: array of TMove; const AValues: array of integer; const ACount: integer; const AFlush: boolean = FALSE); overload;
    procedure UpdateFile;
  end;

implementation

constructor TLog.Create(const AUnitName: string; const ARewrite: boolean; const ATimePrefix: boolean);
var
  LFileName: TFileName;
begin
  LFileName := Concat(
    ExtractFilePath(ParamStr(0)),
    ChangeFileExt(ExtractFileName(AUnitName), '.log')
  );
  Assign(FFile, LFileName);
  if ARewrite or not FileExists(LFileName) then
    Rewrite(FFile)
  else
    Append(FFile);
  FTimePrefix := ATimePrefix;
end;

destructor TLog.Destroy;
begin
  Close(FFile);
  inherited;
end;

procedure TLog.LogLn(const AText: string; const AFlush: boolean);
var
  LTimeStr: string;
begin
  if FTimePrefix then
  begin
    LTimeStr := DateTimeToStr(Now);
    WriteLn(FFile, LTimeStr, ' ', AText);
  end else
    WriteLn(FFile, AText);
  if AFlush then
    Flush(FFile);
end;

procedure TLog.LogLn(const AMoves: array of TMove; const ACount: integer; const AFlush: boolean);
var
  i: integer;
begin
  for i := 0 to Pred(ACount) do
    Write(FFile, Format('%6s', [MoveToStr(AMoves[i])]));
  WriteLn(FFile);
  if AFlush then
    Flush(FFile);
end;

procedure TLog.LogLn(const AMoves: array of TMove; const AValues: array of integer; const ACount: integer; const AFlush: boolean);
var
  i: integer;
begin
  for i := 0 to Pred(ACount) do
    Write(FFile, Format('%6s', [MoveToStr(AMoves[i])]));
  WriteLn(FFile);
  for i := 0 to Pred(ACount) do
    Write(FFile, Format('%6d', [AValues[i]]));
  WriteLn(FFile);
  if AFlush then
    Flush(FFile);
end;

procedure TLog.UpdateFile;
begin
  Flush(FFile);
end;

end.
