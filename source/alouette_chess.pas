{$IFDEF ANDROID}
library alouette_chess;
{$ELSE}
program alouette_chess;
{$ENDIF}

{$mode objfpc}{$H+}

{$IFDEF WINDOWS}
{$R alouette_chess.rc}
{$ENDIF}

uses
{$IFDEF UNIX}
  CThreads,
{$ENDIF}
  SysUtils, Classes, IniFiles, ctypes, SDL3, SDL3_ttf, ChessTypes, ChessGame, Fen, Themes, UciEngine, LogFile;

const
  CAppTitle = 'Alouette Chess';
  CAppVersion = '0.2.0';
  CPromotionChars = 'qrbn';
  CPieceChars = 'PNBRQKpnbrqk';
  CPanelWidth = 210;
  CTitleY = 8;
  CStatusX = 12;
  CStatusY = 30;
  CSecondY = 44;
  CListY = 66;
  CLineHeight = 13;
  CHelpStep = 12;
  CButtonColumns = 3;
  CButtonHeight = 28;
  CButtonGap = 4;
  CSheetPieceSize = 26;
  CSheetPieceStep = 27;
  CSheetPiecesX = 185;
  CSheetPiecesY = 8;
  CSheetRowStep = 30;
  CSheetDir = 'm484';
  CSheetPieceOrder = 'KQRBNP';
  CEngineMoveTime = 1000;
  CAnimationTime = 200;
  CTextCacheSize = 512;
  CConfigFile = 'alouette-chess.ini';
  CLogFile = 'alouette-chess.log';
  CDefaultTheme = 'bftc';
  CDefaultScale = 1;
  CBuiltinEngine = 'builtin';
  CDefaultEngine = CBuiltinEngine;
  CConfigSection = 'alouette-chess';
  CDefaultLayout = {$IFDEF ANDROID}'vertical'{$ELSE}'horizontal'{$ENDIF};

type
  TBoardArray = array[0..7, 0..7] of char;
  TSound = (sndMove, sndCapture, sndCheck, sndVictory, sndDefeat, sndDraw);
  TSoundData = record
    Data: pcuint8;
    Len: cint;
  end;
  TCommand = (cmNewGame, cmFlip, cmSwitchSides, cmTakeBack, cmMute, cmCopyPgn, cmCopyFen, cmQuit);

const
  CCommandKeys: array[TCommand] of string = ('N', 'F', 'S', '<-', 'M', 'C', 'P', 'Esc');
  CCommandCodes: array[TCommand] of TSDL_Keycode = (SDLK_N, SDLK_F, SDLK_S, SDLK_BACKSPACE, SDLK_M, SDLK_C, SDLK_P, SDLK_ESCAPE);
  CCommandLabels: array[TCommand] of string = ('new game', 'flip board', 'switch sides', 'take back', 'mute', 'copy PGN', 'copy FEN', 'quit');

var
  LWindow: PSDL_Window;
  LRenderer: PSDL_Renderer;
  LGame: TChessGame;
  LMoves, LSanMoves, LShownMoves, LUciMoves: TStringList;
  LPosition: TBoardArray;
  LTargets: array[0..7, 0..7] of string;
  LFlipped: boolean = FALSE;
  LSelected: boolean = FALSE;
  LSelFile, LSelRank: integer;
  LDragging: boolean = FALSE;
  LReselected: boolean = FALSE;
  LMouseX, LMouseY, LGrabX, LGrabY: single;
  LPromoting: boolean = FALSE;
  LPromotionMove: string;
  LTitleFont, LTextFont: PTTF_Font;
  LTextCache: TStringList = nil;
  LTheme: TTheme;
  LSquare, LMargin, LBoardSize, LWidth, LHeight, LDotSize: integer;
  LPieceTop, LPopupX, LPopupY, LPopupW, LPopupH: integer;
  LHelpSepY, LHelpY, LMaxLines: integer;
  LPanelX, LPanelY, LPanelW, LPanelH, LButtonY: integer;
  LVertical: boolean = FALSE;
  LFramedBoard: boolean;
  LBoardTexture: PSDL_Texture;
  LPieceTextures: array[0..11] of PSDL_Texture;
  LEngine: TUciEngine = nil;
  LEngineColor: TPieceColor = pcBlack;
  LEngineName: string;
  LGrabCursor, LGrabbingCursor, LCurrentCursor: PSDL_Cursor;
  LAudioStream: PSDL_AudioStream = nil;
  LAudioSpec: TSDL_AudioSpec;
  LSounds: array[TSound] of TSoundData;
  LSoundEnabled: boolean = TRUE;
  LStartFen: string = '';
  LFirstMove: integer = 1;
  LBlackFirst: boolean = FALSE;
  LMoveTime: integer = CEngineMoveTime;
  LScale: integer = CDefaultScale;
  LHasEngineLine: boolean = FALSE;
  LEngineError: string = '';
  LNotice: string = '';
  LNoticeUntil: UInt64 = 0;
  LAnimating: boolean = FALSE;
  LAnimFromFile, LAnimFromRank, LAnimToFile, LAnimToRank: integer;
  LAnimPiece, LAnimCaptured: char;
  LAnimStart: UInt64;
  LAnimSound: TSound;
  LQuit: boolean = FALSE;
{$IFDEF ANDROID}
  LDataDir: string = '';
{$ENDIF}

procedure Report(const AText: string);
begin
  WriteLn(ErrOutput, AText);
  WriteLog(AText);
end;

procedure Fail(const AMessage: string);
begin
  Report(Concat(AMessage, ': ', SDL_GetError));
  Halt(1);
end;

function ResourcePath(const AName: string): string;
begin
{$IFDEF ANDROID}
  result := AName;
{$ELSE}
  result := Concat(SDL_GetBasePath, AName);
{$ENDIF}
end;

function DataPath(const AName: string): string;
{$IFDEF ANDROID}
var
  LPrefPath: PAnsiChar;
{$ENDIF}
begin
{$IFDEF ANDROID}
  if LDataDir = '' then
  begin
    LPrefPath := SDL_GetPrefPath('', 'alouette-chess');
    if LPrefPath <> nil then
    begin
      LDataDir := LPrefPath;
      SDL_free(LPrefPath);
    end;
  end;
  result := Concat(LDataDir, AName);
{$ELSE}
  result := Concat(SDL_GetBasePath, AName);
{$ENDIF}
end;

function LoadTexture(const AName: string; const AColorKey: boolean = FALSE): PSDL_Texture;
var
  LPath: string;
  LSurface: PSDL_Surface;
begin
  LPath := ResourcePath(Concat(AName, '.png'));
  LSurface := SDL_LoadPNG(PAnsiChar(LPath));
  if LSurface = nil then
    Fail('SDL_LoadPNG(' + LPath + ')');
  if AColorKey then
    SDL_SetSurfaceColorKey(LSurface, TRUE, SDL_MapSurfaceRGB(LSurface, $77, $99, $BB));
  result := SDL_CreateTextureFromSurface(LRenderer, LSurface);
  SDL_DestroySurface(LSurface);
  if result = nil then
    Fail('SDL_CreateTextureFromSurface');
  SDL_SetTextureScaleMode(result, SDL_SCALEMODE_NEAREST);
end;

function LoadCursor(const AName: string): PSDL_Cursor;
var
  LPath: string;
  LSurface: PSDL_Surface;
begin
  result := nil;
  LPath := ResourcePath(Concat(AName, '.png'));
  LSurface := SDL_LoadPNG(PAnsiChar(LPath));
  if LSurface = nil then
    exit;
  result := SDL_CreateColorCursor(LSurface, LSurface^.w div 2, LSurface^.h div 2);
  SDL_DestroySurface(LSurface);
end;

procedure LoadCursors;
begin
  LGrabCursor := LoadCursor('images/grab');
  LGrabbingCursor := LoadCursor('images/grabbing');
  LCurrentCursor := SDL_GetDefaultCursor;
end;

procedure FreeCursors;
begin
  SDL_SetCursor(SDL_GetDefaultCursor);
  if LGrabCursor <> nil then
    SDL_DestroyCursor(LGrabCursor);
  if LGrabbingCursor <> nil then
    SDL_DestroyCursor(LGrabbingCursor);
end;

procedure LoadSound(const ASound: TSound; const AName: string);
var
  LPath: string;
  LSpec: TSDL_AudioSpec;
  LBuf: pcuint8;
  LLen: cuint32;
begin
  LSounds[ASound].Data := nil;
  LSounds[ASound].Len := 0;
  LPath := ResourcePath(Concat('sounds/', AName, '.wav'));
  if not SDL_LoadWAV(PAnsiChar(LPath), @LSpec, @LBuf, @LLen) then
    exit;
  if (LSpec.format = LAudioSpec.format) and (LSpec.channels = LAudioSpec.channels) and (LSpec.freq = LAudioSpec.freq) then
  begin
    LSounds[ASound].Data := LBuf;
    LSounds[ASound].Len := LLen;
  end else
  begin
    if not SDL_ConvertAudioSamples(@LSpec, LBuf, LLen, @LAudioSpec, @LSounds[ASound].Data, @LSounds[ASound].Len) then
    begin
      LSounds[ASound].Data := nil;
      LSounds[ASound].Len := 0;
    end;
    SDL_free(LBuf);
  end;
