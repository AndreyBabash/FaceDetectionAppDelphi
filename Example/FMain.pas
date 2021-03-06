unit FMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.ExtCtrls,
  FMX.Controls.Presentation,
  {$IFDEF ANDROID}
  	AndroidApi.Helpers, FMX.Platform.Android, Androidapi.JNI.Widget, FMX.Helpers.Android,
    Androidapi.JNI.Os,
 	{$ENDIF}
  System.Threading, System.Permissions,
  Grijjy.FaceDetection, FMX.Media, FMX.Layouts, FMX.Ani;

type TQuality=(HIGH,MEDIUM,LOW);

type
  TFormMain = class(TForm)
    CameraComponent1: TCameraComponent;
    Button1: TButton;
    Button2: TButton;
    Image1: TImage;
    ToolBar1: TToolBar;
    Label1: TLabel;
    Button3: TButton;
    Layout1: TLayout;
    Rectangle1: TRectangle;
    Label2: TLabel;
    CheckBox1: TCheckBox;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    Button4: TButton;
    CheckBox2: TCheckBox;
    Layout2: TLayout;
    FloatAnimation1: TFloatAnimation;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure CameraComponent1SampleBufferReady(Sender: TObject;
      const ATime: TMediaTime);
    procedure FormCreate(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure RadioButton1Change(Sender: TObject);
    procedure RadioButton2Change(Sender: TObject);
    procedure RadioButton3Change(Sender: TObject);
  private
    { Private declarations }
    FFaceDetector: IgoFaceDetector;
    FFaces: TArray<TgoFace>;
    FBitmap: TBitmap;
    process:boolean;
    task:ITask;
    cameraquality:TQuality;
    FPermissionCamera: string;
    procedure FacePaint;
  private
    procedure ProcessImage;
  public
    { Public declarations }
    destructor Destroy; override;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

{ TFormMain }
// ?????????? ??????
procedure TFormMain.Button1Click(Sender: TObject);
begin
  CameraComponent1.Active := false;
end;

// ?????? ??????
procedure TFormMain.Button2Click(Sender: TObject);
begin
{??????????? ?????????? ?? ????????????? ?????? ?? ????? ?????? ?????????}
{$IFDEF ANDROID}
    FPermissionCamera:=JStringToString(TJManifest_permission.JavaClass.CAMERA);
    PermissionsService.RequestPermissions([FPermissionCamera],
    procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
    var i:integer;
    begin
       for i:=0 to Length(AGrantResults) do
       begin
          if AGrantResults[i] = TPermissionStatus.Granted then
          begin
            case i of
            0:
              begin
                  CameraComponent1.Active := false;
                  // ???????? ??????????? ??? ?????? ?????? ??????????
                  if not CheckBox1.IsChecked then
                  begin
                    CameraComponent1.Kind := FMX.Media.TCameraKind.BackCamera;
                  end
                  else
                  begin
                    CameraComponent1.Kind := FMX.Media.TCameraKind.FrontCamera;
                  end;
                  // ??????????? ???????? ??????????? ? ??????
                  case cameraquality of
                    TQuality.HIGH: CameraComponent1.Quality := FMX.Media.TVideoCaptureQuality.HighQuality;
                    TQuality.MEDIUM: CameraComponent1.Quality := FMX.Media.TVideoCaptureQuality.MediumQuality;
                    TQuality.LOW: CameraComponent1.Quality := FMX.Media.TVideoCaptureQuality.LowQuality;
                  end;
                  // ????? ?????????? ??????
                  if CheckBox2.IsChecked then
                  begin
                    CameraComponent1.FocusMode := FMX.Media.TFocusMode.ContinuousAutoFocus;
                  end;
                  // ???????????? ????????? ?????? ? ????????? ??????
                  CameraComponent1.Active := True;
              end;
            end;
          end
          Else
          begin
            case i of
            0:
                {$IFDEF ANDROID}
                    // ? ?????? ?????? ?????????? ??????? ????
                    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('????????????? ?????? ?????????!'), TJToast.JavaClass.LENGTH_LONG).show;
                {$ENDIF}
            end;
          end;
       end;
  end)
{$ENDIF}
end;

procedure TFormMain.Button3Click(Sender: TObject);
begin
// ??????????? ????????? ??????????
  Layout1.Opacity:=0.0;
  Layout1.Visible:=not Layout1.Visible;
  FloatAnimation1.Start;
end;

procedure TFormMain.Button4Click(Sender: TObject);
begin
  Layout1.Visible:=not Layout1.Visible;
end;

procedure TFormMain.CameraComponent1SampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
  TThread.Synchronize(TThread.CurrentThread,
  procedure
  begin
    ProcessImage;
  end);
end;

procedure TFormMain.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.IsChecked then CheckBox1.Text:='Front Camera'
  else CheckBox1.Text:='Back Camera';
