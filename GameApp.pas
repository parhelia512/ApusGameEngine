// Engine3 Game launcher class
// Copyright (C) 2017 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)

unit GameApp;
interface
 uses
  {$IFDEF ANDROID}jni,{$ENDIF}
  EngineCls;
  
 var
   // Global settings
   gameTitle:string='Engine3 Game Template';
   usedAPI:TGraphicsAPI=gaOpenGL;
   useSystemCursor:boolean=true;
   windowedMode:boolean=true;
   windowWidth:integer=1024;
   windowHeight:integer=768;
   deviceDPI:integer=96; // mobile only
   noVSync:boolean=false;
   checkForSteam:boolean=false; // Check if STEAM client is running and get AppID
   configDir:string;
   instanceID:integer=0;
   langCode:string='en';
   debugMode:boolean=false;

 type
  TGameApplication=class
   constructor Create;
   destructor Destroy; override;
   procedure Run; virtual;
   procedure LoadOptions; virtual;   // Load configuration
   procedure SaveOptions; virtual;
   procedure HandleParam(param:string); virtual;    // Handle each command line option
   procedure SetupScreen; virtual; // Setup window size and output options
   // Initialization routines: override with actual functionality
   procedure LoadFonts; virtual;   // Load font files (called once)
   procedure SelectFonts; virtual;  // Select font constants (may be called many times)
   procedure InitStyles; virtual; // Which styles to add?
   procedure CreateScenes; virtual; // Create and add game scenes
   procedure InitCursors; virtual; 
  end;
  TGameApplicationClass=class of TGameApplication;

 var
  myGameAppClass:TGameApplicationClass;
  myGameApp:TGameApplication; // Store game launcher object here!
  initGame:procedure;

 {$IFDEF ANDROID}
  // Binding functions (to be exported)
  procedure AppSurfaceChanged(env:PJNIEnv;this:jobject; width, height:jint);
  procedure AppInit(env:PJNIEnv;this:jobject; view:jobject; width,height,dpi:jint; assetManager:jobject; sdkVer:jint);
  procedure AppDrawFrame(env:PJNIEnv;this:jobject);
  procedure AppPause(env:PJNIEnv;this:jobject);
  procedure AppResume(env:PJNIEnv;this:jobject);
  function AppInput(env:PJNIEnv;this:jobject; action,i1,i2:jint; text:jstring):jstring;
  procedure AppTouch(env:PJNIEnv;this:jobject; x,y:jfloat; action:jint);
  procedure AppKey(env:PJNIEnv;this:jobject; keyCode,UChar:jint; event: jobject);
 {$ENDIF}

implementation
 uses
  {$IFDEF MSWINDOWS}windows,{$ENDIF}
  {$IFDEF ANDROID}android,androidGame,{$ENDIF}
   SysUtils,MyServis,ControlFiles2,UDict,FastGFX,eventMan,
   UIClasses,BasicGame,EngineTools,ConScene,TweakScene,customstyle,BitmapStyle
  {$IFDEF DIRECTX},DXgame8{$ENDIF}
  {$IFDEF OPENGL},GLgame{$ENDIF}
  {$IFDEF STEAM},SteamAPI{$ENDIF};

type
 TLoadingScene=class(TGameScene)
  v:TAnimatedValue;
  tex:TTextureImage;
  constructor Create; 
  procedure Render; override;
 end;

{$IFDEF ANDROID}
{Android bindings}
var
  initialized:boolean;

procedure AppSurfaceChanged(env:PJNIEnv;this:jobject; width, height:jint);
 begin
  windowWidth:=width;
  windowHeight:=height;
  // Resize window
 end;

procedure AppInit(env:PJNIEnv;this:jobject; view:jobject; width,height,dpi:jint; assetManager:jobject; sdkVer:jint);
 begin
  if initialized then exit;
  try
   LogI(Format('AppInit: %d %d %d',[width,height,dpi]));
   InitAndroid(env,this,view);

   windowWidth:=width;
   windowHeight:=height;
   deviceDPI:=dpi;
   Signal('Engine\InitGame');
   if @initGame<>nil then InitGame;
   initialized:=true;
  except
   on e:exception do LogI('Error in AppInit: '+ExceptionMsg(e));
  end;
 end;

procedure AppDrawFrame(env:PJNIEnv;this:jobject);
 begin
  try
   //DebugMessage('DrawFrame!');
   Signal('Engine\onFrame');
  except
   on e:exception do LogI('Error in AppDrawFrame: '+ExceptionMsg(e));
  end;
 end;

procedure AppPause(env:PJNIEnv;this:jobject);
 begin
  try
   LogI('AppPause!');
   Signal('Engine\ActivateWnd',0);
   Signal('Sound\Pause');
   HideVirtualKeyboard;
  except
   on e:exception do LogI('Error in AppPause: '+ExceptionMsg(e));
  end;
 end;

