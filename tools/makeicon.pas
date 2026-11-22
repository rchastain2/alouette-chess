program makeicon;

{$MODE objfpc}{$H+}

uses
  SysUtils, FPImage, FPReadPNG, FPWritePNG, win3icon;

function IsOpaque(const AColor: TFPColor): boolean;
begin
  result := AColor.Alpha >= $8000;
end;

function NearestColor(const APalette: TIconPalette; const AColor: TFPColor): byte;
var
  i: integer;
  LDistance, LBest: longint;
begin
  result := 0;
  LBest := High(longint);
  for i := 0 to IconColorCount - 1 do
    with APalette[i] do
    begin
      LDistance := Sqr(Red - AColor.Red shr 8) + Sqr(Green - AColor.Green shr 8) + Sqr(Blue - AColor.Blue shr 8);
      if LDistance < LBest then
      begin
        LBest := LDistance;
        result := i;
      end;
    end;
end;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, AMessage);
  Halt(1);
end;

const
  DarkLimit = 40;

type
  TColorArray = array of TIconColor;

function ToIconColor(const AColor: TFPColor): TIconColor;
begin
  result.Red := AColor.Red shr 8;
  result.Green := AColor.Green shr 8;
  result.Blue := AColor.Blue shr 8;
end;

function Channel(const AColor: TIconColor; AChannel: integer): byte;
begin
  case AChannel of
    0: result := AColor.Red;
    1: result := AColor.Green;
  else
    result := AColor.Blue;
  end;
end;

function IsDark(const AColor: TIconColor): boolean;
begin
  result := (AColor.Red < DarkLimit) and (AColor.Green < DarkLimit) and (AColor.Blue < DarkLimit);
end;

procedure BoxRange(const AColors: TColorArray; AFirst, ALast: integer; out AChannel, ARange: integer);
var
  i, c, LMin, LMax: integer;
begin
  AChannel := 0;
  ARange := -1;
  for c := 0 to 2 do
  begin
    LMin := 255;
    LMax := 0;
    for i := AFirst to ALast do
    begin
      if Channel(AColors[i], c) < LMin then LMin := Channel(AColors[i], c);
      if Channel(AColors[i], c) > LMax then LMax := Channel(AColors[i], c);
    end;
    if LMax - LMin > ARange then
    begin
      ARange := LMax - LMin;
      AChannel := c;
    end;
  end;
end;

procedure SortBox(var AColors: TColorArray; AFirst, ALast, AChannel: integer);
var
  i, j: integer;
  LColor: TIconColor;
begin
  for i := AFirst + 1 to ALast do
  begin
    LColor := AColors[i];
    j := i - 1;
    while (j >= AFirst) and (Channel(AColors[j], AChannel) > Channel(LColor, AChannel)) do
    begin
      AColors[j + 1] := AColors[j];
      Dec(j);
    end;
    AColors[j + 1] := LColor;
  end;
end;

function BuildPalette(var AColors: TColorArray): TIconPalette;
var
  LFirst, LLast: array[1..IconColorCount - 1] of integer;
  LCount, i, j, LBest, LBestRange, LChannel, LRange, LMiddle: integer;
  LRed, LGreen, LBlue: longint;
begin
  FillChar(result, SizeOf(result), 0);
  if Length(AColors) = 0 then
    Exit;
  LCount := 1;
  LFirst[1] := 0;
  LLast[1] := High(AColors);
  while LCount < IconColorCount - 1 do
  begin
    LBest := 0;
    LBestRange := 0;
    for i := 1 to LCount do
      if LLast[i] > LFirst[i] then
      begin
        BoxRange(AColors, LFirst[i], LLast[i], LChannel, LRange);
        if LRange > LBestRange then
        begin
          LBestRange := LRange;
          LBest := i;
        end;
      end;
    if LBest = 0 then
      Break;
    BoxRange(AColors, LFirst[LBest], LLast[LBest], LChannel, LRange);
    SortBox(AColors, LFirst[LBest], LLast[LBest], LChannel);
    LMiddle := (LFirst[LBest] + LLast[LBest]) div 2;
    Inc(LCount);
    LFirst[LCount] := LMiddle + 1;
    LLast[LCount] := LLast[LBest];
    LLast[LBest] := LMiddle;
  end;
  for i := 1 to LCount do
  begin
    LRed := 0;
    LGreen := 0;
    LBlue := 0;
    for j := LFirst[i] to LLast[i] do
    begin
      Inc(LRed, AColors[j].Red);
      Inc(LGreen, AColors[j].Green);
      Inc(LBlue, AColors[j].Blue);
    end;
    j := LLast[i] - LFirst[i] + 1;
    result[i].Red := (LRed + j div 2) div j;
    result[i].Green := (LGreen + j div 2) div j;
    result[i].Blue := (LBlue + j div 2) div j;
  end;
