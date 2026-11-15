program pixelchess;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, IniFiles, ctypes, SDL3, SDL3_ttf, ChessTypes, ChessGame, Fen, Themes, UciEngine;

const
  CAppTitle = 'Pixel Chess';
  CAppVersion = '0.1.0';
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
  CSheetPieceSize = 26;
  CSheetPieceStep = 27;
  CSheetPiecesX = 5;
  CSheetWhitePiecesY = 8;
  CSheetBlackPiecesY = 38;
  CSheetBoardY = 255;
  CSheetPieceOrder = 'KQRBNP';
  CEngineMoveTime = 1000;
  CConfigFile = 'pixelchess.ini';
  CDefaultTheme = 'lanea';

type
  TBoardArray = array[0..7, 0..7] of char;

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
  LMouseX, LMouseY, LGrabX, LGrabY: single;
  LPromoting: boolean = FALSE;
  LPromotionMove: string;
  LTitleFont, LTextFont: PTTF_Font;
  LTheme: TTheme;
  LSquare, LMargin, LBoardSize, LWidth, LHeight, LDotSize: integer;
  LPieceTop, LPopupX, LPopupY, LPopupW, LPopupH: integer;
  LHelpSepY, LHelpY, LMaxLines: integer;
  LFramedBoard: boolean;
  LBoardTexture: PSDL_Texture;
  LPieceTextures: array[0..11] of PSDL_Texture;
  LEngine: TUciEngine = nil;
  LEngineColor: TPieceColor = pcBlack;
  LEngineName: string;
  LGrabCursor, LGrabbingCursor, LCurrentCursor: PSDL_Cursor;

procedure Fail(const AMessage: string);
begin
  WriteLn(ErrOutput, AMessage, ': ', SDL_GetError);
  Halt(1);
end;

function LoadTexture(const AName: string; const AColorKey: boolean = FALSE): PSDL_Texture;
var
  LPath: string;
  LSurface: PSDL_Surface;
begin
  LPath := Concat(SDL_GetBasePath, AName, '.png');
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
  LPath := Concat(SDL_GetBasePath, AName, '.png');
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

procedure SetWindowIcon;
var
  LPath: string;
  LSurface: PSDL_Surface;
begin
  LPath := Concat(SDL_GetBasePath, 'images/icon.png');
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
  LPath := Concat(SDL_GetBasePath, AFile);
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

procedure DrawText(const AFont: PTTF_Font; const AX, AY: single; const AText: string; const AColor: TSDL_Color);
var
  LSurface: PSDL_Surface;
  LTexture: PSDL_Texture;
  LRect: TSDL_FRect;
  LColor: TSDL_Color;
begin
  if AText = '' then
    exit;
  LColor := AColor;
  LColor.a := 255;
  LSurface := TTF_RenderText_Solid(AFont, PAnsiChar(AText), 0, LColor);
  if LSurface = nil then
    exit;
  LTexture := SDL_CreateTextureFromSurface(LRenderer, LSurface);
  if LTexture <> nil then
  begin
    SDL_SetTextureScaleMode(LTexture, SDL_SCALEMODE_NEAREST);
    LRect := MakeRect(Round(AX), Round(AY), LSurface^.w, LSurface^.h);
    SDL_RenderTexture(LRenderer, LTexture, nil, @LRect);
    SDL_DestroyTexture(LTexture);
  end;
  SDL_DestroySurface(LSurface);
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

procedure SetupTheme(const AName: string);
begin
  if not FindTheme(AName, LTheme) then
  begin
    WriteLn(ErrOutput, 'Unknown theme: ', AName, '. Available themes: ', ThemeNames, '.');
    Halt(1);
  end;
  LSquare := LTheme.Square;
  LMargin := LTheme.Margin;
  LBoardSize := 8 * LSquare + 2 * LMargin;
  LWidth := LBoardSize + CPanelWidth;
  LHeight := LBoardSize;
  LDotSize := 2 * (LSquare div 8);
end;

procedure StartEngine(const APath: string);
var
  LPath: string;
begin
  LPath := APath;
  if (ExtractFileDrive(LPath) = '') and not (LPath[1] in AllowDirectorySeparators) then
    LPath := Concat(SDL_GetBasePath, LPath);
  if not FileExists(LPath) then
  begin
    WriteLn(ErrOutput, 'Engine not found: ', LPath);
    Halt(1);
  end;
  try
    LEngine := TUciEngine.Create(LPath, ExtractFileDir(LPath));
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, E.Message);
      Halt(1);
    end;
  end;
  LEngineName := ExtractFileName(LPath);
end;