procedure AppResume(env:PJNIEnv;this:jobject);
 begin
  try
   LogI('AppResume!');
   Signal('Engine\ActivateWnd',1);
   Signal('Sound\Resume');
  except
   on e:exception do LogI('Error in AppResume: '+ExceptionMsg(e));
  end;
 end;

function AppInput(env:PJNIEnv;this:jobject; action,i1,i2:jint; text:jstring):jstring;
 var
  wst:WideString;
  c:TUIControl;
  i:integer;
 begin
  try
   result:=nil;
   if appEnv=nil then appEnv:=env;
   wst:=DecodeUTF8(StringFromJavaString(text));
   c:=FocusedControl;
   LogMessage(Format('AppInput: %d %d %d %s',[action, i1, i2, wst]));
   if (c<>nil) and (c is TUIEditBox) then
    with c as TUIEditBox do begin
    case action of
     // Commit text or set selection
     1,2:begin
       if selCount>0 then begin
         // replace selection with given text
         delete(realtext,selstart,selcount);
         insert(wst,realText,selStart);
       end else begin
         // Insert text into cursor position and select it
         insert(wst,realText,cursorpos+1);
         selstart:=cursorpos+1;
       end;
       selcount:=length(wst);
       cursorpos:=selstart+selcount-1;
       if action=1 then begin
         // Commit
         selstart:=cursorPos+1;
         selCount:=0;
       end;
       LogMessage(Format('Input action=%d, sel=%d:%d, cursor=%d',[action,selstart,selcount,cursorpos]));
     end;
     // Get text before cursor
     3:begin
       if selCount>0 then wst:=copy(realText,1,selStart-1)
        else wst:=copy(realText,1,cursorPos);
       if length(wst)>i1 then delete(wst,1,length(wst)-i1);
       result:=JavaString(EncodeUTF8(wst));
       LogMessage(Format('res=%s (%s)',[PtrToStr(result),EncodeUTF8(wst)]));
     end;
     // Get text after cursor
     4:begin
       if selCount>0 then wst:=copy(realtext,selStart+selCount,i1)
        else wst:=copy(realText,cursorPos+1,i1);
       result:=JavaString(EncodeUTF8(wst));
       LogMessage(Format('res=%s (%s)',[PtrToStr(result),EncodeUTF8(wst)]));
     end;
     // Get selected text
     5:if selCount>0 then begin
       wst:=copy(realText,selStart,selCount);
       result:=JavaString(EncodeUTF8(wst));
     end;
     // Delete text
     6:begin
       // After selection
       if selCount>0 then i:=selStart+selCount
        else i:=cursorpos+1;
       delete(realText,i,i2);
       // Before selection
       if selCount>0 then i:=selStart-1
        else i:=cursorPos;
       while (i>0) and (i1>0) do begin
        delete(realText,i,1);
        dec(i); dec(i1);
        dec(selStart);
        dec(cursorpos);
       end;
     end;
     // Set selection/composing region
     7,8:begin
       selStart:=i1+1;
       selCount:=i2-i1+1;
       cursorpos:=i2;
     end;

     // Enter
     10:begin
      Signal('Kbd\Char',13);
      Signal('Kbd\UniChar',13);
     end;
    end;
   end;
  except
   on e:exception do LogI('Error in AppInput: '+ExceptionMsg(e));
  end;
 end;

const
  // UI event types
  ACTION_DOWN   = 0;
  ACTION_UP     = 1;
  ACTION_MOVE   = 2;
  ACTION_CANCEL = 3;

procedure AppTouch(env:PJNIEnv;this:jobject; x,y:jfloat; action:jint);
 var
  tag:integer;
 begin
  try
   tag:=smallint(round(x))+smallint(round(y)) shl 16;
   //LogI(Format('AppTouch: %d  x=%5.1f  y=%5.1f tag=%8x',[action,x,y,tag]));
   if action=ACTION_DOWN then Signal('Engine\SingleTouchStart',tag);
   if action=ACTION_UP then Signal('Engine\SingleTouchRelease',tag);
   if action=ACTION_MOVE then Signal('Engine\SingleTouchMove',tag);
  except
   on e:exception do LogI('Error in AppTouch: '+ExceptionMsg(e));
  end;
 end;

procedure AppKey(env:PJNIEnv;this:jobject; keyCode,UChar:jint; event: jobject);
 begin
  LogI(Format('AppKey: %d  %d',[keyCode,UChar]));
 end;
{$ENDIF}

{ TGameApplication }