end;

procedure InitAudio;
begin
  if not SDL_InitSubSystem(SDL_INIT_AUDIO) then
    exit;
  LAudioSpec.format := SDL_AUDIO_S16;
  LAudioSpec.channels := 1;
  LAudioSpec.freq := 44100;
  LAudioStream := SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, @LAudioSpec, nil, nil);
  if LAudioStream = nil then
    exit;
  LoadSound(sndMove, 'move');
  LoadSound(sndCapture, 'capture');
  LoadSound(sndCheck, 'check');
  LoadSound(sndVictory, 'victory');
  LoadSound(sndDefeat, 'defeat');
  LoadSound(sndDraw, 'draw');
  SDL_ResumeAudioStreamDevice(LAudioStream);
end;

procedure FreeAudio;
var
  LSound: TSound;
begin
  if LAudioStream = nil then
    exit;
  SDL_DestroyAudioStream(LAudioStream);
  LAudioStream := nil;
  for LSound := Low(TSound) to High(TSound) do
    SDL_free(LSounds[LSound].Data);
end;

procedure PlaySound(const ASound: TSound);
begin
  if not LSoundEnabled or (LAudioStream = nil) or (LSounds[ASound].Data = nil) then
    exit;
  SDL_ClearAudioStream(LAudioStream);
  SDL_PutAudioStreamData(LAudioStream, LSounds[ASound].Data, LSounds[ASound].Len);
end;

procedure SetWindowIcon;
var
  LPath: string;
  LSurface: PSDL_Surface;
begin
  LPath := ResourcePath('images/icon.png');
  LSurface := SDL_LoadPNG(PAnsiChar(LPath));
  if LSurface = nil then
    exit;
  SDL_SetWindowIcon(LWindow, LSurface);
  SDL_DestroySurface(LSurface);
end;

function MakeRect(const AX, AY, AW, AH: single): TSDL_FRect;
begin
  result.x := AX;
  result.y := AY;
  result.w := AW;
  result.h := AH;
end;

procedure FillRect(const AX, AY, AW, AH: single; const AColor: TSDL_Color);
var
  LRect: TSDL_FRect;
