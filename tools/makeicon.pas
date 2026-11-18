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

procedure ConvertImage(AImage: TFPCustomImage; out AIcon: TWin3Icon);
var
  x, y, LLeft, LTop, LRight, LBottom, LOffsetX, LOffsetY: integer;
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