constructor TGameApplication.Create;
 var
  i:integer;
  st:string;
 begin
  try
   RegisterThread('ControlThread');
   SetCurrentDir(ExtractFileDir(ParamStr(0)));
   Randomize;
   
   if DirectoryExists('Logs') then begin
    configDir:='Logs\';
    UseLogFile('Logs\game.log');
   end else
    UseLogFile('game.log');
   LogCacheMode(true,false,true);
   SetLogMode(lmVerbose);

   UseControlFile('game.ctl');
   LoadOptions;
   SaveOptions; // Save modified settings

   for i:=1 to paramCount do HandleParam(paramstr(i));

   // PreloadFiles;
   //QueryServerVersion;
   //TryToUpdateUpdater;

  {$IFDEF STEAM}
  if checkForSteam then InitSteamAPI;
  if steamAvailable then
   // ����� ����� ��� ��������� �� �����
   if FileExists('Inf\DefaultLang') and (steamID<>0) then begin
    st:=lowercase(steamGameLang);
    if st='russian' then langCode:='ru';
    if st='english' then langCode:='en';
    LogMessage('First time launch: Steam language is '+langCode);
    SaveOptions;
    DeleteFile('Inf\DefaultLang');
   end;
   {$ENDIF}

   // Language and translation dictionary
   st:=ctlGetStr('game.ctl:\Options\LangFile','language.'+langCode);
   DictInit(st);
   uDict.unicode:=true;
   UIClasses.defaultEncoding:=teUTF8;

   SetupScreen;
  except
   on e:exception do begin
    ForceLogMessage('AppCreate error: '+ExceptionMsg(e));
    ErrorMessage('Fatal error: '#13#10+ExceptionMsg(e));
    halt;
   end;
  end;
 end;

procedure TGameApplication.CreateScenes;
begin

end;

destructor TGameApplication.Destroy;
 begin

  inherited;
 end;


procedure TGameApplication.HandleParam(param: string);
 begin
  param:=UpperCase(param);
  if param='-WND' then windowedMode:=true;
  if param='-FULLSCREEN' then windowedMode:=false;
  if param='-NOVSYNC' then noVSync:=true;
  if param='-DEBUG' then begin
   debugMode:=true;
   debugCriticalSections:=true;
  end;
  if param='-NOSTEAM' then checkForSteam:=false;
 end;

procedure TGameApplication.InitCursors;
begin
 {$IFDEF MSWINDOWS}
 game.RegisterCursor(crLink,2,LoadCursor(0,IDC_HAND));
 game.RegisterCursor(crWait,9,LoadCursor(0,IDC_WAIT));
 game.RegisterCursor(crDefault,1,LoadCursor(0,IDC_ARROW));
 game.ToggleCursor(crDefault);
 game.ToggleCursor(crWait);
 {$ENDIF}
end;

procedure TGameApplication.InitStyles;
begin
 InitCustomStyle('Images\');
end;

procedure TGameApplication.LoadFonts;
begin
 LogMessage('Loading fonts');
end;

procedure TGameApplication.LoadOptions;
 var
  i:integer;
 begin
  try
   // InstanceID = random constant
   instanceID:=CtlGetInt('game.ctl:\InstanceID',0);
   if instanceID=0 then begin
    instanceID:=(1000*random(50000)+MyTickCount shl 8+round(now*1000)) mod 100000000;
    CtlSetInt('game.ctl:\InstanceID',instanceID);
   end;

   // Window size
   i:=CtlGetInt('game.ctl:\Options\WindowWidth',-1);
   if i>0 then begin 
    windowWidth:=i;
    windowHeight:=CtlGetInt('game.ctl:\Options\WindowHeight',windowHeight);
   end;

  except
   on e:exception do ForceLogMessage('Options error: '+ExceptionMsg(e));
  end;
 end;

procedure TGameApplication.Run;
 var
  settings:TGameSettings;
 begin
  // CREATE GAME OBJECT
  // ------------------------
  {$IFDEF MSWINDOWS}
   {$IFDEF DIRECTX}
   if usedAPI=gaDirectX then game:=TDxGame8.Create(80);
   {$ENDIF}
   {$IFDEF OPENGL}
   if usedAPI=gaOpenGL then game:=TGLGame.Create(false);
   if usedAPI=gaOpenGL2 then game:=TGLGame.Create(true);
   {$ENDIF}
  {$ENDIF}
  {$IFDEF IOS}
   game:=TIOSGame.Create;
   {$ENDIF}
   {$IFDEF ANDROID}
   game:=TAndroidGame.Create;
  {$ENDIF}
  if game=nil then raise EError.Create('Game object not created!');

  // CONFIGURE GAME OBJECT
  // ------------------------
  with settings do begin
   title:=GameTitle;
   width:=windowWidth;
   height:=windowHeight;
   colorDepth:=32;
   refresh:=0;
   if WindowedMode then begin
    mode:=dmFixedWindow;
    altMode:=dmFullScreen;
   end else begin
    mode:=dmFullScreen;
    altmode:=dmFixedWindow;
   end;
   fitmode:=dfmKeepAspectRatio;
   showSystemCursor:=useSystemCursor;
   zbuffer:=16;
   stencil:=false;
   multisampling:=0;
   slowmotion:=false;
   if noVSync then begin
    VSync:=0;
    game.showFPS:=true;
   end else
    VSync:=1;
  end;
  if settings.mode<>dmSwitchResolution then
   ForceLogMessage('Running in cooperative mode')
  else
   ForceLogMessage('Running in exclusive mode');

  game.unicode:=true;
  game.Settings:=settings;
  if DebugMode then game.ShowDebugInfo:=3;

  // LAUNCH GAME OBJECT
  // ------------------------
  try
   game.Run;
  except
   on e:exception do begin
     ErrorMessage('Failed to run the game: '+ExceptionMsg(e));
     halt;
   end;
  end;
  ForceLogMessage('RUN');
  game.initialized:=true;

  // LOADER SCENE
  // ------------------------
  game.AddScene(TLoadingScene.Create);
  InitCursors;
  LoadFonts;
  SelectFonts;
  InitStyles;
  AddConsoleScene;
  CreateTweakerScene(painter.GetFont('Default',6),painter.GetFont('Default',7));
  CreateScenes;

  game.ToggleCursor(crWait,false);

  // MAIN LOOP
  // ------------------------
  repeat
   try
    PingThread;
    CheckCritSections;
    delay(10); // ������������ ������� ��� ����� ����� ����������� ��������� �� ��� �����������
    ProcessMessages;
   except
    on e:exception do ForceLogMessage('Error in Control Thread: '+e.message);
   end;
  until game.terminated;
 end;

procedure TGameApplication.SaveOptions;
begin
 try
  SaveAllControlFiles;
 except
  on e:exception do ForceLogMessage('Error in options saving:'+ExceptionMsg(e));
 end;
end;

procedure TGameApplication.SelectFonts;
begin

end;

procedure TGameApplication.SetupScreen;
{$IFDEF MSWINDOWS}
var
 displayWidth,displayHeight:integer;
 aspect:double;
 r:TRect;
begin
 aspect:=windowWidth/windowHeight;

 if not windowedMode then begin
  displayWidth:=GetSystemMetrics(SM_CXSCREEN);
  displayHeight:=GetSystemMetrics(SM_CYSCREEN);

  windowWidth:=displayWidth;
  windowHeight:=displayHeight;

  if displayWidth>=displayHeight*aspect then windowWidth:=round(displayHeight*aspect)
   else windowHeight:=round(displayWidth/aspect);
  if abs(windowWidth-displayWidth)<2 then windowWidth:=displayWidth;
  if abs(windowHeight-displayHeight)<2 then windowHeight:=displayHeight;

  if (displayWidth>2560) or (displayHeight>1600) then begin
   LogMessage('Screen size too large => will use upscaling');
   windowWidth:=1920;
   windowHeight:=1080;
  end;

 end else begin
  // windowed
  SystemParametersInfo(SPI_GETWORKAREA,0,@r,0);
  displayWidth:=r.Right-r.left-2*GetSystemMetrics(SM_CXFIXEDFRAME);
  displayHeight:=r.Bottom-r.top-GetSystemMetrics(SM_CYCAPTION)-2*GetSystemMetrics(SM_CYFIXEDFRAME);

  windowWidth:=Min2(windowWidth,displayWidth);
  windowHeight:=Min2(windowHeight,displayHeight);
 end;
end;
{$ELSE}
begin

end;
{$ENDIF}

{ TLoadingScene }

constructor TLoadingScene.Create;
begin
 inherited Create(true);
 v.Init;
 SetStatus(ssActive);
end;

procedure TLoadingScene.Render;
var
 i,l:integer;
 x,y,a:double;
begin
 if tex=nil then begin
  v.Animate(0.6,1500,Spline1);
  tex:=texman.AllocImage(16,8,pfTrueColorAlpha,0,'bar') as TTextureImage;
  tex.lock;
  SetRenderTarget(tex.data,tex.pitch,tex.width,tex.height);
  FillRect(0,0,tex.width-1,tex.height-1,0);
  FillRect(1,1,tex.width-2,tex.height-2,$FF808080);
  FillRect(2,2,tex.width-3,tex.height-3,$FFFFFFFF);
  tex.unlock;
 end;
 painter.Clear($FF000000);
 for i:=0 to 12 do begin
  a:=i*3.1416/6.5;
  x:=screenWidth/2+32*cos(a);
  y:=screenHeight/2-32*sin(a);
  L:=50+round(-256*i/13-MyTickCount*0.3) and 255;
  L:=round(v.Value*L);
  painter.DrawRotScaled(x,y,1,1,-a,tex,L shl 24+$FFFFFF);
 end;
end;

end.
