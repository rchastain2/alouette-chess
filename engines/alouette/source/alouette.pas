
{**
  @abstract(Programme principal du moteur d'échecs.)
  Interface du moteur d'échecs.
}

program Alouette;

uses
{$IFDEF UNIX}
  CThreads,
{$ENDIF}
  Classes, SysUtils, Math,
  Chess, Move, Best, Utils, Perft, Trees, Settings, History{$IFDEF LOG_MAIN}, Journal{$ENDIF};

const
  CAppName    = 'Alouette';
  CAppVersion = '0.2.0';
  CAppAuthor  = 'Roland Chastain';
  CBuild      = 'FPC ' + {$I %FPCVERSION%} + ' ' + {$I %DATE%} + ' ' + {$I %TIME%} + ' ' + {$I %FPCTARGETOS%} + '-' + {$I %FPCTARGETCPU%};

var
  LLock: TRTLCriticalSection;
{$IFDEF LOG_MAIN}
  LLog: TLog;

procedure LogLine(const AText: string);
begin
  EnterCriticalSection(LLock);
  try
    LLog.LogLn(AText);
  finally
    LeaveCriticalSection(LLock);
  end;
end;
{$ENDIF}

procedure Send(const AMessage: string; const AFlush: boolean = TRUE);
{$IFDEF LOG_MAIN}
var
  LList: TStringList;
  i: integer;
{$ENDIF}
begin
  EnterCriticalSection(LLock);
  try
{$IFDEF LOG_MAIN}
    if Pos(LineEnding, AMessage) = 0 then
      LLog.LogLn(Concat('<- ', AMessage))
    else
    begin
      LList := TStringList.Create;
      LList.Text := AMessage;
      for i := 0 to Pred(LList.Count) do
        LLog.LogLn(Concat('<- ', LList[i]));
      LList.Free;
    end;
{$ENDIF}
    WriteLn(output, AMessage);
    if AFlush then
      Flush(output);
  finally
    LeaveCriticalSection(LLock);
  end;
end;

procedure SendInfo(const AText: string);
begin
  Send(AText);
end;

type
  {** Fil d'exécution pour la recherche du meilleur coup. }
  TSearchThread = class(TThread)
    private
      FPos: TPosition;
      FFrc: boolean;
      FTime: cardinal;
      FRandom: boolean;
      FDepth: integer;
      FInfinite: boolean;
    protected
      procedure Execute; override;
    public
      constructor Create(const APos: TPosition; const AFrc: boolean; const ATime: cardinal; const ARandom: boolean; const ADepth: integer; const AInfinite: boolean);
  end;

var
  LPos: TPosition;
  LFrc: boolean;
  LMoveStr: string;
  LTimeAv: cardinal;
  LRandMove: boolean;
  
constructor TSearchThread.Create(const APos: TPosition; const AFrc: boolean; const ATime: cardinal; const ARandom: boolean; const ADepth: integer; const AInfinite: boolean);
begin
  inherited Create(TRUE);
  FPos := APos;
  FFrc := AFrc;
  FTime := ATime;
  FRandom := ARandom;
  FDepth := ADepth;
  FInfinite := AInfinite;
end;

procedure TSearchThread.Execute;
var
  LTime: TTime;
  LMove: string;
begin
  LTime := Now;
  LMove := '';
  LMove := GetBestMove(FPos, FFrc, FTime, LMove, FRandom, FDepth);
  while FInfinite and not LStop do
    Sleep(10);
  LTime := Now - LTime;
{$IFDEF LOG_MAIN}
  LogLine('** Time used ' + TimeToStr(LTime));
{$ENDIF}
  Send(Format('bestmove %s', [LMove]));
end;

const
  CBoolStr: array[boolean] of string = ('false', 'true');
  CTimeMargin = 50;
  CTimeName: array[boolean] of string = ('wtime', 'btime');
  CIncName: array[boolean] of string = ('winc', 'binc');

var
  LCmd: string;
  LIdx: integer;
  LMTime, LSideTime, LSideInc, LMTG, LGoDepth: integer;
  LInfinite: boolean;
  LThread: TSearchThread;
  LDepth: integer;
  LFen: string;
  LBookLine, LBookMove: string;
  LBook: array[boolean] of TTreeList;
  LBookName: array[boolean] of TFileName;
  LColor: boolean;
  LUseBook, LReadBook: boolean;

procedure EndSearch;
begin
  if Assigned(LThread) then
  begin
    LStop := TRUE;
    LThread.WaitFor;
    FreeAndNil(LThread);
  end;
end;

procedure NewGame;
begin
  EndSearch;
  ClearHistory;
  LPos := EncodePosition;
  AppendToHistory(LPos);
  LBookLine := '';
  LReadBook := LUseBook and not LRandMove;
end;

begin
  Randomize;
  LThread := nil;
  InitCriticalSection(LLock);
  LInfoProc := @SendInfo;
  LoadSettings(LUseBook, LFactorPawnMove, LFactorPawnStruct, LFactorTargets, LFactorCastling, LFactorEnPassant, LFactorCheck, LFactorProtect, LFactorAttack, LFactorPawnMobil, LFactorNewPos);
{$IFDEF LOG_MAIN}
  LLog := TLog.Create(ParamStr(0), FALSE, TRUE);
  LogLine(CAppName + ' ' + CAppVersion + ' ' + CBuild);
{$ENDIF}
  LFrc := FALSE;
  LRandMove := (ParamCount = 1) and ((ParamStr(1) = '-r') or (ParamStr(1) = '--random'));
  LBookName[FALSE] := Concat(ExtractFilePath(ParamStr(0)), 'white.txt');
  LBookName[TRUE]  := Concat(ExtractFilePath(ParamStr(0)), 'black.txt');
  for LColor := FALSE to TRUE do
  begin
    LBook[LColor] := TTreeList.Create;
    if FileExists(LBookName[LColor]) then
      LBook[LColor].LoadFromFileCompact(LBookName[LColor])
{$IFDEF LOG_MAIN}
    else
      LogLine(Format('** File not found: %s', [LBookName[LColor]]))
{$ENDIF};
  end;
  NewGame;
  
  while not Eof do
  begin
    ReadLn(input, LCmd);
{$IFDEF LOG_MAIN}
    LogLine(Concat('-> ', LCmd));
{$ENDIF}
    if LCmd = 'quit' then
      Break
    else
      if LCmd = 'uci' then
      begin
        Send(Format('id name %s %s', [CAppName, CAppVersion]), FALSE);
        Send(Format('id author %s', [CAppAuthor]), FALSE);
        Send(Format('option name UCI_Chess960 type check default %s', [CBoolStr[LFrc]]), FALSE);
        Send('uciok');
      end else
        if LCmd = 'isready' then
        begin
          Send('readyok');
        end else
          if LCmd = 'ucinewgame' then
            NewGame
          else
            if BeginsWith('position ', LCmd) then
            begin
              EndSearch;
              if not WordPresent('startpos', LCmd) and WordPresent('fen', LCmd) and not IsValidFen(GetFen(LCmd)) then
              begin
{$IFDEF LOG_MAIN}
                LogLine(Format('** Invalid FEN: %s', [LCmd]));
{$ENDIF}
                Continue;
              end;
              ClearHistory;
              if WordPresent('startpos', LCmd) then
              begin
                LPos := EncodePosition;
                AppendToHistory(LPos);
                LReadBook := LUseBook and not LRandMove;
              end else
                if WordPresent('fen', LCmd) then
                begin
                  LFen := GetFen(LCmd);
                  LPos := EncodePosition(LFen, LFrc);
                  AppendToHistory(LPos);
                  LReadBook := LUseBook and IsUsualStartPos(LFen) and not LRandMove;  
                end
{$IFDEF LOG_MAIN}
                else
                  LogLine(Format('** Unknown command: %s', [LCmd]))
{$ENDIF};
              
              LBookLine := '';
              if WordPresent('moves', LCmd) then
                for LIdx := 4 to WordsNumber(LCmd) do
                begin
                  LMoveStr := GetWord(LIdx, LCmd);
                  if IsChessMove(LMoveStr) then
                  begin
                    if not Move.DoMove(LPos, LMoveStr) then
                    begin
{$IFDEF LOG_MAIN}
                      LogLine(Format('** Impossible move: %s', [LMoveStr]));
{$ENDIF}
                      Break;
                    end;
                    AppendToHistory(LPos);
                    LBookLine := Concat(LBookLine, ' ', LMoveStr);
                  end;
                end;
            end else
              if BeginsWith('go', LCmd) then
              begin
                EndSearch;
                LInfinite := WordPresent('infinite', LCmd);
                if not GetGoParam('depth', LCmd, LGoDepth) then
                  LGoDepth := 0;
                if LInfinite then
                  LTimeAv := High(integer)
                else
                  if GetGoParam('movetime', LCmd, LMTime) then
                    LTimeAv := Max(1, LMTime - CTimeMargin)
                  else
                    if GetGoParam(CTimeName[LPos.Side], LCmd, LSideTime) then
                    begin
                      if not GetGoParam(CIncName[LPos.Side], LCmd, LSideInc) then
                        LSideInc := 0;
                      if not (GetGoParam('movestogo', LCmd, LMTG) and (LMTG > 0)) then
                        LMTG := 49;
                      LTimeAv := Max(1, Min(LSideTime - CTimeMargin, (LSideTime - CTimeMargin) div (LMTG + 1) + LSideInc));
                    end else
                      if LGoDepth > 0 then
                        LTimeAv := High(integer)
                      else
                      begin
                        LTimeAv := 1000;
{$IFDEF LOG_MAIN}
                        LogLine(Format('** Unknown command: %s', [LCmd]));
{$ENDIF}
                      end;

                if LReadBook and not LInfinite then
                begin
                  LBookMove := LBook[LPos.Side].FindMoveToPlay(Trim(LBookLine), TRUE);
                  if LBookMove <> EmptyStr then
                  begin
{$IFDEF LOG_MAIN}
                    LogLine(Format('** Book %s', [LBookMove]));
{$ENDIF}
                    Send('info string book move');
                    Send(Format('bestmove %s', [LBookMove]));
                    Continue;
                  end;
                end;

                LStop := FALSE;
                LThread := TSearchThread.Create(LPos, LFrc, LTimeAv, LRandMove, LGoDepth, LInfinite);
                LThread.Start;
              end else
                if LCmd = 'stop' then
                  LStop := TRUE
                else
                  if BeginsWith('setoption name UCI_Chess960 value ', LCmd) then
                    LFrc := WordPresent('true', LCmd)
                  else
                    if LCmd = 'board' then
                      Send(PosToText(LPos))
                    else
                      if LCmd = 'moves' then
                        DisplayLegalMoves(LPos)
                      else
                        if IsPerftCmd(LCmd, LDepth) then
                          Start(LPos, LDepth)
                        else
                          if LCmd = 'help' then
                            Send(
                              'UCI commands:' + LineEnding +
                              '  go depth <x>' + LineEnding +
                              '  go infinite' + LineEnding +
                              '  go movetime <x>' + LineEnding +
                              '  go wtime <x> btime <x> [winc <x> binc <x>] [movestogo <x>]' + LineEnding +
                              '  isready' + LineEnding +
                              '  position fen <fen> [moves ...]' + LineEnding +
                              '  position startpos [moves ...]' + LineEnding +
                              '  quit' + LineEnding +
                              '  setoption name UCI_Chess960 value <true,false>' + LineEnding +
                              '  stop' + LineEnding +
                              '  uci' + LineEnding +
                              '  ucinewgame' + LineEnding +
                              'Custom commands:' + LineEnding +
                              '  board (display the current board)' + LineEnding +
                              '  help' + LineEnding +
                              '  moves (display legal moves for the current position)' + LineEnding +
                              '  perft <x>'
                            )
{$IFDEF LOG_MAIN}
                          else
                            LogLine(Format('** Unknown command: %s', [LCmd]))
{$ENDIF};
  end;
  EndSearch;
  if not SettingsFileExists then
    SaveSettings(LUseBook, LFactorPawnMove, LFactorPawnStruct, LFactorTargets, LFactorCastling, LFactorEnPassant, LFactorCheck, LFactorProtect, LFactorAttack, LFactorPawnMobil, LFactorNewPos);
  LBook[FALSE].Free;
  LBook[TRUE].Free;
{$IFDEF LOG_MAIN}
  LLog.Free;
{$ENDIF}
  DoneCriticalSection(LLock);
end.