procedure LoadConfig;
var
  LIni: TIniFile;
  LThemeName, LEnginePath: string;
begin
  LIni := TIniFile.Create(Concat(SDL_GetBasePath, CConfigFile));
  try
    LThemeName := Trim(LIni.ReadString('Display', 'Theme', CDefaultTheme));
    LEnginePath := Trim(LIni.ReadString('Engine', 'Path', ''));
  finally
    LIni.Free;
  end;
  if LThemeName = '' then
    LThemeName := CDefaultTheme;
  SetupTheme(LThemeName);
  if LEnginePath <> '' then
    StartEngine(LEnginePath);
end;

procedure SetupPanel;
var
  LHelpLines: integer;
begin
  if LEngine <> nil then
    LHelpLines := 5
  else
    LHelpLines := 3;
  LHelpSepY := LHeight - 12 - LHelpLines * CHelpStep;
  LHelpY := LHelpSepY + 6;
  LMaxLines := (LHelpSepY - 6 - CListY) div CLineHeight;
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
  LIndex, w, h: integer;
begin
  if LTheme.Kind = tkSheet then
  begin
    LIndex := Pos(UpCase(c), CSheetPieceOrder) - 1;
    if WhitePiece(c) then
      LSrc := MakeRect(CSheetPiecesX + LIndex * CSheetPieceStep, CSheetWhitePiecesY, CSheetPieceSize, CSheetPieceSize)
    else
      LSrc := MakeRect(CSheetPiecesX + LIndex * CSheetPieceStep, CSheetBlackPiecesY, CSheetPieceSize, CSheetPieceSize);
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
  LSrc := MakeRect(ASrcX, CSheetBoardY + ASrcY, AW, AH);
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
begin
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
  LGame := TChessGame.Create(CFenStartPosition);
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

procedure UndoMove;
var
  LList, LSans, LShown, LUci: TStringList;
  i: integer;
begin
  if LMoves.Count = 0 then
    exit;
  LList := TStringList.Create;
  LSans := TStringList.Create;
  LShown := TStringList.Create;
  LUci := TStringList.Create;
  try
    LList.Assign(LMoves);
    LSans.Assign(LSanMoves);
    LShown.Assign(LShownMoves);
    LUci.Assign(LUciMoves);
    LList.Delete(LList.Count - 1);
    LSans.Delete(LSans.Count - 1);
    LShown.Delete(LShown.Count - 1);
    LUci.Delete(LUci.Count - 1);
    NewGame;
    for i := 0 to LList.Count - 1 do
      LGame.DoMove(LList[i]);
    LMoves.Assign(LList);
    LSanMoves.Assign(LSans);
    LShownMoves.Assign(LShown);
    LUciMoves.Assign(LUci);
    UpdatePosition;
  finally
    LList.Free;
    LSans.Free;
    LShown.Free;
    LUci.Free;
  end;
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

procedure UpdateEngine;
var
  LMove: string;
begin
  if LEngine = nil then
    exit;
  if LEngine.Poll(LMove) and EngineToMove then
  begin
    LMove := EngineMoveToGame(LMove);
    if LMove <> '' then
      PlayMove(LMove);
  end;
  if LEngine.Name <> '' then
    LEngineName := LEngine.Name;
  if not LEngine.Thinking and not LPromoting and (LGame.State = gsProgress) and EngineToMove then
    LEngine.Go(LUciMoves, CEngineMoveTime);
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
  UndoMove;
  if EngineToMove then
    UndoMove;
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
  if (LGame.State <> gsProgress) or EngineToMove then
    exit;
  if not ScreenToSquare(AX, AY, f, r) then
  begin
    Deselect;
    exit;
  end;
  if OwnPiece(LPosition[f, r]) and not (LSelected and (LTargets[f, r] <> '')) then
  begin
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
    exit;
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
  f, r, LCol, LRow, x, y: integer;
begin
  DrawBoardImage;
  if LShownMoves.Count > 0 then
  begin
    LLast := LShownMoves[LShownMoves.Count - 1];
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
      if LPosition[f, r] <> ' ' then
        DrawPiece(LPosition[f, r], ScreenX(f), ScreenY(r));
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
      result := 'Draw.';
  end;
end;

procedure DrawHelpLine(const AIndex: integer; const AKey, ALabel: string);
begin
  DrawText(LTextFont, LBoardSize + 8, LHelpY + AIndex * CHelpStep, AKey, Color(ciHelp));
  DrawText(LTextFont, LBoardSize + 40, LHelpY + AIndex * CHelpStep, ALabel, Color(ciHelp));
end;

procedure DrawPanel;
var
  LStatus, LSecond, LBlack, LNumber: string;
  LLines, LFirst, i: integer;
  y: single;