end;

procedure ConvertImage(AImage: TFPCustomImage; out AIcon: TWin3Icon);
var
  x, y, LLeft, LTop, LRight, LBottom, LOffsetX, LOffsetY: integer;
  LColors: TColorArray;
  LColor: TIconColor;
begin
  LLeft := AImage.Width;
  LTop := AImage.Height;
  LRight := -1;
  LBottom := -1;
  for y := 0 to AImage.Height - 1 do
    for x := 0 to AImage.Width - 1 do
      if IsOpaque(AImage.Colors[x, y]) then
      begin
        if x < LLeft then LLeft := x;
        if x > LRight then LRight := x;
        if y < LTop then LTop := y;
        if y > LBottom then LBottom := y;
      end;
  if LRight < 0 then
    Fail('Image is fully transparent');
  if (LRight - LLeft + 1 > IconWidth) or (LBottom - LTop + 1 > IconHeight) then
    Fail(Format('Visible area is %dx%d, larger than %dx%d', [LRight - LLeft + 1, LBottom - LTop + 1, IconWidth, IconHeight]));

  LOffsetX := LLeft - (IconWidth - (LRight - LLeft + 1)) div 2;
  LOffsetY := LTop - (IconHeight - (LBottom - LTop + 1)) div 2;

  ClearIcon(AIcon);
  SetLength(LColors, 0);
  for y := 0 to IconHeight - 1 do
    for x := 0 to IconWidth - 1 do
      if (x + LOffsetX >= 0) and (x + LOffsetX < AImage.Width)
      and (y + LOffsetY >= 0) and (y + LOffsetY < AImage.Height)
      and IsOpaque(AImage.Colors[x + LOffsetX, y + LOffsetY]) then
      begin
        LColor := ToIconColor(AImage.Colors[x + LOffsetX, y + LOffsetY]);
        if not IsDark(LColor) then
        begin
          SetLength(LColors, Length(LColors) + 1);
          LColors[High(LColors)] := LColor;
        end;
      end;
  AIcon.Palette := BuildPalette(LColors);

  for y := 0 to IconHeight - 1 do
    for x := 0 to IconWidth - 1 do
      if (x + LOffsetX >= 0) and (x + LOffsetX < AImage.Width)
      and (y + LOffsetY >= 0) and (y + LOffsetY < AImage.Height)
      and IsOpaque(AImage.Colors[x + LOffsetX, y + LOffsetY]) then
        AIcon.Pixels[y, x] := NearestColor(AIcon.Palette, AImage.Colors[x + LOffsetX, y + LOffsetY])
      else
        AIcon.Transparent[y, x] := TRUE;
end;

procedure SavePreview(const AFileName: string; const AIcon: TWin3Icon; AScale: integer);
var
  LImage: TFPMemoryImage;
  LWriter: TFPWriterPNG;
  LColor: TFPColor;
  x, y: integer;
begin
  LImage := TFPMemoryImage.Create(IconWidth * AScale, IconHeight * AScale);
  LWriter := TFPWriterPNG.Create;
  try
    LWriter.UseAlpha := TRUE;
    LWriter.WordSized := FALSE;
    for y := 0 to LImage.Height - 1 do
      for x := 0 to LImage.Width - 1 do
        if AIcon.Transparent[y div AScale, x div AScale] then
          LImage.Colors[x, y] := colTransparent
        else
        begin
          with AIcon.Palette[AIcon.Pixels[y div AScale, x div AScale]] do
          begin
            LColor.Red := Red * $101;
            LColor.Green := Green * $101;
            LColor.Blue := Blue * $101;
          end;
          LColor.Alpha := alphaOpaque;
          LImage.Colors[x, y] := LColor;
        end;
    LImage.SaveToFile(AFileName, LWriter);
  finally
    LWriter.Free;
    LImage.Free;
  end;
end;

var
  LImage: TFPMemoryImage;
  LIcon: TWin3Icon;
  LError: TIconError;
  LScale: integer;

begin
  if not (ParamCount in [2..4]) then
    Fail('Usage: makeicon SOURCE.png DEST.ico [PREVIEW.png [SCALE]]');

  LImage := TFPMemoryImage.Create(0, 0);
  try
    LImage.LoadFromFile(ParamStr(1));
    ConvertImage(LImage, LIcon);
  finally
    LImage.Free;
  end;

  LError := SaveIcon(ParamStr(2), LIcon);
  if LError <> ieNone then
    Fail(IconErrorText(LError));

  if ParamCount >= 3 then
  begin
    LScale := StrToIntDef(ParamStr(4), 3);
    if LScale < 1 then
      Fail('Invalid scale');
    SavePreview(ParamStr(3), LIcon, LScale);
  end;
end.
