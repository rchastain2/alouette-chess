
unit Settings;

interface

procedure LoadSettings(
  out AUseBook: boolean;
  out
  AProtectedPawns,
  AMobility,
  ACastling,
  AEnPassant,
  ACheck,
  ANewPos: integer
);
procedure SaveSettings(
  const AUseBook: boolean;
  const
  AProtectedPawns,
  AMobility,
  ACastling,
  AEnPassant,
  ACheck,
  ANewPos: integer
);
function SettingsFileExists: boolean;
procedure SetSettingsFile(const AFileName: string);

implementation

uses
  SysUtils, IniFiles;

const
  CMain = 'main';
  CFact = 'factors';
  
var
  LIniPath: string;

procedure LoadSettings(
  out AUseBook: boolean;
  out
  AProtectedPawns,
  AMobility,
  ACastling,
  AEnPassant,
  ACheck,
  ANewPos: integer
);
begin
  with TIniFile.Create(LIniPath) do
  try
    AUseBook := boolean(ReadInteger(CMain, 'usebook',        1));
    AProtectedPawns  := ReadInteger(CFact, 'protectedpawns', 2);
    AMobility        := ReadInteger(CFact, 'mobility',       1);
    ACastling        := ReadInteger(CFact, 'castling',       5);
    AEnPassant       := ReadInteger(CFact, 'enpassant',      0);
    ACheck           := ReadInteger(CFact, 'check',          1);
    ANewPos          := ReadInteger(CFact, 'newpos',         10);
  finally
    Free;
  end;
end;

procedure SaveSettings(
  const AUseBook: boolean;
  const
  AProtectedPawns,
  AMobility,
  ACastling,
  AEnPassant,
  ACheck,
  ANewPos: integer
);
begin
  with TIniFile.Create(LIniPath) do
  try
    WriteInteger(CMain, 'usebook',        Ord(AUseBook));
    WriteInteger(CFact, 'protectedpawns', AProtectedPawns);
    WriteInteger(CFact, 'mobility',       AMobility);
    WriteInteger(CFact, 'castling',       ACastling);
    WriteInteger(CFact, 'enpassant',      AEnPassant);
    WriteInteger(CFact, 'check',          ACheck);
    WriteInteger(CFact, 'newpos',         ANewPos);
    UpdateFile;
  finally
    Free;
  end;
end;

function SettingsFileExists: boolean;
begin
  result := FileExists(LIniPath);
end;

procedure SetSettingsFile(const AFileName: string);
begin
  LIniPath := AFileName;
end;

begin
  LIniPath := ChangeFileExt(ParamStr(0), '.cfg');
end.