begin
  LRect := MakeRect(AX, AY, AW, AH);
  SDL_SetRenderDrawColor(LRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderFillRect(LRenderer, @LRect);
end;

procedure FrameRect(const AX, AY, AW, AH: single; const AColor: TSDL_Color);
var
  LRect: TSDL_FRect;
begin
  LRect := MakeRect(AX, AY, AW, AH);
  SDL_SetRenderDrawColor(LRenderer, AColor.r, AColor.g, AColor.b, AColor.a);
  SDL_RenderRect(LRenderer, @LRect);
end;

function OpenFont(const AFile: string; const ASize: single): PTTF_Font;
var
  LPath: string;
begin
  LPath := ResourcePath(AFile);
  result := TTF_OpenFont(PAnsiChar(LPath), ASize);
  if result = nil then
    Fail('TTF_OpenFont(' + LPath + ')');
end;

procedure LoadFonts;
begin
  if not TTF_Init then
    Fail('TTF_Init');
  LTitleFont := OpenFont('fonts/alagard.ttf', 16);
  LTextFont := OpenFont('fonts/Minecraftia-Regular.ttf', 8);
end;

procedure FreeFonts;
begin
  TTF_CloseFont(LTitleFont);
  TTF_CloseFont(LTextFont);
  TTF_Quit;
end;

function TextWidth(const AFont: PTTF_Font; const AText: string): integer;
var
  w, h: cint;
begin
  if (AText = '') or not TTF_GetStringSize(AFont, PAnsiChar(AText), 0, @w, @h) then
    exit(0);
  result := w;
end;

procedure ClearTextCache;
var
  i: integer;
begin
  if LTextCache = nil then
    exit;
  for i := 0 to LTextCache.Count - 1 do
    SDL_DestroyTexture(PSDL_Texture(LTextCache.Objects[i]));
  LTextCache.Clear;
end;

procedure FreeTextCache;
begin
  ClearTextCache;
  FreeAndNil(LTextCache);
end;

function TextTexture(const AFont: PTTF_Font; const AText: string; const AColor: TSDL_Color): PSDL_Texture;
var
  LKey: string;
  LIndex: integer;
  LSurface: PSDL_Surface;
  LColor: TSDL_Color;
begin
  if LTextCache = nil then
  begin
    LTextCache := TStringList.Create;
    LTextCache.CaseSensitive := TRUE;
    LTextCache.Sorted := TRUE;
  end;
  LKey := Format('%p|%.2x%.2x%.2x|%s', [Pointer(AFont), AColor.r, AColor.g, AColor.b, AText]);
  if LTextCache.Find(LKey, LIndex) then
    exit(PSDL_Texture(LTextCache.Objects[LIndex]));
  result := nil;
  LColor := AColor;
  LColor.a := 255;
  LSurface := TTF_RenderText_Solid(AFont, PAnsiChar(AText), 0, LColor);
  if LSurface = nil then
    exit;
  result := SDL_CreateTextureFromSurface(LRenderer, LSurface);
  SDL_DestroySurface(LSurface);
  if result = nil then
    exit;
  SDL_SetTextureScaleMode(result, SDL_SCALEMODE_NEAREST);
  if LTextCache.Count >= CTextCacheSize then
    ClearTextCache;
  LTextCache.AddObject(LKey, TObject(result));
end;

procedure DrawText(const AFont: PTTF_Font; const AX, AY: single; const AText: string; const AColor: TSDL_Color);
var
  LTexture: PSDL_Texture;
  LRect: TSDL_FRect;
  w, h: single;
begin
  if AText = '' then
    exit;
  LTexture := TextTexture(AFont, AText, AColor);
  if LTexture = nil then
    exit;
  SDL_GetTextureSize(LTexture, @w, @h);
  LRect := MakeRect(Round(AX), Round(AY), w, h);
  SDL_RenderTexture(LRenderer, LTexture, nil, @LRect);
end;

procedure DrawTextCentered(const ACenterX, ACenterY: single; const AText: string; const AColor: TSDL_Color);
begin
  DrawText(LTextFont, ACenterX - TextWidth(LTextFont, AText) div 2, ACenterY - 5, AText, AColor);
end;

function WhitePiece(const c: char): boolean;
begin
  result := c in ['A'..'Z'];
end;

function Color(const AId: TColorId): TSDL_Color;
begin
  result := ToColor(LTheme.Colors[AId]);
end;

function MixColors(const AId1, AId2: TColorId): TSDL_Color;
var
  LColor1, LColor2: TSDL_Color;
begin
  LColor1 := Color(AId1);
  LColor2 := Color(AId2);
  result.r := (LColor1.r + LColor2.r) div 2;
  result.g := (LColor1.g + LColor2.g) div 2;
  result.b := (LColor1.b + LColor2.b) div 2;
  result.a := 255;
end;

procedure SetupTheme(const AName: string);
begin
  if not FindTheme(AName, LTheme) then
  begin
    Report(Concat('Unknown theme: ', AName, '. Available themes: ', ThemeNames, '.'));
    Halt(1);
  end;
  LSquare := LTheme.Square;
  LMargin := LTheme.Margin;
  LBoardSize := 8 * LSquare + 2 * LMargin;
  if LVertical then
  begin
    LPanelX := 0;
    LPanelY := LBoardSize;
    LPanelW := LBoardSize;
    LPanelH := LBoardSize * 11 div 9;
  end else
  begin
    LPanelX := LBoardSize;
    LPanelY := 0;
    LPanelW := CPanelWidth;
    LPanelH := LBoardSize;
  end;
  LWidth := LPanelX + LPanelW;
  LHeight := LPanelY + LPanelH;
  LDotSize := 2 * (LSquare div 8);
end;

{$IFDEF ANDROID}
procedure CopyResource(const AName: string);
var
  LTarget: string;
  LData: pointer;
  LSize: csize_t;
begin
  LTarget := DataPath(AName);
  if FileExists(LTarget) then
    exit;
  LData := SDL_LoadFile(PAnsiChar(ResourcePath(AName)), @LSize);
  if LData = nil then
  begin
    Report(Concat('SDL_LoadFile(', AName, '): ', SDL_GetError));
    exit;
  end;
  if not SDL_SaveFile(PAnsiChar(LTarget), LData, LSize) then
    Report(Concat('SDL_SaveFile(', LTarget, '): ', SDL_GetError));
  SDL_free(LData);
end;

procedure InstallEngineFiles;
begin
  if not SDL_CreateDirectory(PAnsiChar(DataPath('engine'))) then
    Report(Concat('SDL_CreateDirectory: ', SDL_GetError));
  CopyResource('engine/white.txt');
  CopyResource('engine/black.txt');
end;
{$ENDIF}

procedure StartEngine(const APath: string);
var
  LPath: string;
begin
  if APath = CBuiltinEngine then
  begin
    WriteLog('Starting built-in engine');
{$IFDEF ANDROID}
    InstallEngineFiles;
{$ENDIF}
    LEngine := TUciEngine.CreateBuiltin(DataPath('engine/alouette.cfg'), DataPath('engine/'));
    LEngineName := 'Alouette';
    exit;
  end;
  LPath := APath;
  if (ExtractFileDrive(LPath) = '') and not (LPath[1] in AllowDirectorySeparators) then
    LPath := ResourcePath(LPath);
  if not FileExists(LPath) then
  begin
    Report('Engine not found: ' + LPath);
    Halt(1);
  end;
  WriteLog('Starting engine: ' + LPath);
  try
    LEngine := TUciEngine.Create(LPath, ExtractFileDir(LPath));
  except
    on E: Exception do
    begin
      Report(E.Message);
      Halt(1);
    end;
  end;
  LEngineName := ExtractFileName(LPath);
end;

procedure CreateDefaultConfig(const APath: string);
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.Add('[' + CConfigSection + ']');
    LList.Add('theme=' + CDefaultTheme);
    LList.Add('scale=' + IntToStr(CDefaultScale));
    LList.Add('engine=' + CDefaultEngine);
    LList.Add('movetime=' + IntToStr(CEngineMoveTime));
    LList.Add('sound=1');
    LList.Add('log=1');
    LList.Add('layout=' + CDefaultLayout);
    try
      LList.SaveToFile(APath);
    except
      on E: Exception do
        Report(E.Message);
    end;
  finally
    LList.Free;
  end;
end;

const
  CUsage = 'Usage: alouette-chess [-t NAME] [-s N] [-e PATH] [-m MS] [--sound=0|1] [--log=0|1|2] [--layout=horizontal|vertical] [-f FEN] [-h]';

procedure PrintUsage;
begin
  WriteLn(CUsage);
  WriteLn('  --theme=NAME, -t NAME    graphical theme: ', ThemeNames);
  WriteLn('  --scale=N, -s N          window scale factor, limited by the screen size');
  WriteLn('  --engine=PATH, -e PATH   UCI engine, or builtin for the bundled Alouette; an empty path disables the engine');
  WriteLn('  --movetime=MS, -m MS     engine thinking time per move, in milliseconds');
  WriteLn('  --sound=0|1              start muted (0) or with sounds (1)');
  WriteLn('  --log=0|1|2              no log (0), simple log (1), log with the UCI dialogue (2)');
  WriteLn('  --layout=horizontal|vertical  panel beside (horizontal) or below (vertical) the board');
  WriteLn('  --fen=FEN, -f FEN        start position');
  WriteLn('  --help, -h               show this help');
end;

procedure UsageError(const AMessage: string);
begin
  Report(AMessage);
  WriteLn(ErrOutput, CUsage);
  Halt(1);
end;

function CheckFen(var AFen: string): boolean;
var
  LFields, LRanks: TStringArray;
  LRows: array[0..7] of string;
  LCastling: string;
  LWhiteKings, LBlackKings, LCount, LValue, i, j, f: integer;
  c: char;
begin
  result := FALSE;
  LFields := Trim(AFen).Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(LFields) = 4 then
  begin
    SetLength(LFields, 6);
    LFields[4] := '0';
    LFields[5] := '1';
  end;
  if Length(LFields) <> 6 then
    exit;
  LRanks := LFields[0].Split(['/']);
  if Length(LRanks) <> 8 then
    exit;
  LWhiteKings := 0;
  LBlackKings := 0;
  for i := 0 to 7 do
  begin
    LCount := 0;
    LRows[i] := '';
    for j := 1 to Length(LRanks[i]) do
    begin
      c := LRanks[i][j];
      if c in ['1'..'8'] then
      begin
        Inc(LCount, Ord(c) - Ord('0'));
        LRows[i] := LRows[i] + StringOfChar(' ', Ord(c) - Ord('0'));
      end
      else if Pos(c, CPieceChars) > 0 then
      begin
        Inc(LCount);
        LRows[i] := LRows[i] + c;
        if c = 'K' then
          Inc(LWhiteKings)
        else if c = 'k' then
          Inc(LBlackKings)
        else if (c in ['P', 'p']) and (i in [0, 7]) then
          exit;
      end else
        exit;
    end;
    if LCount <> 8 then
      exit;
  end;
  if (LWhiteKings <> 1) or (LBlackKings <> 1) then
    exit;
  if (LFields[1] <> 'w') and (LFields[1] <> 'b') then
    exit;
  if LFields[2] <> '-' then
    for j := 1 to Length(LFields[2]) do
      if not (LFields[2][j] in ['K', 'Q', 'k', 'q']) then
        exit;
  LCastling := '';
  if (Pos('K', LFields[2]) > 0) and (LRows[7][5] = 'K') and (LRows[7][8] = 'R') then
    LCastling := LCastling + 'K';
  if (Pos('Q', LFields[2]) > 0) and (LRows[7][5] = 'K') and (LRows[7][1] = 'R') then
    LCastling := LCastling + 'Q';
  if (Pos('k', LFields[2]) > 0) and (LRows[0][5] = 'k') and (LRows[0][8] = 'r') then
    LCastling := LCastling + 'k';
  if (Pos('q', LFields[2]) > 0) and (LRows[0][5] = 'k') and (LRows[0][1] = 'r') then
    LCastling := LCastling + 'q';
  if LCastling = '' then
    LCastling := '-';
  LFields[2] := LCastling;
  if LFields[3] <> '-' then
  begin
    if (Length(LFields[3]) <> 2) or not (LFields[3][1] in ['a'..'h']) then
      exit;
    f := Ord(LFields[3][1]) - Ord('a') + 1;
    if LFields[1] = 'w' then
    begin
      if (LFields[3][2] <> '6') or (LRows[3][f] <> 'p') or (LRows[2][f] <> ' ') or (LRows[1][f] <> ' ') then
        exit;
    end
    else if (LFields[3][2] <> '3') or (LRows[4][f] <> 'P') or (LRows[5][f] <> ' ') or (LRows[6][f] <> ' ') then
      exit;
  end;
  if not TryStrToInt(LFields[4], LValue) or (LValue < 0) then
    exit;
  if not TryStrToInt(LFields[5], LValue) or (LValue < 1) then
    exit;
  if LFields[1] = 'w' then
    LFields[1] := 'b'
  else
    LFields[1] := 'w';
  with TChessGame.Create(Concat(LFields[0], ' ', LFields[1], ' - - 0 1')) do
  try
    if Check then
      exit;
  finally
    Free;
  end;
  if LFields[1] = 'w' then
    LFields[1] := 'b'
  else
    LFields[1] := 'w';
  AFen := string.Join(' ', LFields);
  result := TRUE;
end;

procedure SetupStartPosition(const AFen: string);
var
  LFen: string;
  LFields: TStringArray;
begin
  LFen := AFen;
  if not CheckFen(LFen) then
  begin
    Report('Invalid FEN: ' + AFen);
    Halt(1);
  end;
  with TChessGame.Create(LFen) do
  try
    LStartFen := GetFen(FALSE);
  finally
    Free;
  end;
  if LStartFen = CFenStartPosition then
    LStartFen := '';
  LFields := LFen.Split([' ']);
  LBlackFirst := LFields[1] = 'b';
  LFirstMove := StrToInt(LFields[5]);
end;

function StartFen: string;
begin
  if LStartFen = '' then
    result := CFenStartPosition
  else
    result := LStartFen;
end;

procedure ParseCommandLine(var AThemeName, AScale, AEnginePath, AMoveTime, ASound, ALog, ALayout, AFen: string);
var
  i: integer;
  LArg: string;

  function TryOption(const ALong, AShort: string; out AValue: string): boolean;
  begin
    result := TRUE;
    if Pos(ALong + '=', LArg) = 1 then
      AValue := Trim(Copy(LArg, Length(ALong) + 2, MaxInt))
    else if (LArg = ALong) or ((AShort <> '') and (LArg = AShort)) then
    begin
      if i = ParamCount then
        UsageError('Missing value after ' + LArg + '.');
      Inc(i);
      AValue := Trim(ParamStr(i));
    end
    else
      result := FALSE;
  end;

var
  LValue: string;
begin
  i := 1;
  while i <= ParamCount do
  begin
    LArg := ParamStr(i);
    if (LArg = '--help') or (LArg = '-h') then
    begin
      PrintUsage;
      Halt(0);
    end
    else if TryOption('--theme', '-t', LValue) then
      AThemeName := LValue
    else if TryOption('--scale', '-s', LValue) then
      AScale := LValue
    else if TryOption('--engine', '-e', LValue) then
    begin
      if (LValue <> '') and (LValue <> CBuiltinEngine) then
        LValue := ExpandFileName(LValue);
      AEnginePath := LValue;
    end
    else if TryOption('--movetime', '-m', LValue) then
      AMoveTime := LValue
    else if TryOption('--sound', '', LValue) then
      ASound := LValue
    else if TryOption('--log', '', LValue) then
      ALog := LValue
    else if TryOption('--layout', '', LValue) then
      ALayout := LValue
    else if TryOption('--fen', '-f', LValue) then
      AFen := LValue
    else
      UsageError('Unknown option: ' + LArg);
    Inc(i);
  end;
end;

procedure InitVideo;
begin
  SDL_SetAppMetadata(CAppTitle, CAppVersion, 'alouette-chess');
  if not SDL_Init(SDL_INIT_VIDEO) then
    Fail('SDL_Init');
end;

procedure CheckScale;
var
  LRect: TSDL_Rect;
  LMax: integer;
begin
  if not SDL_GetDisplayUsableBounds(SDL_GetPrimaryDisplay, @LRect) then
    exit;
  LMax := LRect.w div LWidth;
  if LRect.h div LHeight < LMax then
    LMax := LRect.h div LHeight;
  if LMax < 1 then
    LMax := 1;
  if LScale > LMax then
  begin
    Report(Format('Warning: scale %d is too large for this screen (%dx%d), using %d with theme %s.', [LScale, LRect.w, LRect.h, LMax, LTheme.Title]));
    LScale := LMax;
  end;
end;

procedure LoadConfig;
var
  LIni: TIniFile;
  LPath, LThemeName, LScaleText, LEnginePath, LMoveTimeText, LSoundText, LLogText, LLayoutText, LFen: string;
  LVersion: integer;
begin
  LPath := DataPath(CConfigFile);
  if not FileExists(LPath) then
    CreateDefaultConfig(LPath);
  LIni := TIniFile.Create(LPath);
  try
    LThemeName := Trim(LIni.ReadString(CConfigSection, 'theme', CDefaultTheme));
    LScaleText := Trim(LIni.ReadString(CConfigSection, 'scale', IntToStr(CDefaultScale)));
    LEnginePath := Trim(LIni.ReadString(CConfigSection, 'engine', ''));
    LMoveTimeText := Trim(LIni.ReadString(CConfigSection, 'movetime', IntToStr(CEngineMoveTime)));
    LSoundText := Trim(LIni.ReadString(CConfigSection, 'sound', '1'));
    LLogText := Trim(LIni.ReadString(CConfigSection, 'log', '1'));
    LLayoutText := Trim(LIni.ReadString(CConfigSection, 'layout', CDefaultLayout));
  finally
    LIni.Free;
  end;
  LFen := '';
  ParseCommandLine(LThemeName, LScaleText, LEnginePath, LMoveTimeText, LSoundText, LLogText, LLayoutText, LFen);
  if LSoundText = '' then
    LSoundEnabled := TRUE
  else if (LSoundText = '0') or (LSoundText = '1') then
    LSoundEnabled := LSoundText = '1'
  else
  begin
    Report(Concat('Invalid sound value: ', LSoundText, '. Expected 0 or 1.'));
    Halt(1);
  end;
  if LLogText = '' then
    LogLevel := 1
  else if not TryStrToInt(LLogText, LogLevel) or (LogLevel < 0) or (LogLevel > 2) then
  begin
    Report(Concat('Invalid log level: ', LLogText, '. Expected 0, 1 or 2.'));
    Halt(1);
  end;
  if (LLayoutText = '') or (LLayoutText = 'horizontal') then
    LVertical := FALSE
  else if LLayoutText = 'vertical' then
    LVertical := TRUE
  else
  begin
    Report(Concat('Invalid layout: ', LLayoutText, '. Expected horizontal or vertical.'));
    Halt(1);
  end;
  if LogLevel >= 1 then
    OpenLog(DataPath(CLogFile));
  WriteLog(Concat(CAppTitle, ' ', CAppVersion));
  WriteLog(Format('Built %s %s with FPC %s for %s-%s', [{$I %DATE%}, {$I %TIME%}, {$I %FPCVERSION%}, {$I %FPCTARGETCPU%}, {$I %FPCTARGETOS%}]));
  LVersion := SDL_GetVersion;
  WriteLog(Format('SDL %d.%d.%d', [SDL_VERSIONNUM_MAJOR(LVersion), SDL_VERSIONNUM_MINOR(LVersion), SDL_VERSIONNUM_MICRO(LVersion)]));
  LVersion := TTF_Version;
  WriteLog(Format('SDL_ttf %d.%d.%d', [SDL_VERSIONNUM_MAJOR(LVersion), SDL_VERSIONNUM_MINOR(LVersion), SDL_VERSIONNUM_MICRO(LVersion)]));
  if LScaleText = '' then
    LScale := CDefaultScale
  else if not TryStrToInt(LScaleText, LScale) or (LScale < 1) then
  begin
    Report(Concat('Invalid scale: ', LScaleText, '. Expected a positive number.'));
    Halt(1);
  end;
  if LMoveTimeText = '' then
    LMoveTime := CEngineMoveTime
  else if not TryStrToInt(LMoveTimeText, LMoveTime) or (LMoveTime <= 0) then
  begin
    Report(Concat('Invalid move time: ', LMoveTimeText, '. Expected a positive number of milliseconds.'));
    Halt(1);
  end;
  if LFen <> '' then
    SetupStartPosition(LFen);
  if LThemeName = '' then
    LThemeName := CDefaultTheme;
  SetupTheme(LThemeName);
  InitVideo;
  CheckScale;
  WriteLog(Format('Theme %s, scale %d', [LTheme.Title, LScale]));
  if LEnginePath <> '' then
    StartEngine(LEnginePath);
  LHasEngineLine := LEngine <> nil;
end;

function CommandVisible(const ACommand: TCommand): boolean;
begin
  result := (ACommand <> cmSwitchSides) or LHasEngineLine;
end;

function CommandEnabled(const ACommand: TCommand): boolean;
begin
  result := (ACommand <> cmSwitchSides) or (LEngine <> nil);
end;

function CommandLabel(const ACommand: TCommand): string;
begin
  if (ACommand = cmMute) and not LSoundEnabled then
    result := 'unmute'
  else
    result := CCommandLabels[ACommand];
end;

function VisibleCommandCount: integer;
var
  c: TCommand;
begin
  result := 0;
  for c := Low(TCommand) to High(TCommand) do
    if CommandVisible(c) then
      Inc(result);
end;

procedure SetupPanel;
var
  LRows: integer;
begin
  if LVertical then
  begin
    LRows := (VisibleCommandCount + CButtonColumns - 1) div CButtonColumns;
    LButtonY := LPanelY + LPanelH - 8 - LRows * CButtonHeight - (LRows - 1) * CButtonGap;
    LHelpSepY := LButtonY - 8 - Ord(LHasEngineLine) * CHelpStep - 6 * Ord(LHasEngineLine);
  end else
    LHelpSepY := LPanelY + LPanelH - 12 - (Ord(LHasEngineLine) + VisibleCommandCount) * CHelpStep;
  LHelpY := LHelpSepY + 6;
  LMaxLines := (LHelpSepY - 6 - LPanelY - CListY) div CLineHeight;
end;

procedure TextureSize(const ATexture: PSDL_Texture; out AW, AH: integer);
var
  w, h: single;
begin
  SDL_GetTextureSize(ATexture, @w, @h);
  AW := Round(w);
  AH := Round(h);
end;

function ImageDir: string;
begin
  if LTheme.Kind = tkSheet then
    result := Concat('images/', CSheetDir, '/')
  else
    result := Concat('images/', LTheme.Name, '/');
end;

procedure LoadTextures;
var
  i, w, h: integer;
  c: char;
begin
  LPieceTop := 0;
  LFramedBoard := LTheme.Kind = tkDrawn;
  case LTheme.Kind of
    tkSheet:
      begin
        LBoardTexture := LoadTexture(ImageDir + 'chess_boards');
        LPieceTextures[0] := LoadTexture(ImageDir + 'chess_pieces_v5', TRUE);
      end;
    tkImage, tkDrawn:
      begin
        if LTheme.Kind = tkImage then
        begin
          LBoardTexture := LoadTexture(ImageDir + 'board');
          TextureSize(LBoardTexture, w, h);
          LFramedBoard := w < LBoardSize;
        end;
        for i := 0 to 11 do
        begin
          c := CPieceChars[i + 1];
          if WhitePiece(c) then
            LPieceTextures[i] := LoadTexture(ImageDir + 'w' + LowerCase(c))
          else
            LPieceTextures[i] := LoadTexture(ImageDir + 'b' + c);
          TextureSize(LPieceTextures[i], w, h);
          if h - LSquare > LPieceTop then
            LPieceTop := h - LSquare;
        end;
      end;
  end;
  LPopupW := 4 * LSquare + 40;
  LPopupH := LSquare + LPieceTop + 20;
  LPopupX := (LBoardSize - LPopupW) div 2;
  LPopupY := (LBoardSize - LPopupH) div 2;
end;

procedure FreeTextures;
var
  i: integer;
begin
  if LBoardTexture <> nil then
    SDL_DestroyTexture(LBoardTexture);
  for i := 0 to 11 do
    if LPieceTextures[i] <> nil then
      SDL_DestroyTexture(LPieceTextures[i]);
end;

procedure DrawPiece(const c: char; const AX, AY: single);
var
  LSrc, LDst: TSDL_FRect;
  LTexture: PSDL_Texture;
  LIndex, LRow, w, h: integer;
begin
  if LTheme.Kind = tkSheet then
  begin
    LIndex := Pos(UpCase(c), CSheetPieceOrder) - 1;
    if WhitePiece(c) then
      LRow := LTheme.Sheet.White
    else
      LRow := LTheme.Sheet.Black;
    LSrc := MakeRect(CSheetPiecesX + LIndex * CSheetPieceStep, CSheetPiecesY + LRow * CSheetRowStep, CSheetPieceSize, CSheetPieceSize);
    LDst := MakeRect(AX + (LSquare - CSheetPieceSize) div 2, AY + (LSquare - CSheetPieceSize) div 2, CSheetPieceSize, CSheetPieceSize);
    SDL_RenderTexture(LRenderer, LPieceTextures[0], @LSrc, @LDst);
    exit;
  end;
  LTexture := LPieceTextures[Pos(c, CPieceChars) - 1];
  TextureSize(LTexture, w, h);
  if h > LSquare then
    LDst := MakeRect(AX + (LSquare - w) div 2, AY + LSquare - h, w, h)
  else
    LDst := MakeRect(AX + (LSquare - w) div 2, AY + (LSquare - h) div 2, w, h);
  SDL_RenderTexture(LRenderer, LTexture, nil, @LDst);
end;

procedure DrawFrame;
var
  i, j, a: integer;
  LFile, LRank: string;
begin
  FillRect(0, 0, LBoardSize, LBoardSize, Color(ciFrame));
  for i := 0 to 7 do
  begin
    if LFlipped then
      j := 7 - i
    else
      j := i;
    LFile := Chr(Ord('a') + j);
    LRank := Chr(Ord('8') - j);
    a := LMargin + i * LSquare + LSquare div 2;
    DrawTextCentered(a, LMargin div 2, LFile, Color(ciCoord));
    DrawTextCentered(a, LBoardSize - LMargin div 2, LFile, Color(ciCoord));
    DrawTextCentered(LMargin div 2, a, LRank, Color(ciCoord));
    DrawTextCentered(LBoardSize - LMargin div 2, a, LRank, Color(ciCoord));
  end;
end;

procedure DrawSheetPart(const ASrcX, ASrcY, ADstX, ADstY, AW, AH: single);
var
  LSrc, LDst: TSDL_FRect;
begin
  LSrc := MakeRect(ASrcX, LTheme.Sheet.Board + ASrcY, AW, AH);
  LDst := MakeRect(ADstX, ADstY, AW, AH);
  SDL_RenderTexture(LRenderer, LBoardTexture, @LSrc, @LDst);
end;

procedure DrawBoardImage;
var
  i, j, a, b, w, h: integer;
  LRect: TSDL_FRect;
begin
  if LFramedBoard then
    DrawFrame;
  case LTheme.Kind of
    tkImage:
      begin
        TextureSize(LBoardTexture, w, h);
        if LFramedBoard then
          LRect := MakeRect(LMargin, LMargin, w, h)
        else
          LRect := MakeRect(0, 0, w, h);
        SDL_RenderTexture(LRenderer, LBoardTexture, nil, @LRect);
      end;
    tkDrawn:
      for i := 0 to 7 do
        for j := 0 to 7 do
          if (i + j) mod 2 = 0 then
            FillRect(LMargin + i * LSquare, LMargin + j * LSquare, LSquare, LSquare, Color(ciLight))
          else
            FillRect(LMargin + i * LSquare, LMargin + j * LSquare, LSquare, LSquare, Color(ciDark));
    tkSheet:
      begin
        DrawSheetPart(0, 0, 0, 0, LBoardSize, LBoardSize);
        if LFlipped then
          for i := 0 to 7 do
          begin
            j := 7 - i;
            a := LMargin + i * LSquare;
            b := LMargin + j * LSquare;
            DrawSheetPart(b, 0, a, 0, LSquare, LMargin);
            DrawSheetPart(b, LBoardSize - LMargin, a, LBoardSize - LMargin, LSquare, LMargin);
            DrawSheetPart(0, b, 0, a, LMargin, LSquare);
            DrawSheetPart(LBoardSize - LMargin, b, LBoardSize - LMargin, a, LMargin, LSquare);
          end;
      end;
  end;
end;

function PromotionX(const AIndex: integer): single;
begin
  result := LPopupX + 8 + AIndex * (LSquare + 8);
end;

function PromotionY: single;
begin
  result := LPopupY + 10 + LPieceTop;
end;

function PromotionIndexAt(const AX, AY: single): integer;
var
  i: integer;
begin
  result := -1;
  for i := 0 to 3 do
    if (AX >= PromotionX(i)) and (AX < PromotionX(i) + LSquare)
      and (AY >= LPopupY + 10) and (AY < PromotionY + LSquare) then
      exit(i);
end;

procedure DrawPromotionFrame(const AHover: integer);
var
  i: integer;
begin
  FillRect(LPopupX, LPopupY, LPopupW, LPopupH, Color(ciPopup));
  FrameRect(LPopupX, LPopupY, LPopupW, LPopupH, Color(ciPopupFrame));
  FrameRect(LPopupX + 1, LPopupY + 1, LPopupW - 2, LPopupH - 2, Color(ciPopupInnerFrame));
  for i := 0 to 3 do
    if i = AHover then
      FillRect(PromotionX(i), PromotionY, LSquare, LSquare, Color(ciPopupHover))
    else
      FillRect(PromotionX(i), PromotionY, LSquare, LSquare, Color(ciPopupCell));
end;

function SquareName(const AFile, ARank: integer): string;
begin
  result := Concat(Chr(Ord('a') + AFile), Chr(Ord('1') + ARank));
end;

function ScreenX(const AFile: integer): single;
begin
  if LFlipped then
    result := LMargin + LSquare * (7 - AFile)
  else
    result := LMargin + LSquare * AFile;
end;

function ScreenY(const ARank: integer): single;
begin
  if LFlipped then
    result := LMargin + LSquare * ARank
  else
    result := LMargin + LSquare * (7 - ARank);
end;

function ScreenToSquare(const AX, AY: single; out AFile, ARank: integer): boolean;
var
  LCol, LRow: integer;
begin
  result := (AX >= LMargin) and (AX < LMargin + 8 * LSquare) and (AY >= LMargin) and (AY < LMargin + 8 * LSquare);
  if not result then
    exit;
  LCol := Trunc((AX - LMargin) / LSquare);
  LRow := Trunc((AY - LMargin) / LSquare);
  if LFlipped then
  begin
    AFile := 7 - LCol;
    ARank := LRow;
  end else
  begin
    AFile := LCol;
    ARank := 7 - LRow;
  end;
end;

procedure UpdatePosition;
var
  LFen: string;
  i, f, r: integer;
begin
  for f := 0 to 7 do
    for r := 0 to 7 do
      LPosition[f, r] := ' ';
  LFen := LGame.GetFen(FALSE);
  f := 0;
  r := 7;
  i := 1;
  while (i <= Length(LFen)) and (LFen[i] <> ' ') do
  begin
    case LFen[i] of
      '/':
        begin
          Dec(r);
          f := 0;
        end;
      '1'..'8':
        Inc(f, Ord(LFen[i]) - Ord('0'));
      else
        begin
          if (f <= 7) and (r >= 0) then
            LPosition[f, r] := LFen[i];
          Inc(f);
        end;
    end;
    Inc(i);
  end;
end;

procedure ClearTargets;
var
  f, r: integer;
begin
  for f := 0 to 7 do
    for r := 0 to 7 do
      LTargets[f, r] := '';
end;

procedure ComputeTargets(const AFile, ARank: integer);
var
  LList: TStringArray;
  LMove, LFrom: string;
  i, LFile, LRank: integer;
begin
  ClearTargets;
  LFrom := SquareName(AFile, ARank);
  LList := LGame.LegalMoves.Split(' ');
  for i := 0 to High(LList) do
  begin
    LMove := Copy(LList[i], 1, 4);
    if (Length(LMove) <> 4) or (Copy(LMove, 1, 2) <> LFrom) then
      continue;
    LFile := Ord(LMove[3]) - Ord('a');
    LRank := Ord(LMove[4]) - Ord('1');
    LTargets[LFile, LRank] := LMove;
    if LGame.IsCastling(LMove) then
    begin
      if LMove[3] > LMove[1] then
        LTargets[6, LRank] := LMove
      else
        LTargets[2, LRank] := LMove;
    end;
  end;
end;

procedure Deselect;
begin
  LSelected := FALSE;
  LDragging := FALSE;
  ClearTargets;
end;

function ShownMove(const AMove: string): string;
begin
  result := Copy(AMove, 1, 4);
  if LGame.IsCastling(AMove) then
  begin
    if AMove[3] > AMove[1] then
      result[3] := 'g'
    else
      result[3] := 'c';
  end;
end;

procedure PlayMove(const AMove: string);
var
  LSan: string;
  i: integer;
  LCapture: boolean;
  LSound: TSound;
begin
  LCapture := LGame.IsCapture(AMove) or (LGame.IsEnPassant(AMove) <> '');
  LShownMoves.Append(ShownMove(AMove));
  if LGame.IsCastling(AMove) then
    LUciMoves.Append(ShownMove(AMove))
  else
    LUciMoves.Append(AMove);
  LSan := LGame.GetSan(AMove);
  if (LSan <> '') and (LSan[1] in ['a'..'h']) and (AMove[1] <> AMove[3]) then
  begin
    i := Pos('=', LSan);
    if i > 0 then
      LSan := Concat(AMove[1], 'x', Copy(AMove, 3, 2), Copy(LSan, i, MaxInt))
    else
      LSan := Concat(AMove[1], 'x', Copy(AMove, 3, 2));
  end;
  LGame.DoMove(AMove);
  if LGame.State = gsCheckmate then
    LSan := LSan + '#'
  else if LGame.Check then
    LSan := LSan + '+';
  LMoves.Append(AMove);
  LSanMoves.Append(LSan);
  UpdatePosition;
  Deselect;
  case LGame.State of
    gsCheckmate:
      if (LEngine <> nil) and (LGame.ActiveColor <> LEngineColor) then
        LSound := sndDefeat
      else
        LSound := sndVictory;
    gsStalemate, gsDraw:
      LSound := sndDraw;
  else
    if LGame.Check then
      LSound := sndCheck
    else if LCapture then
      LSound := sndCapture
    else
      LSound := sndMove;
  end;
  if LAnimating then
    LAnimSound := LSound
  else
    PlaySound(LSound);
end;

procedure StartAnimation(const AMove: string);
var
  LShown: string;
begin
  LShown := ShownMove(AMove);
  LAnimFromFile := Ord(LShown[1]) - Ord('a');
  LAnimFromRank := Ord(LShown[2]) - Ord('1');
  LAnimToFile := Ord(LShown[3]) - Ord('a');
  LAnimToRank := Ord(LShown[4]) - Ord('1');
  LAnimPiece := LPosition[LAnimFromFile, LAnimFromRank];
  LAnimCaptured := LPosition[LAnimToFile, LAnimToRank];
  LAnimStart := SDL_GetTicks;
  LAnimating := TRUE;
end;

procedure UpdateAnimation;
begin
  if LAnimating and (SDL_GetTicks - LAnimStart >= CAnimationTime) then
  begin
    LAnimating := FALSE;
    PlaySound(LAnimSound);
  end;
end;

procedure TryMove(const AFile, ARank: integer);
var
  LMove: string;
begin
  LMove := LTargets[AFile, ARank];
  if LMove = '' then
    exit;
  if LGame.IsPromotion(LMove) then
  begin
    LPromoting := TRUE;
    LPromotionMove := LMove;
    LDragging := FALSE;
  end else
    PlayMove(LMove);
end;

procedure NewGame;
begin
  LGame.Free;
  LGame := TChessGame.Create(StartFen);
  LMoves.Clear;
  LSanMoves.Clear;
  LShownMoves.Clear;
  LUciMoves.Clear;
  if LEngine <> nil then
    LEngine.NewGame;
  LPromoting := FALSE;
  Deselect;
  UpdatePosition;
end;

procedure UndoMoves(ACount: integer);
var
  i: integer;
begin
  if ACount > LMoves.Count then
    ACount := LMoves.Count;
  if ACount = 0 then
    exit;
  for i := 1 to ACount do
  begin
    LMoves.Delete(LMoves.Count - 1);
    LSanMoves.Delete(LSanMoves.Count - 1);
    LShownMoves.Delete(LShownMoves.Count - 1);
    LUciMoves.Delete(LUciMoves.Count - 1);
  end;
  LGame.Free;
  LGame := TChessGame.Create(StartFen);
  for i := 0 to LMoves.Count - 1 do
    LGame.DoMove(LMoves[i]);
  UpdatePosition;
end;

function EngineToMove: boolean;
begin
  result := (LEngine <> nil) and (LGame.ActiveColor = LEngineColor);
end;

function EngineMoveToGame(const AMove: string): string;
var
  LList: TStringArray;
  LMove: string;
  i: integer;
begin
  result := '';
  LList := LGame.LegalMoves.Split(' ');
  for i := 0 to High(LList) do
  begin
    LMove := Copy(LList[i], 1, 4);
    if LGame.IsCastling(LMove) then
      LMove := ShownMove(LMove);
    if LMove = Copy(AMove, 1, 4) then
      exit(Concat(Copy(LList[i], 1, 4), Copy(AMove, 5, 1)));
  end;
end;

procedure EngineFailed(const AReason: string);
begin
  WriteLog('Engine error: ' + AReason);
  LEngineError := AReason;
  FreeAndNil(LEngine);
end;

procedure UpdateEngine;
var
  LMove, LBest: string;
begin
  if LEngine = nil then
    exit;
  if LEngine.Poll(LBest) and EngineToMove then
  begin
    LMove := EngineMoveToGame(LBest);
    if LMove = '' then
    begin
      EngineFailed('illegal move ' + LBest);
      exit;
    end;
    StartAnimation(LMove);
    PlayMove(LMove);
  end;
  if LEngine.Name <> '' then
    LEngineName := LEngine.Name;
  if not LEngine.Running then
  begin
    EngineFailed('stopped');
    exit;
  end;
  if not LEngine.Thinking and not LPromoting and (LGame.State = gsProgress) and EngineToMove then
    LEngine.Go(LStartFen, LUciMoves, LMoveTime);
end;

function GameResult: string;
begin
  case LGame.State of
    gsCheckmate:
      if LGame.ActiveColor = pcWhite then
        result := '0-1'
      else
        result := '1-0';
    gsStalemate, gsDraw:
      result := '1/2-1/2';
  else
    result := '*';
  end;
end;

function PlayerName(const AColor: TPieceColor): string;
begin
  if (LEngine <> nil) and (LEngineColor = AColor) then
    result := LEngineName
  else
    result := 'Human';
end;

function MoveSlot(const AIndex: integer): integer;
begin
  result := AIndex + Ord(LBlackFirst);
end;

function GamePgn: string;
var
  LText, LLine, LToken: string;
  i, LSlot: integer;

  procedure AddToken(const AToken: string);
  begin
    if (LLine <> '') and (Length(LLine) + 1 + Length(AToken) > 79) then
    begin
      LText := LText + LLine + LineEnding;
      LLine := '';
    end;
    if LLine = '' then
      LLine := AToken
    else
      LLine := LLine + ' ' + AToken;
  end;

begin
  LText := Format('[Event "Casual game"]%s[Site "Alouette Chess"]%s[Date "%s"]%s[Round "-"]%s[White "%s"]%s[Black "%s"]%s[Result "%s"]%s',
    [LineEnding, LineEnding, FormatDateTime('yyyy.mm.dd', Now), LineEnding, LineEnding,
     PlayerName(pcWhite), LineEnding, PlayerName(pcBlack), LineEnding, GameResult, LineEnding]);
  if LStartFen <> '' then
    LText := LText + Format('[SetUp "1"]%s[FEN "%s"]%s', [LineEnding, LStartFen, LineEnding]);
  LText := LText + LineEnding;
  LLine := '';
  for i := 0 to LSanMoves.Count - 1 do
  begin
    LSlot := MoveSlot(i);
    LToken := LSanMoves[i];
    if not Odd(LSlot) then
      LToken := Format('%d. %s', [LFirstMove + LSlot div 2, LToken])
    else if i = 0 then
      LToken := Format('%d... %s', [LFirstMove, LToken]);
    AddToken(LToken);
  end;
  AddToken(GameResult);
  result := LText + LLine + LineEnding;
end;

procedure ShowNotice(const AText: string);
begin
  LNotice := AText;
  LNoticeUntil := SDL_GetTicks + 2000;
end;

procedure CopyToClipboard(const AText, ANotice: string);
begin
  if SDL_SetClipboardText(PAnsiChar(AText)) then
    ShowNotice(ANotice)
  else
    ShowNotice('Copy failed.');
end;

procedure SwitchSides;
begin
  if (LEngine = nil) or LPromoting then
    exit;
  LEngine.Stop;
  Deselect;
  if LEngineColor = pcWhite then
    LEngineColor := pcBlack
  else
    LEngineColor := pcWhite;
  LFlipped := LEngineColor = pcWhite;
end;

procedure TakeBack;
begin
  if LPromoting then
    exit;
  Deselect;
  if LEngine <> nil then
    LEngine.Stop;
  if (LEngine <> nil) and not EngineToMove then
    UndoMoves(2)
  else
    UndoMoves(1);
end;

procedure ExecuteCommand(const ACommand: TCommand);
begin
  case ACommand of
    cmNewGame:
      NewGame;
    cmFlip:
      LFlipped := not LFlipped;
    cmSwitchSides:
      SwitchSides;
    cmTakeBack:
      TakeBack;
    cmMute:
      LSoundEnabled := not LSoundEnabled;
    cmCopyPgn:
      CopyToClipboard(GamePgn, 'PGN copied.');
    cmCopyFen:
      CopyToClipboard(LGame.GetFen(FALSE), 'FEN copied.');
    cmQuit:
      LQuit := TRUE;
  end;
end;

function HelpLineY(const ALine: integer): integer;
begin
  result := LHelpY + ALine * CHelpStep;
end;

function CommandRect(const ASlot: integer): TSDL_FRect;
var
  w: integer;
begin
  if LVertical then
  begin
    w := (LPanelW - 16 - (CButtonColumns - 1) * CButtonGap) div CButtonColumns;
    result := MakeRect(LPanelX + 8 + (ASlot mod CButtonColumns) * (w + CButtonGap),
      LButtonY + (ASlot div CButtonColumns) * (CButtonHeight + CButtonGap), w, CButtonHeight);
  end else
    result := MakeRect(LPanelX + 4, HelpLineY(Ord(LHasEngineLine) + ASlot), LPanelW - 8, CHelpStep);
end;

function CommandAt(const AX, AY: single; out ACommand: TCommand): boolean;
var
  LSlot: integer;
  LRect: TSDL_FRect;
  c: TCommand;
begin
  result := FALSE;
  LSlot := 0;
  for c := Low(TCommand) to High(TCommand) do
    if CommandVisible(c) then
    begin
      LRect := CommandRect(LSlot);
      if (AX >= LRect.x) and (AX < LRect.x + LRect.w) and (AY >= LRect.y) and (AY < LRect.y + LRect.h) then
      begin
        ACommand := c;
        exit(CommandEnabled(c));
      end;
      Inc(LSlot);
    end;
end;

function OwnPiece(const c: char): boolean;
begin
  result := (c <> ' ') and (WhitePiece(c) = (LGame.ActiveColor = pcWhite));
end;

procedure UpdateCursor;
var
  f, r: integer;
  LCursor: PSDL_Cursor;
begin
  LCursor := nil;
  if LDragging then
    LCursor := LGrabbingCursor
  else if not LPromoting and (LGame.State = gsProgress) and not EngineToMove
    and ScreenToSquare(LMouseX, LMouseY, f, r) and OwnPiece(LPosition[f, r]) then
    LCursor := LGrabCursor;
  if LCursor = nil then
    LCursor := SDL_GetDefaultCursor;
  if LCursor <> LCurrentCursor then
  begin
    SDL_SetCursor(LCursor);
    LCurrentCursor := LCursor;
  end;
end;

procedure MouseDown(const AX, AY: single);
var
  f, r, i: integer;
  LCommand: TCommand;
begin
  if LPromoting then
  begin
    i := PromotionIndexAt(AX, AY);
    LPromoting := FALSE;
    if i >= 0 then
      PlayMove(LPromotionMove + CPromotionChars[i + 1])
    else
      Deselect;
    exit;
  end;
  if (AX >= LPanelX) and (AY >= LPanelY) then
  begin
    if CommandAt(AX, AY, LCommand) then
      ExecuteCommand(LCommand)
    else
      Deselect;
    exit;
  end;
  if (LGame.State <> gsProgress) or EngineToMove then
    exit;
  if not ScreenToSquare(AX, AY, f, r) then
  begin
    Deselect;
    exit;
  end;
  if OwnPiece(LPosition[f, r]) and not (LSelected and (LTargets[f, r] <> '')) then
  begin
    LReselected := LSelected and (f = LSelFile) and (r = LSelRank);
    LSelected := TRUE;
    LSelFile := f;
    LSelRank := r;
    ComputeTargets(f, r);
    LDragging := TRUE;
    LGrabX := AX - ScreenX(f);
    LGrabY := AY - (ScreenY(r));
  end else if LSelected and (LTargets[f, r] <> '') then
    TryMove(f, r)
  else
    Deselect;
end;

procedure MouseUp(const AX, AY: single);
var
  f, r: integer;
begin
  if not LDragging then
    exit;
  LDragging := FALSE;
  if not ScreenToSquare(AX, AY, f, r) then
    exit;
  if (f = LSelFile) and (r = LSelRank) then
  begin
    if LReselected then
      Deselect;
    exit;
  end;
  if LTargets[f, r] <> '' then
    TryMove(f, r)
  else
    Deselect;
end;

procedure DrawSquareHighlight(const ASquare: string; const AColor: TSDL_Color);
var
  f, r: integer;
begin
  f := Ord(ASquare[1]) - Ord('a');
  r := Ord(ASquare[2]) - Ord('1');
  FillRect(ScreenX(f), ScreenY(r), LSquare, LSquare, AColor);
end;

procedure DrawBoard;
var
  LLast: string;
  f, r, LCol, LRow, x, y, i: integer;
  t: single;
begin
  DrawBoardImage;
  i := LShownMoves.Count - 1;
  if LAnimating then
    Dec(i);
  if i >= 0 then
  begin
    LLast := LShownMoves[i];
    DrawSquareHighlight(Copy(LLast, 1, 2), Color(ciLastFrom));
    DrawSquareHighlight(Copy(LLast, 3, 2), Color(ciLastTo));
  end;
  if LGame.Check then
  begin
    LGame.GetKingCheckedXY(x, y);
    FillRect(ScreenX(x - 1), ScreenY(y - 1), LSquare, LSquare, Color(ciCheck));
  end;
  if LSelected then
  begin
    FillRect(ScreenX(LSelFile), ScreenY(LSelRank), LSquare, LSquare, Color(ciSelected));
    for f := 0 to 7 do
      for r := 0 to 7 do
        if LTargets[f, r] <> '' then
        begin
          if LPosition[f, r] = ' ' then
            FillRect(ScreenX(f) + (LSquare - LDotSize) div 2, ScreenY(r) + (LSquare - LDotSize) div 2, LDotSize, LDotSize, Color(ciDot))
          else
          begin
            FrameRect(ScreenX(f), ScreenY(r), LSquare, LSquare, Color(ciTargetOuter));
            FrameRect(ScreenX(f) + 1, ScreenY(r) + 1, LSquare - 2, LSquare - 2, Color(ciTargetInner));
          end;
        end;
  end;
  for LRow := 0 to 7 do
    for LCol := 0 to 7 do
    begin
      if LFlipped then
      begin
        f := 7 - LCol;
        r := LRow;
      end else
      begin
        f := LCol;
        r := 7 - LRow;
      end;
      if LDragging and (f = LSelFile) and (r = LSelRank) then
        continue;
      if LAnimating and (f = LAnimToFile) and (r = LAnimToRank) then
      begin
        if LAnimCaptured <> ' ' then
          DrawPiece(LAnimCaptured, ScreenX(f), ScreenY(r));
        continue;
      end;
      if LPosition[f, r] <> ' ' then
        DrawPiece(LPosition[f, r], ScreenX(f), ScreenY(r));
    end;
  if LAnimating then
  begin
    t := (SDL_GetTicks - LAnimStart) / CAnimationTime;
    if t > 1 then
      t := 1;
    DrawPiece(LAnimPiece,
      Round(ScreenX(LAnimFromFile) + (ScreenX(LAnimToFile) - ScreenX(LAnimFromFile)) * t),
      Round(ScreenY(LAnimFromRank) + (ScreenY(LAnimToRank) - ScreenY(LAnimFromRank)) * t));
  end;
  if LDragging then
    DrawPiece(LPosition[LSelFile, LSelRank], Round(LMouseX - LGrabX), Round(LMouseY - LGrabY));
end;

function StatusText(out ASecondLine: string): string;
begin
  ASecondLine := '';
  case LGame.State of
    gsProgress:
      begin
        if LGame.ActiveColor = pcWhite then
          result := 'White to move'
        else
          result := 'Black to move';
        if LGame.Check then
          ASecondLine := 'Check!';
      end;
    gsCheckmate:
      begin
        result := 'Checkmate.';
        if LGame.ActiveColor = pcWhite then
          ASecondLine := 'Black wins.'
        else
          ASecondLine := 'White wins.';
      end;
    gsStalemate:
      result := 'Stalemate.';
    gsDraw:
      begin
        result := 'Draw.';
        case LGame.DrawReason of
          drFiftyMoves:
            ASecondLine := 'Fifty-move rule.';
          drRepetition:
            ASecondLine := 'Threefold repetition.';
          drMaterial:
            ASecondLine := 'Insufficient material.';
        end;
      end;
  end;
end;

function FitText(const AText: string; const AMaxWidth: integer): string;
begin
  result := AText;
  if TextWidth(LTextFont, result) <= AMaxWidth then
    exit;
  while (result <> '') and (TextWidth(LTextFont, result + '...') > AMaxWidth) do
    SetLength(result, Length(result) - 1);
  result := result + '...';
end;

procedure DrawCommand(const ASlot: integer; const ACommand: TCommand; const AHover: boolean);
var
  LColor: TSDL_Color;
  LRect: TSDL_FRect;
begin
  LRect := CommandRect(ASlot);
  if AHover then
    FillRect(LRect.x, LRect.y, LRect.w, LRect.h, MixColors(ciPanel, ciSeparator));
  if CommandEnabled(ACommand) then
    LColor := Color(ciHelp)
  else
    LColor := MixColors(ciHelp, ciPanel);
  if LVertical then
  begin
    FrameRect(LRect.x, LRect.y, LRect.w, LRect.h, Color(ciSeparator));
    DrawTextCentered(LRect.x + LRect.w / 2, LRect.y + LRect.h / 2, CommandLabel(ACommand), LColor);
  end else
  begin
    DrawText(LTextFont, LPanelX + 8, LRect.y, CCommandKeys[ACommand], LColor);
    DrawText(LTextFont, LPanelX + 40, LRect.y, CommandLabel(ACommand), LColor);
  end;
end;

procedure DrawPanel;
var
  LStatus, LSecond, LWhite, LBlack, LNumber: string;
  LLines, LFirst, i: integer;
  y: single;
  c, LHoverCommand: TCommand;
  LHover: boolean;
begin
  FillRect(LPanelX, LPanelY, LPanelW, LPanelH, Color(ciPanel));
  if LVertical then
    FillRect(LPanelX, LPanelY, LPanelW, 2, Color(ciPanelBorder))
  else
    FillRect(LPanelX, LPanelY, 2, LPanelH, Color(ciPanelBorder));
  DrawText(LTitleFont, LPanelX + (LPanelW - TextWidth(LTitleFont, UpperCase(CAppTitle))) div 2, LPanelY + CTitleY, UpperCase(CAppTitle), Color(ciTitle));
  LStatus := StatusText(LSecond);
  if (LNotice <> '') and (SDL_GetTicks < LNoticeUntil) then
    LSecond := LNotice;
  DrawText(LTextFont, LPanelX + CStatusX, LPanelY + CStatusY, LStatus, Color(ciStatus));
  if LSecond <> '' then
    DrawText(LTextFont, LPanelX + CStatusX, LPanelY + CSecondY, LSecond, Color(ciSecond));
  FillRect(LPanelX + 8, LPanelY + CListY - 8, LPanelW - 16, 1, Color(ciSeparator));
  LLines := (MoveSlot(LSanMoves.Count) + 1) div 2;
  LFirst := 0;
  if LLines > LMaxLines then
    LFirst := LLines - LMaxLines;
  for i := LFirst to LLines - 1 do
  begin
    y := LPanelY + CListY + (i - LFirst) * CLineHeight;
    LWhite := '...';
    if 2 * i - Ord(LBlackFirst) >= 0 then
      LWhite := LSanMoves[2 * i - Ord(LBlackFirst)];
    if 2 * i + 1 - Ord(LBlackFirst) < LSanMoves.Count then
      LBlack := LSanMoves[2 * i + 1 - Ord(LBlackFirst)]
    else
      LBlack := '';
    LNumber := Format('%d.', [LFirstMove + i]);
    DrawText(LTextFont, LPanelX + 34 - TextWidth(LTextFont, LNumber), y, LNumber, Color(ciHelp));
    DrawText(LTextFont, LPanelX + 44, y, LWhite, Color(ciList));
    DrawText(LTextFont, LPanelX + 110, y, LBlack, Color(ciList));
  end;
  FillRect(LPanelX + 8, LHelpSepY, LPanelW - 16, 1, Color(ciSeparator));
  if LHasEngineLine then
  begin
    if LEngine = nil then
      LSecond := ' ' + LEngineError
    else if LEngineColor = pcWhite then
      LSecond := ' plays White'
    else
      LSecond := ' plays Black';
    DrawText(LTextFont, LPanelX + 8, LHelpY, FitText(LEngineName, LPanelW - 16 - TextWidth(LTextFont, LSecond)) + LSecond, Color(ciList));
  end;
  LHover := not LDragging and not LPromoting and CommandAt(LMouseX, LMouseY, LHoverCommand);
  i := 0;
  for c := Low(TCommand) to High(TCommand) do
    if CommandVisible(c) then
    begin
      DrawCommand(i, c, LHover and (c = LHoverCommand));
      Inc(i);
    end;
end;

procedure DrawPromotion;
var
  i: integer;
  c: char;
begin
  FillRect(0, 0, LBoardSize, LBoardSize, Color(ciOverlay));
  DrawPromotionFrame(PromotionIndexAt(LMouseX, LMouseY));
  for i := 0 to 3 do
  begin
    c := CPromotionChars[i + 1];
    if LGame.ActiveColor = pcWhite then
      c := UpCase(c);
    DrawPiece(c, PromotionX(i), PromotionY);
  end;
end;

procedure Render;
begin
  SDL_SetRenderDrawColor(LRenderer, Color(ciClear).r, Color(ciClear).g, Color(ciClear).b, Color(ciClear).a);
  SDL_RenderClear(LRenderer);
  SDL_SetRenderDrawBlendMode(LRenderer, SDL_BLENDMODE_BLEND);
  DrawBoard;
  DrawPanel;
  if LPromoting then
    DrawPromotion;
  SDL_RenderPresent(LRenderer);
end;

procedure HandleEvent(var e: TSDL_Event);
var
  c: TCommand;
begin
  SDL_ConvertEventToRenderCoordinates(LRenderer, @e);
  if LAnimating and ((e.type_ = SDL_EVENT_KEY_DOWN) or (e.type_ = SDL_EVENT_MOUSE_BUTTON_DOWN)
    or (e.type_ = SDL_EVENT_MOUSE_BUTTON_UP)) then
    exit;
  case e.type_ of
    SDL_EVENT_QUIT:
      LQuit := TRUE;
    SDL_EVENT_KEY_DOWN:
      if (e.key.key = SDLK_ESCAPE) and LPromoting then
      begin
        LPromoting := FALSE;
        Deselect;
      end else
        for c := Low(TCommand) to High(TCommand) do
          if (e.key.key = CCommandCodes[c]) and CommandEnabled(c) then
            ExecuteCommand(c);
    SDL_EVENT_WINDOW_MOUSE_LEAVE:
      begin
        LMouseX := -1;
        LMouseY := -1;
      end;
    SDL_EVENT_MOUSE_MOTION:
      begin
        LMouseX := e.motion.x;
        LMouseY := e.motion.y;
      end;
    SDL_EVENT_MOUSE_BUTTON_DOWN:
      if e.button.button = SDL_BUTTON_LEFT then
      begin
        LMouseX := e.button.x;
        LMouseY := e.button.y;
        MouseDown(e.button.x, e.button.y);
      end;
    SDL_EVENT_MOUSE_BUTTON_UP:
      if e.button.button = SDL_BUTTON_LEFT then
        MouseUp(e.button.x, e.button.y);
  end;
end;

function WaitTimeout: cint32;
var
  LNow: UInt64;
begin
  if LAnimating then
    exit(10);
  result := -1;
  if LEngine <> nil then
  begin
    if LEngine.Thinking or (EngineToMove and (LGame.State = gsProgress)) then
      exit(10);
    result := 250;
  end;
  LNow := SDL_GetTicks;
  if (LNotice <> '') and (LNow < LNoticeUntil) then
    if (result < 0) or (LNoticeUntil - LNow < UInt64(result)) then
      result := LNoticeUntil - LNow;
end;

procedure MainLoop;
var
  e: TSDL_Event;
begin
  while not LQuit do
  begin
    if SDL_WaitEventTimeout(@e, WaitTimeout) then
      repeat
        HandleEvent(e);
      until not SDL_PollEvent(@e);
    UpdateEngine;
    UpdateAnimation;
    UpdateCursor;
    Render;
  end;
end;

procedure Run;
begin
  LoadConfig;
  SetupPanel;
  if not SDL_CreateWindowAndRenderer(CAppTitle, LScale * LWidth, LScale * LHeight, 0, @LWindow, @LRenderer) then
    Fail('SDL_CreateWindowAndRenderer');
  SetWindowIcon;
  SDL_SetRenderLogicalPresentation(LRenderer, LWidth, LHeight, SDL_LOGICAL_PRESENTATION_INTEGER_SCALE);
  if not SDL_SetRenderVSync(LRenderer, 1) then
    SDL_SetRenderVSync(LRenderer, SDL_RENDERER_VSYNC_ADAPTIVE);
  LoadTextures;
  LoadFonts;
  LoadCursors;
  InitAudio;
  LMoves := TStringList.Create;
  LSanMoves := TStringList.Create;
  LShownMoves := TStringList.Create;
  LUciMoves := TStringList.Create;
  LGame := nil;
  NewGame;
  MainLoop;
  LGame.Free;
  LMoves.Free;
  LSanMoves.Free;
  LShownMoves.Free;
  LUciMoves.Free;
  LEngine.Free;
  FreeAudio;
  FreeCursors;
  FreeTextCache;
  FreeFonts;
  FreeTextures;
  SDL_DestroyRenderer(LRenderer);
  SDL_DestroyWindow(LWindow);
  SDL_Quit;
  WriteLog('Exit');
end;

{$IFDEF ANDROID}
function SDL_main(argc: cint; argv: PPAnsiChar): cint; cdecl;
begin
  Run;
  result := 0;
end;

exports
  SDL_main;

begin
{$ELSE}
begin
  Run;
{$ENDIF}
end.