begin
  FillRect(LBoardSize, 0, LWidth - LBoardSize, LHeight, Color(ciPanel));
  FillRect(LBoardSize, 0, 2, LHeight, Color(ciPanelBorder));
  DrawText(LTitleFont, LBoardSize + (LWidth - LBoardSize - TextWidth(LTitleFont, UpperCase(CAppTitle))) div 2, CTitleY, UpperCase(CAppTitle), Color(ciTitle));
  LStatus := StatusText(LSecond);
  DrawText(LTextFont, LBoardSize + CStatusX, CStatusY, LStatus, Color(ciStatus));
  if LSecond <> '' then
    DrawText(LTextFont, LBoardSize + CStatusX, CSecondY, LSecond, Color(ciSecond));
  FillRect(LBoardSize + 8, CListY - 8, LWidth - LBoardSize - 16, 1, Color(ciSeparator));
  LLines := (LSanMoves.Count + 1) div 2;
  LFirst := 0;
  if LLines > LMaxLines then
    LFirst := LLines - LMaxLines;
  for i := LFirst to LLines - 1 do
  begin
    y := CListY + (i - LFirst) * CLineHeight;
    if 2 * i + 1 < LSanMoves.Count then
      LBlack := LSanMoves[2 * i + 1]
    else
      LBlack := '';
    LNumber := Format('%d.', [i + 1]);
    DrawText(LTextFont, LBoardSize + 34 - TextWidth(LTextFont, LNumber), y, LNumber, Color(ciHelp));
    DrawText(LTextFont, LBoardSize + 44, y, LSanMoves[2 * i], Color(ciList));
    DrawText(LTextFont, LBoardSize + 110, y, LBlack, Color(ciList));
  end;
  FillRect(LBoardSize + 8, LHelpSepY, LWidth - LBoardSize - 16, 1, Color(ciSeparator));
  i := 0;
  if LEngine <> nil then
  begin
    if LEngineColor = pcWhite then
      DrawText(LTextFont, LBoardSize + 8, LHelpY, LEngineName + ' plays White', Color(ciList))
    else
      DrawText(LTextFont, LBoardSize + 8, LHelpY, LEngineName + ' plays Black', Color(ciList));
    i := 1;
  end;
  DrawHelpLine(i, 'N', 'new game');
  DrawHelpLine(i + 1, 'F', 'flip board');
  if LEngine <> nil then
  begin
    DrawHelpLine(i + 2, 'S', 'switch sides');
    Inc(i);
  end;
  DrawHelpLine(i + 2, '<-', 'take back');
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

procedure MainLoop;
var
  e: TSDL_Event;
  LQuit: boolean = FALSE;
begin
  while not LQuit do
  begin
    while SDL_PollEvent(@e) do
    begin
      SDL_ConvertEventToRenderCoordinates(LRenderer, @e);
      case e.type_ of
        SDL_EVENT_QUIT:
          LQuit := TRUE;
        SDL_EVENT_KEY_DOWN:
          case e.key.key of
            SDLK_ESCAPE:
              if LPromoting then
              begin
                LPromoting := FALSE;
                Deselect;
              end else
                LQuit := TRUE;
            SDLK_N:
              NewGame;
            SDLK_F:
              LFlipped := not LFlipped;
            SDLK_S:
              SwitchSides;
            SDLK_BACKSPACE:
              TakeBack;
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
    UpdateEngine;
    UpdateCursor;
    Render;
  end;
end;

begin
  LoadConfig;
  SetupPanel;
  SDL_SetAppMetadata(CAppTitle, CAppVersion, 'pixelchess');
  if not SDL_Init(SDL_INIT_VIDEO) then
    Fail('SDL_Init');
  if not SDL_CreateWindowAndRenderer(CAppTitle + ' ' + CAppVersion, LWidth, LHeight, 0, @LWindow, @LRenderer) then
    Fail('SDL_CreateWindowAndRenderer');
  SetWindowIcon;
  SDL_SetRenderLogicalPresentation(LRenderer, LWidth, LHeight, SDL_LOGICAL_PRESENTATION_INTEGER_SCALE);
  if not SDL_SetRenderVSync(LRenderer, 1) then
    SDL_SetRenderVSync(LRenderer, SDL_RENDERER_VSYNC_ADAPTIVE);
  LoadTextures;
  LoadFonts;
  LoadCursors;
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
  FreeCursors;
  FreeFonts;
  FreeTextures;
  SDL_DestroyRenderer(LRenderer);
  SDL_DestroyWindow(LWindow);
  SDL_Quit;
end.
