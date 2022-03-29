unit Unit1;

interface

uses
  System.SysUtils,
  System.IOUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.Diagnostics, System.TimeSpan,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, System.Rtti,
  FMX.Grid.Style, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Grid,
  FMX.StdCtrls, FMX.Memo.Types, FMX.Memo,
  HlpHashLibTypes,
  HlpHash,
  HlpIHashResult,
  {CRC32}
  HlpCRC32Fast,
  {MD5}
  HlpMD5,
  {SHA1}
  HlpSHA1,
  {XXH32}
  HlpXXHash32,
  FMX.ListBox, FMX.ExtCtrls, FMX.Layouts;

type
  GridColumn = (Name, Hash);

type
  TForm1 = class(TForm)
    Grid1: TGrid;
    StringColumn1: TStringColumn;
    StringColumn2: TStringColumn;
    Button1: TButton;
    Label1: TLabel;
    Button2: TButton;
    Label3: TLabel;
    ProgressBar1: TProgressBar;
    Label4: TLabel;
    ProgressBar2: TProgressBar;
    Label7: TLabel;
    ComboBox2: TComboBox;
    SaveDialog1: TSaveDialog;
    Layout1: TLayout;
    Label2: TLabel;
    procedure Grid1GetValue(Sender: TObject; const ACol, ARow: Integer;
      var Value: TValue);
    procedure Grid1SetValue(Sender: TObject; const ACol, ARow: Integer;
      const Value: TValue);
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button2Click(Sender: TObject);
    function GetFileHash(FromName: STRING; VAR error: WORD): String;
  private
    { Private declarations }
  public
    { Public declarations }
    Data: Array of Array of TValue;
    ColPos: Array Of Integer;
  end;

var
  Form1: TForm1;
  TempDirPath, HashExt: String;
  TLCount: Integer;
  pMB, nMB: Int64;
  ErExit: WORD;
  GetElapsedTime: TStopWatch;

implementation

{$R *.fmx}

function FileSize(fileName: wideString): Int64;
var
  sr: TSearchRec;
begin
  if FindFirst(fileName, faAnyFile, sr) = 0 then
    result := Int64(sr.FindData.nFileSizeHigh) shl Int64(32) +
      Int64(sr.FindData.nFileSizeLow)
  else
    result := -1;
  FindClose(sr);
end;

function GetCount(Dir: string): Integer;
var
  I: Integer;
begin
  I := 0;
  for Dir in TDirectory.GetFiles(Dir, '*', TSearchOption.soAllDirectories) do
    I := I + 1;
  result := I;
end;

function msToHourMinSec(AMilliseconds: Int64): String;
var
  t: Double;
begin
  t := AMilliseconds / MSecsPerDay;
  if t < 1 then
    result := FormatDateTime('h:nn:ss.zzz', t)
  else
    result := IntToStr(trunc(t)) + ' days ' + FormatDateTime('h:nn:ss.zzz', t);
end;

function TForm1.GetFileHash(FromName: STRING; VAR error: WORD): String;
var
  BytesRead, BufferSize: Integer;
  FromFile: System.file;
  TotalBytes: Int64;
  { CRC32 }
  ICHKSUM1: TCRC32_PKZIP;
  { MD5 }
  ICHKSUM2: TMD5;
  { SHA1 }
  ICHKSUM3: TSHA1;
  { XXH32 }
  ICHKSUM4: TXXHASH32;
  LData: THashLibByteArray;
