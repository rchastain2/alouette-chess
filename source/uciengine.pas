unit UciEngine;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF} SysUtils, Classes, ctypes, SDL3, PixelLog;

type
  TUciEngine = class
  private
    FProcess: PSDL_Process;
    FThread: TThread;
    FInput, FOutput: PSDL_IOStream;
    FBuffer: string;
    FThinking: boolean;
    FPendingReady: integer;
    FName: string;
    FExited: boolean;
    procedure Send(const ALine: string);
    procedure Sync;
    function ReadLine(out ALine: string): boolean;
    function ReadProcessLine(out ALine: string): boolean;
  public
    constructor Create(const AExecutable, AWorkingDir: string);
    constructor CreateBuiltin(const AConfigFile, ABookDir: string);
    destructor Destroy; override;
    procedure SetOption(const AName, AValue: string);
    procedure NewGame;
    procedure Go(const AFen: string; const AMoves: TStrings; const AMoveTime: integer);
    procedure Stop;
    function Poll(out AMove: string): boolean;
    function Running: boolean;
    property Thinking: boolean read FThinking;
    property Name: string read FName;
  end;

implementation

uses
  Uci;

type
  TBuiltinThread = class(TThread)
  private
    FConfigFile, FBookDir: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AConfigFile, ABookDir: string);
  end;

var
  LLock: TRTLCriticalSection;
  LInputEvent: PRTLEvent;
  LInputLines, LOutputLines: TStringList;

function BuiltinReadLine(out ALine: string): boolean;
begin
  result := TRUE;
  repeat
    EnterCriticalSection(LLock);
    try
      if LInputLines.Count > 0 then
      begin
        ALine := LInputLines[0];
        LInputLines.Delete(0);
        exit;
      end;
    finally
      LeaveCriticalSection(LLock);
    end;
    RTLEventWaitFor(LInputEvent, 100);
  until FALSE;
end;

procedure BuiltinWriteLine(const ALine: string);
var
  LLine: string;
