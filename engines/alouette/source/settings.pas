
unit Settings;

interface

procedure LoadSettings(
  out AUseBook: boolean;
  out
  APawnMove,
  APawnStruct,
  ATargets,
  ACastling,
  AEnPassant,
  ACheck,
  AProtect,
  AAttack,
  AMobility,
  ANewPos: integer
);
procedure SaveSettings(
  const AUseBook: boolean;
  const
  APawnMove,
  APawnStruct,
  ATargets,
  ACastling,
  AEnPassant,
  ACheck,
  AProtect,
  AAttack,
  AMobility,
  ANewPos: integer
);
function SettingsFileExists: boolean;

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
  APawnMove,
  APawnStruct,
  ATargets,
  ACastling,
  AEnPassant,
  ACheck,
  AProtect,
  AAttack,
  AMobility,
  ANewPos: integer
);
begin
  with TIniFile.Create(LIniPath) do
  try
    AUseBook := boolean(ReadInteger(CMain, 'usebook',    1));
    APawnMove        := ReadInteger(CFact, 'pawnmove',   1);
    APawnStruct      := ReadInteger(CFact, 'pawnstruct', 1);
    ATargets         := ReadInteger(CFact, 'targets',    1);
    ACastling        := ReadInteger(CFact, 'castling',   1);
    AEnPassant       := ReadInteger(CFact, 'enpassant',  1);
    ACheck           := ReadInteger(CFact, 'check',      1);
    AProtect         := ReadInteger(CFact, 'protect',    1);
    AAttack          := ReadInteger(CFact, 'attack',     1);
    AMobility        := ReadInteger(CFact, 'mobility',   1);
    ANewPos          := ReadInteger(CFact, 'newpos',     1);
  finally
    Free;
  end;
end;

procedure SaveSettings(
  const AUseBook: boolean;
  const
  APawnMove,
  APawnStruct,
  ATargets,
  ACastling,
  AEnPassant,
  ACheck,
  AProtect,
  AAttack,
  AMobility,
  ANewPos: integer
);
begin
  with TIniFile.Create(LIniPath) do
  try
    WriteInteger(CMain, 'usebook',    Ord(AUseBook));
    WriteInteger(CFact, 'pawnmove',   APawnMove);
    WriteInteger(CFact, 'pawnstruct', APawnStruct);
    WriteInteger(CFact, 'targets',    ATargets);
    WriteInteger(CFact, 'castling',   ACastling);
    WriteInteger(CFact, 'enpassant',  AEnPassant);
    WriteInteger(CFact, 'check',      ACheck);
    WriteInteger(CFact, 'protect',    AProtect);
    WriteInteger(CFact, 'attack',     AAttack);
    WriteInteger(CFact, 'mobility',   AMobility);
    WriteInteger(CFact, 'newpos',     ANewPos);
    UpdateFile;
  finally
    Free;
  end;
end;

function SettingsFileExists: boolean;
begin
  result := FileExists(LIniPath);
end;

begin
  LIniPath := ChangeFileExt(ParamStr(0), '.cfg');
end.