end;

destructor TFormMain.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  { Create bitmap and face detector if needed. }
  cameraquality:=TQuality.LOW;
  CameraComponent1.Kind := FMX.Media.TCameraKind.FrontCamera;
  if (FBitmap = nil) then
  FBitmap := TBitmap.Create;
  process:=false;
end;


procedure TFormMain.FacePaint;
  var
  SrcRect, DstRect, Rect: TRectF;
  Scale, DstWidth, DstHeight: Single;
  Face: TgoFace;

  procedure PaintEye(const APosition: TPointF; const AColor: TAlphaColor);
  var
    P: TPointF;
    R: TRectF;
    Radius: Single;
  begin
    { Exit if eye position is not available }
    if (APosition.X = 0) and (APosition.Y = 0) then
      Exit;

    P.X := APosition.X * Scale;
    P.Y := APosition.Y * Scale;
    P.Offset(DstRect.TopLeft);

    Radius := Face.EyesDistance * Scale * 0.2;
    R := RectF(P.X - Radius, P.Y - Radius, P.X + Radius, P.Y + Radius);

    TThread.Synchronize(nil, procedure
    begin
    with Image1 do
      begin
      Canvas.BeginScene();
      Canvas.Stroke.Color := AColor;
      Canvas.Stroke.Thickness:=7;
      Canvas.DrawEllipse(R, 1);
      Canvas.EndScene;
      exit;
      end;
    end);
  end;

begin

  { Paint bitmap to fit the paint box while preserving aspect ratio. }
  SrcRect := RectF(0, 0, FBitmap.Width, FBitmap.Height);
  Scale := Min(Image1.Width / FBitmap.Width, Image1.Height / FBitmap.Height);
  DstWidth := Round(FBitmap.Width * Scale);
  DstHeight := Round(FBitmap.Height * Scale);
  DstRect.Left := Floor(0.5 * (Image1.Width - DstWidth));
  DstRect.Top := Floor(0.5 * (Image1.Height - DstHeight));
  DstRect.Width := DstWidth;
  DstRect.Height := DstHeight;

  TThread.Synchronize(nil,
  procedure
  begin
    with Image1 do
    begin
      Canvas.BeginScene();
      Canvas.DrawBitmap(FBitmap, SrcRect, RectF(0, 0, Image1.Width, Image1.Height), 1);
      Canvas.EndScene;
      exit;
    end;
  end);

  { Paint each face with its features }
  for Face in FFaces do
  begin
    { Paint bounds around entire face }
    Rect := Face.Bounds;
    Rect.Left := Floor(Rect.Left * Scale);
    Rect.Top := Floor(Rect.Top * Scale);
    Rect.Right := Ceil(Rect.Right * Scale);
    Rect.Bottom := Ceil(Rect.Bottom * Scale);
    Rect.Offset(DstRect.TopLeft);

    TThread.Synchronize(nil, procedure
    begin
      with Image1 do
      begin
        Canvas.BeginScene();
        Canvas.Stroke.Color := TAlphaColors.Lime;
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Thickness :=7;
        Canvas.DrawRect(Rect, 4, 4, AllCorners, 1);
        Canvas.EndScene;
        exit;
      end;
    end);



    { Paint the eyes }
    PaintEye(Face.LeftEyePosition, TAlphaColors.Greenyellow);
    PaintEye(Face.RightEyePosition, TAlphaColors.Greenyellow);

  end;

  FBitmap:=nil;
  process:=false;

end;


procedure TFormMain.ProcessImage;
begin

  if process then
  exit;


  { Create bitmap and face detector if needed. }
  if (FBitmap = nil) then
  FBitmap := TBitmap.Create;

   TThread.Synchronize(nil, procedure
    begin
      CameraComponent1.SampleBufferToBitmap(FBitmap,True);
    end);

  process:=true;

  if (FFaceDetector = nil) then
    { Create a face detector using high accuracy and a maximum detection of
      10 faces. }
    FFaceDetector := TgoFaceDetector.Create(TgoFaceDetectionAccuracy.High, 10);

  { Detect faces in bitmap }
  FFaces := FFaceDetector.DetectFaces(FBitmap);
  {Task for drawing on faces}
  task:=TTask.Create(procedure
  begin
    FacePaint;
  end);

  task.Start;

end;

// ????? ??????? ???????? ??????????? ? ??????
procedure TFormMain.RadioButton1Change(Sender: TObject);
begin
  cameraquality:=TQuality.HIGH;
end;

procedure TFormMain.RadioButton2Change(Sender: TObject);
begin
  cameraquality:=TQuality.MEDIUM;
end;

procedure TFormMain.RadioButton3Change(Sender: TObject);
begin
  cameraquality:=TQuality.LOW;
end;

end.
