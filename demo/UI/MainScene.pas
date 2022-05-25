﻿// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit MainScene;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.CrossPlatform,Apus.EventMan,Apus.Colors,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Load; override;
   procedure Render; override;
  end;

 var
  sceneMain:TMainScene;
  root:TUIElement;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine: UI Demo'; // app window title
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
 end;

procedure RootCloseCLick;
 begin
  root.visible:=false;
 end;

procedure InitTestLayer;
 begin
  root.DeleteChildren;
  root.visible:=true;
  TUIButton.Create(100,28,'Root\Close','Back',0,root).
   SetPos(root.width/2,root.height-2,pivotBottomCenter).
   SetAnchors(0.5,1,0.5,1);
  UIButton('Root\Close').onClick:=@RootCloseClick;
 end;

procedure TestButtons;
 begin
  InitTestLayer;
 end;

procedure TestWidgets;
 begin
  InitTestLayer;
//  TUILabel.Create()
 end;


{ TMainScene }
procedure TMainScene.Load;
 var
  font:cardinal;
  btn:TUIButton;
  panel:TUIElement;
 begin
  UI.font:=txt.GetFont('',7.0);
  // Create menu panel
  panel:=TUIElement.Create(250,200,UI,'MainMenu');
  panel.Center;
  panel.SetAnchors(anchorCenter);
  panel.layout:=TRowLayout.CreateVertical(10,true);
  panel.SetPaddings(15);
  panel.styleInfo:='40E0E0E0 60E0E0E0';

  // Create menu buttons
  TUIButton.Create(120,30,'Main\Widgets','Widgets',panel).onClick:=@TestWidgets;
  TUIButton.Create(120,30,'Main\Buttons','Buttons',panel).onClick:=@TestButtons;
  TUIButton.Create(120,30,'Main\Close','Exit',0,panel);
  Link('UI\Main\Close\Click','Engine\Cmd\Exit');

  // Create a placeholder UI element for demos
  root:=TUIElement.Create(UI.width,UI.height,UI,'Root');
  root.SetAnchors(anchorAll);
  root.styleInfo:='FFB0C0C4 80000000';
  root.shape:=TElementShape.shapeFull;
  root.visible:=false;
 end;

procedure TMainScene.Render;
 begin
  // 1. Draw scene background
  gfx.target.Clear($406080); // clear with black
  // Draw some lines
  inherited;
 end;

end.