begin
  BufferSize := (64 * 1024);
  try
    System.ASSIGN(FromFile, FromName);
{$I-}
    Reset(FromFile, 1);
{$I+}
    error := IOResult;
    case Form1.ComboBox2.ItemIndex of
      0:
        begin
          ICHKSUM1 := TCRC32_PKZIP.Create;
          ICHKSUM1.Initialize;
        end;
      1:
        begin
          ICHKSUM2 := TMD5.Create;
          ICHKSUM2.Initialize;
        end;
      2:
        begin
          ICHKSUM3 := TSHA1.Create;
          ICHKSUM3.Initialize;
        end;
      3:
        begin
          ICHKSUM4 := TXXHASH32.Create;
          ICHKSUM4.Initialize;
        end;
    end;
    if error = 0 then
    begin
      TotalBytes := 0;
      System.SetLength(LData, BufferSize);
      repeat
{$I-}
        BlockRead(FromFile, LData[0], BufferSize, BytesRead);
{$I+}
        error := IOResult;
        if (error = 0) AND (BytesRead > 0) then
        begin
          case Form1.ComboBox2.ItemIndex of
            0:
              begin
                ICHKSUM1.TransformBytes(LData, 0, BytesRead);
              end;
            1:
              begin
                ICHKSUM2.TransformBytes(LData, 0, BytesRead);
              end;
            2:
              begin
                ICHKSUM3.TransformBytes(LData, 0, BytesRead);
              end;
            3:
              begin
                ICHKSUM4.TransformBytes(LData, 0, BytesRead);
              end;
          end;
          pMB := TotalBytes div (1024 * 1024);
          Form1.ProgressBar1.Value := pMB;
          pMB := TotalBytes;
          TotalBytes := TotalBytes + BytesRead;
          Application.ProcessMessages;
        end
        until (BytesRead = 0) OR (error > 0);
        System.CLOSE(FromFile)
      end;
    finally
      case Form1.ComboBox2.ItemIndex of
        0:
          begin
            result := ICHKSUM1.TransformFinal.ToString();
          end;
        1:
          begin
            result := ICHKSUM2.TransformFinal.ToString();
          end;
        2:
          begin
            result := ICHKSUM3.TransformFinal.ToString();
          end;
        3:
          begin
            result := ICHKSUM4.TransformFinal.ToString();
          end;
      end;
    end;
  end;

  procedure TForm1.Button1Click(Sender: TObject);
  var
    LnCount: Integer;
    S: String;
    GetR: TStringDynArray;
  begin
    if SelectDirectory('Select Directory', GetCurrentDir, S) then
    begin
      if TDirectory.IsEmpty(S) then
      begin
        ShowMessage('Selected "' + ExtractFileName(S) + '" is Empty');
      end
      else
      begin
        ErExit := 0;
        case Form1.ComboBox2.ItemIndex of
          0:
            begin
              HashExt := '.sfv';
            end;
          1:
            begin
              HashExt := '.md5';
            end;
          2:
            begin
              HashExt := '.sh1';
            end;
          3:
            begin
              HashExt := '.xxh';
            end;
        end;
        Button1.Enabled := false;
        Button2.Enabled := false;
        LnCount := GetCount(S);
        Grid1.RowCount := LnCount;
        SetLength(Data, Grid1.Content.ChildrenCount, Grid1.RowCount);
        SetLength(ColPos, Grid1.Content.ChildrenCount);
        GetR := TDirectory.GetFiles(S, '*.*', TSearchOption.soAllDirectories);
        Label1.Text := 'File Processed : ' + '0 \ ' + IntToStr(LnCount);
        ProgressBar2.Max := LnCount;
        ComboBox2.Enabled := false;
        TempDirPath := IncludeTrailingPathDelimiter(S);
        try
          TLCount := 0;
          GetElapsedTime := TStopWatch.Create;
          GetElapsedTime.Start;
          for S in GetR do
          begin
            if ErExit = 1 then
              Break;
            nMB := FileSize(S) div (1024 * 1024);
            ProgressBar1.Max := nMB;
            Grid1.BeginUpdate;
            Data[Ord(GridColumn.Name), TLCount] := TValue.From<String>(S);
            Grid1.EndUpdate;
            Application.ProcessMessages;
            Grid1.BeginUpdate;
            Data[Ord(GridColumn.Hash), TLCount] :=
              TValue.From<String>(GetFileHash(S, ErExit));
            Grid1.EndUpdate;
            TLCount := TLCount + 1;
            Label1.Text := 'File Processed : ' + IntToStr(TLCount) + ' \ ' +
              IntToStr(LnCount);
            ProgressBar2.Value := TLCount;
            Application.ProcessMessages;
          end;
        finally
          GetElapsedTime.Stop;
          Label2.Text :=
            ('Elapsed time : ' + msToHourMinSec
            (GetElapsedTime.ElapsedMilliseconds));
          if ErExit = 0 then
          begin
            ProgressBar1.Max := 100;
            ProgressBar1.Value := 100;
          end;
        end;
        Button1.Enabled := true;
        Button2.Enabled := true;
        ComboBox2.Enabled := true;
        Button1.ResetFocus;
        Button2.SetFocus;
      end;
    end;
  end;

  procedure TForm1.Button2Click(Sender: TObject);
  var
    Row1, Row2: TValue;
    I, StrLnCount: Integer;
    StrFile: TStringList;
  begin
    SaveDialog1.Title := 'Save your HashDB file';
    SaveDialog1.InitialDir := GetCurrentDir;

    { case Form1.ComboBox2.ItemIndex of
      0:
      begin
      HashExt := '*.sfv';
      end;
      1:
      begin
      HashExt := '*.md5';
      end;
      2:
      begin
      HashExt := '*.sh1';
      end;
      3:
      begin
      HashExt := '*.xxh';
      end;
      end; }

    SaveDialog1.Filter := ComboBox2.Items[ComboBox2.ItemIndex] + ' | ' +
      LowerCase(HashExt);
    SaveDialog1.DefaultExt := LowerCase(HashExt);
    SaveDialog1.FilterIndex := 0;
    if SaveDialog1.Execute then
    begin
      StrFile := TStringList.Create;
      for I := 0 to (Grid1.RowCount - 1) do
      begin
        Row1 := Data[0, I];
        Row2 := Data[1, I];
        StrFile.Add(StringColumn2.ValueToString(Row2) + ' *' +
          StringColumn1.ValueToString(Row1))
      end;
      for StrLnCount := 0 to StrFile.Count - 1 do
      begin
        StrFile[StrLnCount] := StringReplace(StrFile[StrLnCount], TempDirPath,
          '', [rfReplaceAll]);
      end;
      StrFile.SaveToFile(SaveDialog1.fileName);
    end;
  end;

  procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
  begin
    ErExit := 1;
  end;

  procedure TForm1.Grid1GetValue(Sender: TObject; const ACol, ARow: Integer;
    var Value: TValue);
  begin
    Value := Data[ACol, ARow];
  end;

  procedure TForm1.Grid1SetValue(Sender: TObject; const ACol, ARow: Integer;
    const Value: TValue);
  begin
    Data[ACol, ARow] := Value;
  end;

end.
