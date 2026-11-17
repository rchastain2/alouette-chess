unit UciEngine;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF} SysUtils, Classes, ctypes, SDL3, PixelLog;

type
  TUciEngine = class
  private
    FProcess: PSDL_Process;
    FInput, FOutput: PSDL_IOStream;
    FBuffer: string;
    FThinking: boolean;
    FPendingReady: integer;
    FName: string;
    FExited: boolean;
    procedure Send(const ALine: string);
    procedure Sync;
    function ReadLine(out ALine: string): boolean;
  public
    constructor Create(const AExecutable, AWorkingDir: string);
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

destructor TUciEngine.Destroy;
var
  i: integer;
begin
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
  if LogUci then
    WriteLog('< ' + ALine);
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
  if not FExited then
    FExited := SDL_WaitProcess(FProcess, FALSE, nil);
  result := not FExited;
end;

end.