begin
  EnterCriticalSection(LLock);
  try
    for LLine in ALine.Split([#13#10, #10]) do
      LOutputLines.Add(LLine);
  finally
    LeaveCriticalSection(LLock);
  end;
end;

procedure PushInputLine(const ALine: string);
begin
  EnterCriticalSection(LLock);
  try
    LInputLines.Add(ALine);
  finally
    LeaveCriticalSection(LLock);
  end;
  RTLEventSetEvent(LInputEvent);
end;

function PopOutputLine(out ALine: string): boolean;
begin
  EnterCriticalSection(LLock);
  try
    result := LOutputLines.Count > 0;
    if result then
    begin
      ALine := LOutputLines[0];
      LOutputLines.Delete(0);
    end;
  finally
    LeaveCriticalSection(LLock);
  end;
end;

constructor TBuiltinThread.Create(const AConfigFile, ABookDir: string);
begin
  inherited Create(TRUE);
  FConfigFile := AConfigFile;
  FBookDir := ABookDir;
end;

procedure TBuiltinThread.Execute;
begin
  RunUci(FConfigFile, FBookDir, FALSE, @BuiltinReadLine, @BuiltinWriteLine);
end;

constructor TUciEngine.Create(const AExecutable, AWorkingDir: string);
var
  LArgs: array[0..1] of PAnsiChar;
  LProps: TSDL_PropertiesID;
begin
  inherited Create;
{$IFDEF UNIX}
  fpSignal(SIGPIPE, SignalHandler(SIG_IGN));
{$ENDIF}
  LArgs[0] := PAnsiChar(AExecutable);
  LArgs[1] := nil;
  LProps := SDL_CreateProperties;
  SDL_SetPointerProperty(LProps, SDL_PROP_PROCESS_CREATE_ARGS_POINTER, @LArgs[0]);
  SDL_SetStringProperty(LProps, SDL_PROP_PROCESS_CREATE_WORKING_DIRECTORY_STRING, PAnsiChar(AWorkingDir));
  SDL_SetNumberProperty(LProps, SDL_PROP_PROCESS_CREATE_STDIN_NUMBER, SDL_PROCESS_STDIO_APP);
  SDL_SetNumberProperty(LProps, SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER, SDL_PROCESS_STDIO_APP);
  SDL_SetNumberProperty(LProps, SDL_PROP_PROCESS_CREATE_STDERR_NUMBER, SDL_PROCESS_STDIO_NULL);
  FProcess := SDL_CreateProcessWithProperties(LProps);
  SDL_DestroyProperties(LProps);
  if FProcess = nil then
    raise Exception.CreateFmt('Cannot start %s: %s', [AExecutable, SDL_GetError]);
  FInput := SDL_GetProcessInput(FProcess);
  FOutput := SDL_GetProcessOutput(FProcess);
  Send('uci');
end;

constructor TUciEngine.CreateBuiltin(const AConfigFile, ABookDir: string);
begin
  inherited Create;
  EnterCriticalSection(LLock);
  try
    LInputLines.Clear;
    LOutputLines.Clear;
  finally
    LeaveCriticalSection(LLock);
  end;
  FThread := TBuiltinThread.Create(AConfigFile, ABookDir);
  FThread.Start;
  Send('uci');
end;

destructor TUciEngine.Destroy;
var
  i: integer;
begin
  if FThread <> nil then
  begin
    if not FThread.Finished then
      Send('quit');
    while not FThread.Finished do
      SDL_Delay(1);
    FThread.WaitFor;
    FThread.Free;
  end;
  if (FProcess <> nil) and Running then
  begin
    Send('quit');
    i := 0;
    while not SDL_WaitProcess(FProcess, FALSE, nil) and (i < 50) do
    begin
      SDL_Delay(10);
      Inc(i);
    end;
    if i = 50 then
    begin
      SDL_KillProcess(FProcess, TRUE);
      SDL_WaitProcess(FProcess, TRUE, nil);
    end;
  end;
  if FProcess <> nil then
    SDL_DestroyProcess(FProcess);
  inherited Destroy;
end;

procedure TUciEngine.Send(const ALine: string);
var
  LLine: string;
begin
  if LogUci then
    WriteLog('> ' + ALine);
  if FThread <> nil then
  begin
    PushInputLine(ALine);
    exit;
  end;
  LLine := ALine + #10;
  SDL_WriteIO(FInput, PAnsiChar(LLine), Length(LLine));
  SDL_FlushIO(FInput);
end;

procedure TUciEngine.Sync;
begin
  Send('isready');
  Inc(FPendingReady);
end;

function TUciEngine.ReadLine(out ALine: string): boolean;
begin
  if FThread <> nil then
    result := PopOutputLine(ALine)
  else
    result := ReadProcessLine(ALine);
  if result and LogUci then
    WriteLog('< ' + ALine);
end;

function TUciEngine.ReadProcessLine(out ALine: string): boolean;
var
  LChunk: array[0..4095] of char;
  LCount: csize_t;
  LPos: integer;
  LText: string;
begin
  repeat
    LCount := SDL_ReadIO(FOutput, @LChunk, SizeOf(LChunk));
    if LCount > 0 then
    begin
      SetString(LText, PAnsiChar(@LChunk), LCount);
      FBuffer := FBuffer + LText;
    end;
  until LCount = 0;
  LPos := Pos(#10, FBuffer);
  result := LPos > 0;
  if not result then
    exit;
  ALine := TrimRight(Copy(FBuffer, 1, LPos - 1));
  Delete(FBuffer, 1, LPos);
end;

procedure TUciEngine.SetOption(const AName, AValue: string);
begin
  Send(Format('setoption name %s value %s', [AName, AValue]));
end;

procedure TUciEngine.NewGame;
begin
  Stop;
  Send('ucinewgame');
  Sync;
end;

procedure TUciEngine.Go(const AFen: string; const AMoves: TStrings; const AMoveTime: integer);
var
  LLine: string;
  i: integer;
begin
  if AFen = '' then
    LLine := 'position startpos'
  else
    LLine := 'position fen ' + AFen;
  if AMoves.Count > 0 then
  begin
    LLine := LLine + ' moves';
    for i := 0 to AMoves.Count - 1 do
      LLine := LLine + ' ' + AMoves[i];
  end;
  Send(LLine);
  Send(Format('go movetime %d', [AMoveTime]));
  FThinking := TRUE;
end;

procedure TUciEngine.Stop;
begin
  if not FThinking then
    exit;
  Send('stop');
  Sync;
  FThinking := FALSE;
end;

function TUciEngine.Poll(out AMove: string): boolean;
var
  LLine: string;
  LWords: TStringArray;
begin
  result := FALSE;
  while ReadLine(LLine) do
  begin
    if Copy(LLine, 1, 8) = 'id name ' then
      FName := Trim(Copy(LLine, 9, MaxInt));
    if (LLine = 'readyok') and (FPendingReady > 0) then
      Dec(FPendingReady);
    if Copy(LLine, 1, 9) <> 'bestmove ' then
      continue;
    if FPendingReady > 0 then
      continue;
    LWords := LLine.Split(' ');
    AMove := LWords[1];
    FThinking := FALSE;
    exit(TRUE);
  end;
end;

function TUciEngine.Running: boolean;
begin
  if FThread <> nil then
    exit(not FThread.Finished);
  if not FExited then
    FExited := SDL_WaitProcess(FProcess, FALSE, nil);
  result := not FExited;
end;

initialization
  InitCriticalSection(LLock);
  LInputEvent := RTLEventCreate;
  LInputLines := TStringList.Create;
  LOutputLines := TStringList.Create;

finalization
  LOutputLines.Free;
  LInputLines.Free;
  RTLEventDestroy(LInputEvent);
  DoneCriticalSection(LLock);

end.
