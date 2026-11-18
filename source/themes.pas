unit Themes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SDL3;

type
  TThemeKind = (tkImage, tkDrawn, tkSheet);

  TColorId = (
    ciClear, ciLastFrom, ciLastTo, ciCheck, ciSelected, ciDot, ciTargetOuter, ciTargetInner,
    ciPanel, ciPanelBorder, ciTitle, ciStatus, ciSecond, ciSeparator, ciList, ciHelp,
    ciOverlay, ciPopup, ciPopupFrame, ciPopupInnerFrame, ciPopupCell, ciPopupHover,
    ciFrame, ciLight, ciDark, ciCoord
  );

  TSheet = record
    Board: integer;
    White: integer;
    Black: integer;
  end;

  TTheme = record
    Name: string;
    Title: string;
    Kind: TThemeKind;
    Square: integer;
    Margin: integer;
    Sheet: TSheet;
    Colors: array[TColorId] of cardinal;
  end;

const
  CThemes: array[0..11] of TTheme = (
    (
      Name: 'bftc'; Title: 'BFTC'; Kind: tkDrawn; Square: 40; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $101610FF, $FFDC3C5A, $FFDC3C78, $E6282882, $5AAAFF6E, $1E5A28B4, $1E6E28E6, $1E6E28A0,
        $202E22FF, $466040FF, $EEEED2FF, $E8ECE0FF, $FF7864FF, $466040FF, $CDD7BEFF, $8CA07DFF,
        $0000006E, $202E22F0, $EEEED2FF, $00000000, $769656FF, $EEEED2FF,
        $F2F2E6FF, $EEEED2FF, $769656FF, $2F3B24FF
      )
    ),
    (
      Name: 'deepbasic'; Title: 'Deep Basic'; Kind: tkDrawn; Square: 40; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $101610FF, $FFDC3C5A, $FFDC3C78, $E6282882, $5AAAFF6E, $1E5A28B4, $1E6E28E6, $1E6E28A0,
        $202E22FF, $466040FF, $EEEED2FF, $E8ECE0FF, $FF7864FF, $466040FF, $CDD7BEFF, $8CA07DFF,
        $0000006E, $202E22F0, $EEEED2FF, $00000000, $769656FF, $EEEED2FF,
        $F2F2E6FF, $EEEED2FF, $769656FF, $2F3B24FF
      )
    ),
    (
      Name: 'fritz'; Title: 'Fritz'; Kind: tkImage; Square: 40; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $141414FF, $FFD23C50, $FFD23C6E, $E6282882, $5AAAFF6E, $28A03CAA, $28C83CDC, $28C83CA0,
        $242428FF, $505058FF, $F0F0F0FF, $E6E6E6FF, $FF7864FF, $505058FF, $D2D2D2FF, $8C8C96FF,
        $0000006E, $242428F0, $F0F0F0FF, $00000000, $C8C8C8FF, $FFFFFFFF,
        $3C3C3CFF, $00000000, $00000000, $DCDCDCFF
      )
    ),
    (
      Name: 'lanea'; Title: 'Lanea'; Kind: tkImage; Square: 32; Margin: 32;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $14100EFF, $FFD23C50, $FFD23C6E, $E6282882, $5AAAFF6E, $28A03CAA, $28C83CDC, $28C83CA0,
        $2E241EFF, $5A483AFF, $EBC878FF, $E6E6DCFF, $FF7864FF, $5A483AFF, $D2C8B4FF, $968C78FF,
        $0000006E, $2E241EF0, $EBC878FF, $00000000, $00000000, $EBC8785A,
        $00000000, $00000000, $00000000, $00000000
      )
    ),
    (
      Name: 'lucas'; Title: 'Lucas312'; Kind: tkImage; Square: 32; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $121418FF, $FFD23C50, $FFD23C6E, $E6282882, $5AAAFF6E, $28A03CAA, $28C83CDC, $28C83CA0,
        $22262EFF, $4A5262FF, $C8D7EBFF, $E4E8EEFF, $FF7864FF, $4A5262FF, $C8CED8FF, $8890A0FF,
        $0000006E, $22262EF0, $C8D7EBFF, $00000000, $808080FF, $C8D7EBFF,
        $464A52FF, $00000000, $00000000, $D8DCE0FF
      )
    ),
    (
      Name: 'm484'; Title: 'Master484'; Kind: tkSheet; Square: 28; Margin: 12;
      Sheet: (Board: 255; White: 0; Black: 13);
      Colors: (
        $281A14FF, $FFDC5A5A, $FFDC5A78, $E6282882, $5AAAFF6E, $3C8C46BE, $3CA046E6, $3CA046A0,
        $4A2E24FF, $4A2E24FF, $EAC9AEFF, $F0E1D2FF, $FF826EFF, $8C5845FF, $D6BEAAFF, $BE9682FF,
        $00000064, $8C5845F5, $674032FF, $D69282FF, $D69282FF, $EAC9AEFF,
        $00000000, $00000000, $00000000, $00000000
      )
    ),
    (
      Name: 'm484-classic'; Title: 'Master484 Classic'; Kind: tkSheet; Square: 28; Margin: 12;
      Sheet: (Board: 0; White: 0; Black: 4);
      Colors: (
        $221810FF, $FFDC5A5A, $FFDC5A78, $E6282882, $5AAAFF6E, $3C8C46BE, $3CA046E6, $3CA046A0,
        $3E2A1CFF, $3E2A1CFF, $CCBB88FF, $EEE6CCFF, $FF826EFF, $7A5236FF, $D2C8A0FF, $B4A07AFF,
        $00000064, $7A5236F5, $573A26FF, $BE8C64FF, $BE8C64FF, $CCBB88FF,
        $00000000, $00000000, $00000000, $00000000
      )
    ),
    (
      Name: 'm484-gold'; Title: 'Master484 Gold'; Kind: tkSheet; Square: 28; Margin: 12;
      Sheet: (Board: 0; White: 5; Black: 4);
      Colors: (
        $221810FF, $FFDC5A5A, $FFDC5A78, $E6282882, $5AAAFF6E, $3C8C46BE, $3CA046E6, $3CA046A0,
        $3E2A1CFF, $3E2A1CFF, $CCBB88FF, $EEE6CCFF, $FF826EFF, $7A5236FF, $D2C8A0FF, $B4A07AFF,
        $00000064, $7A5236F5, $573A26FF, $BE8C64FF, $BE8C64FF, $CCBB88FF,
        $00000000, $00000000, $00000000, $00000000
      )
    ),
    (
      Name: 'm484-slate'; Title: 'Master484 Slate'; Kind: tkSheet; Square: 28; Margin: 12;
      Sheet: (Board: 0; White: 0; Black: 11);
      Colors: (
        $221810FF, $FFDC5A5A, $FFDC5A78, $E6282882, $5AAAFF6E, $3C8C46BE, $3CA046E6, $3CA046A0,
        $3E2A1CFF, $3E2A1CFF, $CCBB88FF, $EEE6CCFF, $FF826EFF, $7A5236FF, $D2C8A0FF, $B4A07AFF,
        $00000064, $7A5236F5, $573A26FF, $BE8C64FF, $BE8C64FF, $CCBB88FF,
        $00000000, $00000000, $00000000, $00000000
      )
    ),
    (
      Name: 'owl'; Title: 'OWL'; Kind: tkDrawn; Square: 40; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $141820FF, $FFDC3C5A, $FFDC3C78, $E6282882, $5AAAFF6E, $283246B4, $283246E6, $283246A0,
        $2A2F3AFF, $4A5468FF, $D8DCE4FF, $E4E8EEFF, $FF7864FF, $4A5468FF, $C8CED8FF, $8890A0FF,
        $0000006E, $2A2F3AF0, $D8DCE4FF, $00000000, $8C96A8FF, $D8DCE4FF,
        $3C4250FF, $D8DCE4FF, $8C96A8FF, $D8DCE4FF
      )
    ),
    (
      Name: 'smirf'; Title: 'Smirf'; Kind: tkDrawn; Square: 36; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $14100EFF, $FFD23C50, $FFD23C6E, $E6282882, $5AAAFF6E, $28A03CAA, $28C83CDC, $28C83CA0,
        $3E2C22FF, $6E523EFF, $F0D9B5FF, $EFE3CCFF, $FF7864FF, $6E523EFF, $DCC8AFFF, $AA9178FF,
        $0000006E, $3E2C22F0, $F0D9B5FF, $00000000, $B58863FF, $F0D9B5FF,
        $EFE3CCFF, $F0D9B5FF, $B58863FF, $5C4033FF
      )
    ),
    (
      Name: 'warlord'; Title: 'Warlord'; Kind: tkImage; Square: 48; Margin: 16;
      Sheet: (Board: 0; White: 0; Black: 0);
      Colors: (
        $160E0EFF, $FFD23C50, $FFD23C6E, $E6282882, $5AAAFF6E, $28A03CAA, $28C83CDC, $28C83CA0,
        $2E1C1CFF, $6A3C3CFF, $EBBE96FF, $EEE4E0FF, $FF7864FF, $6A3C3CFF, $DCC8C0FF, $A08880FF,
        $0000006E, $2E1C1CF0, $EBBE96FF, $00000000, $808080FF, $EBBE96FF,
        $503834FF, $00000000, $00000000, $E8D8D0FF
      )
    )
  );

function FindTheme(const AName: string; out ATheme: TTheme): boolean;
function ThemeNames: string;
function ToColor(const AValue: cardinal): TSDL_Color;

implementation

function FindTheme(const AName: string; out ATheme: TTheme): boolean;
var
  i: integer;
begin
  for i := Low(CThemes) to High(CThemes) do
    if SameText(CThemes[i].Name, AName) then
    begin
      ATheme := CThemes[i];
      exit(TRUE);
    end;
  result := FALSE;
end;

function ThemeNames: string;
var
  i: integer;
begin
  result := '';
  for i := Low(CThemes) to High(CThemes) do
  begin
    if i > Low(CThemes) then
      result := result + ', ';
    result := result + CThemes[i].Name;
  end;
end;

function ToColor(const AValue: cardinal): TSDL_Color;
begin
  result.r := (AValue shr 24) and $FF;
  result.g := (AValue shr 16) and $FF;
  result.b := (AValue shr 8) and $FF;
  result.a := AValue and $FF;
end;

end.
