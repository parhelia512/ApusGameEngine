﻿// Class for 3D model with skeletal (rigged) animation
//
// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Model3D;
interface
uses Apus.MyServis, Apus.Geom2D, Apus.Geom3D, Apus.Structs, Apus.AnimatedValues, Apus.Engine.API;
const
 // Bone flags
 bfDefaultPos = 1; // default matrix updated (model->bone)
 bfCurrentPos = 2; // current matrix updated (bone->model)

type
 // Part of mesh surface
 TModelPart=record
  partName,materialName:AnsiString;
  firstTrg,trgCount:integer;  // triangles of the part
  firstVrt,vrtCount:integer;  // vertices used in the part (may also conatain other vertices)
 end;

 {$MinEnumSize 1}
 TBoneProperty=(bpPosition,bpRotation,bpScale);

 // Definition of bone
 TBone=packed record
  boneName:string;
  parent:integer; // index of the parent bone
  // default values
  position:TPoint3s;
  scale:TVector3s;
  {$IFDEF CPUx64} padding:array[0..2] of cardinal;  {$ENDIF} // align by 16
  rotation:TQuaternionS;
  matrix:TMatrix4s; // model space -> bone space (in reference position)
 end;
 TBonesArray=array of TBone;

 // Animation timeline is a big table [bone_property,frame]
 // This record (20 bytes) stores one cell of this table
 // Sorted by frame,boneIdx
 TKeyFrame=packed record
  frame:word;   // time marker
  boneIdx:byte; // bone index
  prop:TBoneProperty;    // which bone property is affected (position, rotation or scale)
  value:TQuaternionS;
 end;
 TAnimationKeyFrames=array of TKeyFrame;

 // Single bone state
 TBoneState=record
  position:TVector4s;
  rotation:TQuaternionS;
  scale:TVector4s;
  function IsEqual(state:TBoneState):boolean;
 end;
 TBoneStates=array of TBoneState;

 // Per-frame bone states
 TTimeline=record
  positions:array of TVector4s;
  rotations:array of TQuaternionS;
  scales:array of TVector4s;
 end;

 TModel3D=class;
 TModelInstance=class;

 // Single animation timeline
 TAnimation=record
  name:string;
  numFrames:integer; // duration in frames
  fps:single;  // frames per second
  keyFrames:TAnimationKeyFrames; // individual keyframes (source)
  loopFrom,loopTo:integer; // loop frame range [loopFrom..loopTo-1] (0 - don't loop), if loopTo frame exist it should be equal to loopFrom frame
  smooth:boolean; // play smoothly - interpolate between animation frames
  procedure SetLoop(loop:boolean=true); overload;
  procedure SetLoop(fromFrame,toFrame:integer); overload;
  procedure BuildTimeline(model:TModel3D);
  // Get timeline values
  function GetBonePosition(bone:integer;frame:single):TVector4s;
  function GetBoneRotation(bone:integer;frame:single):TQuaternionS;
  function GetBoneScale(bone:integer;frame:single):TVector4s;
 private
  timeline:array of TTimeline; // timeline for each bone (can contain empty arrays)
  defaultBoneState:TBoneStates;  // state of bones with no timeline
  procedure SmoothMove(var frame:single;out frame1,frame2:integer);
 end;

 // Vertex bindings
 TVertexBinding=packed record
  bone1,bone2:byte;
  weight1,weight2:byte; // 0..255 range
 end;

 // 3D model with rigged animation support
 TModel3D=class
  name,src:string; // Model name and source file name (if available)
  // Vertex data (no more than 64K vertices!)
  vp:array of TPoint3s;  // vertex positions
  vn:array of TVector3s; // vertex normals (optional)
  vt,vt2:array of TPoint2s; // texture coords (up to 2 sets, optional)
  vc:array of cardinal;     // vertex colors (optional)
  vb:array of TVertexBinding;  // Weights and indices (max 2 bones supported per vertex)
  // Surface data
  trgList:array of word;    // List of triangles
  parts:array of TModelPart;  // Model may contain multiple parts
  // Bones
  bones:TBonesArray;
  bonesRelative:boolean; // true if each bone is specified in it's parent bone space, false - absolute values
  // Animation sequences
  animations:array of TAnimation;

  // External references
  shaderName,texName,texName2:string;

  fps:single;

  constructor Create(name:string;src:string='');
  procedure Prepare; // precalculate bone matrices, build animation timelines etc...
  // Instantiate a model
  function CreateInstance:TModelInstance;

  procedure FlipX; // Flip model along X axis (right\left CS conversion)
  function FindBone(bName:string):integer;

 private
  bonesHash:TSimpleHashS;
  procedure CalcBoneMatrix(bone:integer);
 end;

 // An animated instance of a 3D model
 TModelInstance=class
  model:TModel3D;
  constructor Create(model:TModel3D);
  // Control animation
  procedure PlayAnimation(name:string='';easeTimeMS:integer=0);
  procedure StopAnimation(name:string='';easeTimeMS:integer=0);
  procedure PauseAnimation(name:string='');
  procedure ResumeAnimation(name:string='');
  procedure SetAnimationPos(name:string;frame:integer); overload;
  procedure SetAnimationPos(name:string;frame:single); overload;
  function IsAnimationPlaying(name:string=''):boolean; // playing and not paused
  function IsAnimationPaused(name:string=''):boolean; // paused
  function GetAnimationPos(name:string=''):single;
  function GetAnimationSize(name:string=''):integer;

  procedure Update; // update animations and calculate bones
  procedure Draw(tex:TTexture);
 protected
 type
  TBoneMatrices=record
   toModel:TMatrix4s; // transform to the model space
   combined:TMatrix4s; // combined transformation from default pos to animated pos
  end;

  // For each underlying model's animation there is a state object
  TInstanceAnimation=record
   weight:TAnimatedValue;
   playing:boolean; // is it playing now?
   paused:boolean;
   stopping:boolean; // don't loop if stopping
   curFrame:single; // current playback position (in frames)
   startTime:int64; // when animation playback was started
  end;
 var
  lastUpdated:int64; // when state was last updated
  animations:array of TInstanceAnimation;
  bones:TBoneStates;
  boneMatrices:array of TBoneMatrices; // "default pos -> animated pos" transformation matrix
  vertices:array of TVertex3D;
  dirty:boolean; // flag to update vertices bound to bones (if bones were changed)
  procedure AdvanceAnimations(time:integer);
  function UpdateBones:boolean;
  procedure UpdateBoneMatrices;
  procedure FillVertexBuffer;
  function FindAnimation(name:string):integer;
 end;

 var
  globalDirty:integer;

implementation
 uses Apus.CrossPlatform, SysUtils;

 const
  defaultColor:cardinal=$FF808080;


{ TAnimation }
procedure TAnimation.BuildTimeline(model:TModel3D);
 var
  numBones:integer;
  i,j,n,bone,frame,lastKeyFrame,firstKeyFrame:integer;
  nn,step:single;
  dwNN:cardinal absolute nn;
  vec:TVector4s;
 begin
  numBones:=length(model.bones);
  SetLength(timeline,numBones);
  SetLength(defaultBoneState,numBones);
  for i:=0 to numBones-1 do begin // default values
   defaultBoneState[i].position:=Vector4s(model.bones[i].position);
   defaultBoneState[i].rotation:=model.bones[i].rotation;
   defaultBoneState[i].scale:=Vector4s(model.bones[i].scale);
  end;

  // Store keyframes in the timeline
  nn:=NAN;
  for i:=0 to high(keyFrames) do begin
   bone:=keyFrames[i].boneIdx;
   frame:=keyFrames[i].frame;
   ASSERT(frame<numFrames);
   case keyFrames[i].prop of
    bpPosition:begin
      if timeline[bone].positions=nil then begin
       SetLength(timeline[bone].positions,numFrames);
       FillDword(timeline[bone].positions[0],numFrames*4,dwNN);
      end;
      timeline[bone].positions[frame]:=keyFrames[i].value;
    end;
    bpRotation:begin
      if timeline[bone].rotations=nil then begin
       SetLength(timeline[bone].rotations,numFrames);
       FillDword(timeline[bone].rotations[0],numFrames*4,dwNN);
      end;
      timeline[bone].rotations[frame]:=keyFrames[i].value;
    end;
    bpScale:begin
      if timeline[bone].scales=nil then begin
       SetLength(timeline[bone].scales,numFrames);
       FillDword(timeline[bone].scales[0],numFrames*4,dwNN);
      end;
      timeline[bone].scales[frame]:=keyFrames[i].value;
    end;
   end;
  end;

  // Fill the gaps - interpolate keyframe values, and reduce arrays with just single value
  for i:=0 to high(timeline) do
   with timeline[i] do begin
    // Process position
    if length(positions)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if positions[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do begin
         positions[j]:=positions[lastKeyFrame];
         positions[j].Middle(positions[frame],(j-lastKeyFrame)*step);
        end;
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].position:=positions[firstKeyFrame];
      SetLength(positions,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       positions[frame]:=positions[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       positions[frame]:=positions[lastKeyframe];
     end;
    end;
    // Process rotation
    if length(rotations)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if rotations[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do
         rotations[j]:=QInterpolate(rotations[lastKeyFrame],rotations[frame],(j-lastKeyFrame)*step); // with normalization
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].rotation:=rotations[firstKeyFrame];
      SetLength(rotations,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       rotations[frame]:=rotations[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       rotations[frame]:=rotations[lastKeyframe];
     end;
    end;
    // Process scale
    if length(scales)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if scales[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do begin
         scales[j]:=scales[lastKeyFrame];
         scales[j].Middle(scales[frame],(j-lastKeyFrame)*step);
        end;
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].scale:=scales[firstKeyFrame];
      SetLength(scales,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       scales[frame]:=scales[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       scales[frame]:=scales[lastKeyframe];
     end;
    end;
   end;
 end;

function TAnimation.GetBonePosition(bone:integer;frame:single):TVector4s;
 var
  frame1,frame2:integer;
 begin
  if timeline[bone].positions=nil then
   exit(defaultBoneState[bone].position);

  if smooth then begin
   SmoothMove(frame,frame1,frame2);
   with timeline[bone] do begin
    result:=positions[frame1];
    result.Middle(positions[frame2],frame);
   end;
  end else
   result:=timeline[bone].positions[round(frame)];
 end;

function TAnimation.GetBoneRotation(bone:integer;frame:single):TQuaternionS;
 var
  frame1,frame2:integer;
  s:single;
 begin
  if timeline[bone].rotations=nil then
   exit(defaultBoneState[bone].rotation);

  if smooth then begin
   s:=frame;
   SmoothMove(frame,frame1,frame2);
   with timeline[bone] do begin
    result:=QInterpolate(rotations[frame1],rotations[frame2],frame);
   end;
  end else
   result:=timeline[bone].rotations[round(frame)];
 end;

function TAnimation.GetBoneScale(bone:integer;frame:single):TVector4s;
 begin
  if timeline[bone].scales<>nil then
   result:=timeline[bone].scales[round(frame)]
  else
   result:=defaultBoneState[bone].scale;
 end;

procedure TAnimation.SmoothMove(var frame:single;out frame1,frame2:integer);
 begin
   frame2:=trunc(frame+1);
   frame1:=frame2-1;
   frame:=frame-frame1;
   if frame2>=numFrames then frame2:=0; // no wrapping around loopTo since frames[loopTo] must be equal to frames[loopFrom]
   if frame1<0 then
    if loopTo>0 then
     frame1:=loopTo-1
    else
     frame1:=numFrames-1;
 end;


procedure TAnimation.SetLoop(fromFrame,toFrame:integer);
 begin
  loopFrom:=fromFrame;
  loopTo:=toFrame;
 end;

procedure TAnimation.SetLoop(loop:boolean=true);
 begin
  if loop then
   SetLoop(0,numFrames)
  else
   SetLoop(0,0);
 end;

{ TModel3D }

procedure TModel3D.CalcBoneMatrix(bone:integer);
 var
  mat,mScale,mTemp:TMatrix4s;
  parent:integer;
 begin
   if not IsNAN(bones[bone].matrix[0,0]) then exit; // already calculated
   parent:=bones[bone].parent;
   // recursion
   if (parent>=0) and bonesRelative then begin
    if IsNaN(bones[parent].matrix[0,0]) then
     CalcBoneMatrix(parent);
   end;
   MatrixFromQuaternion(bones[bone].rotation,mat);
   if not IsIdentity(bones[bone].scale) then
    with bones[bone] do begin
     mScale:=IdentMatrix4s;
     mScale[0,0]:=scale.x;
     mScale[1,1]:=scale.y;
     mScale[2,2]:=scale.z;
     mTemp:=mat;
     MultMat(mScale,mTemp,mat);
    end;
   move(bones[bone].position,mat[3],sizeof(TPoint3s));
   // Combine with parent bone
   if (parent>=0) and bonesRelative then
    MultMat(mat,bones[parent].matrix,bones[bone].matrix)
   else
    bones[bone].matrix:=mat;
 end;

constructor TModel3D.Create(name:string;src:string='');
 begin
  inherited Create;
  self.name:=name;
  self.src:=src;
  bonesRelative:=true;
 end;

function TModel3D.CreateInstance:TModelInstance;
 begin
  result:=TModelInstance.Create(self);
 end;

function TModel3D.FindBone(bName:string):integer;
 var
  i:integer;
 begin
  if bonesHash.count<>length(bones) then begin
   bonesHash.Init(length(bones));
   for i:=0 to high(bones) do
    bonesHash.Put(bones[i].boneName,i);
  end;
  result:=bonesHash.Get(bName);
 end;

procedure TModel3D.FlipX;
 var
  i,j:integer;
 begin
  // vertices
  for i:=0 to high(vp) do vp[i].x:=-vp[i].x;
  for i:=0 to high(vn) do vn[i].x:=-vn[i].x;
  // bones
  for i:=0 to high(bones) do begin
   bones[i].position.x:=-bones[i].position.x;
   bones[i].rotation.x:=-bones[i].rotation.x;
  end;
  // animations
  for i:=0 to high(animations) do
   for j:=0 to high(animations[i].keyFrames) do
    with animations[i].keyFrames[j] do
     if prop in [bpPosition,bpRotation] then value.x:=-value.x;
 end;


procedure TModel3D.Prepare;
 var
  mTemp:TMatrix4s;
  i:integer;
 begin
  for i:=0 to high(bones) do
   bones[i].matrix[0,0]:=NaN;
  // Calculate "bone->world" matrices
  for i:=0 to high(bones) do
   CalcBoneMatrix(i);
  // Invert bone matrices to get "world->bone" matrix
  for i:=0 to high(bones) do begin
   mTemp:=bones[i].matrix;
   InvertFull(mTemp,bones[i].matrix);
  end;

  // Build animation timelines
  for i:=0 to high(animations) do
   animations[i].BuildTimeline(self);
 end;

{ TModelInstance }

constructor TModelInstance.Create(model:TModel3D);
 var
  i:integer;
 begin
  self.model:=model;
  SetLength(animations,length(model.animations));
  for i:=0 to high(animations) do begin
   animations[i].weight.Init;
  end;
 end;

procedure TModelInstance.Draw(tex:TTexture);
 begin
  FillVertexBuffer;
  gfx.draw.IndexedMesh(@vertices[0],@model.trgList[0],length(model.trgList) div 3,length(vertices),tex);
 end;

function BlendVec(const vec:TVector3s;const m1,m2:TMatrix4s;weight1,weight2:byte):TVector3s;
 var
  tmp,src:TVector4s;
 begin
  if weight1+weight2>0 then begin
   ZeroMem(tmp,sizeof(tmp));
   src:=Vector4s(vec);
   if weight1>0 then begin
    MultPnt(m1,@src,1,0);
    tmp.Add(src,weight1/255);
   end;
   if weight2>0 then begin
    src:=Vector4s(vec);
    MultPnt(m2,@src,1,0);
    tmp.Add(src,weight2/255);
   end;
   move(tmp,result,sizeof(result));
  end else
   result:=vec;
 end;

procedure TModelInstance.FillVertexBuffer;
 var
  v1,v2:TVector4s;
  i,vCount:integer;
  rigged:boolean;
  binding:TVertexBinding;
 begin
  vCount:=length(model.vp);
  // Init vertex buffer
  if length(vertices)<>vCount then begin
   SetLength(vertices,vCount);
   dirty:=true; // mark to fill vertex data
   // Tex coords and vertex colors are permanent - filled just once
   if length(model.vt)=vCount then
    for i:=0 to vCount-1 do
     vertices[i].SetUV(model.vt[i]);
   // Vertex colors
   if length(model.vc)=vCount then
    for i:=0 to vCount-1 do
     vertices[i].color:=model.vc[i]
   else
    for i:=0 to vCount-1 do
     vertices[i].color:=$FFFFFFFF;
  end;
  if not dirty then exit;  // nothing changed -> no need to update vertices

  rigged:=(length(model.vb)=vCount) and
          (length(model.bones)=length(boneMatrices));
  for i:=0 to vCount-1 do begin
   if rigged then begin
    binding:=model.vb[i];
    with binding do begin
     vertices[i].SetPos(BlendVec(model.vp[i],
      boneMatrices[bone1].combined,
      boneMatrices[bone2].combined,
      weight1,weight2));

     vertices[i].SetNormal(BlendVec(model.vn[i],
      boneMatrices[bone1].combined,
      boneMatrices[bone2].combined,
      weight1,weight2));
    end;
   end else begin
    vertices[i].SetPos(model.vp[i]);
    vertices[i].SetNormal(model.vn[i]);
   end;
  end;
  dirty:=false;
 end;

function TModelInstance.FindAnimation(name:string):integer;
 var
  i:integer;
 begin
  for i:=0 to high(model.animations) do
   if (name='') or SameText(name,model.animations[i].name) then
    exit(i);
  raise EWarning.Create('Animation "%s" not found in model "%s"',[name,model.name]);
 end;

procedure TModelInstance.PlayAnimation(name:string;easeTimeMS:integer);
 begin
  with animations[FindAnimation(name)] do begin
    playing:=true;
    stopping:=false;
    paused:=false;
    curFrame:=0;
    startTime:=MyTickCount;
    weight.Animate(1,easeTimeMS);
    LogMessage('PlayAni "%s" for "%s"',[name,model.name]);
   end;
 end;

procedure TModelInstance.StopAnimation(name:string;easeTimeMS:integer);
 begin
  with animations[FindAnimation(name)] do begin
   stopping:=true;
   weight.Animate(0,easeTimeMS);
   LogMessage('StopAni "%s" for "%s"',[name,model.name]);
  end;
 end;

procedure TModelInstance.PauseAnimation(name:string);
 begin
  animations[FindAnimation(name)].paused:=true;
 end;

procedure TModelInstance.ResumeAnimation(name:string);
 begin
  animations[FindAnimation(name)].paused:=false;
 end;

procedure TModelInstance.SetAnimationPos(name:string;frame:single);
 var
  i,max:integer;
 begin
  i:=FindAnimation(name);
  with animations[i] do begin
   playing:=true;
   stopping:=false;
   weight.Assign(1);
   paused:=true;
   max:=model.animations[i].numFrames-1;
   if round(frame)>max then frame:=frame-(max+1);
   if frame>=0 then
    curFrame:=Clamp(frame,0,max)
   else
    curFrame:=Clamp(max-frame,0,max);
  end;
 end;

procedure TModelInstance.SetAnimationPos(name:string;frame:integer);
 begin
  SetAnimationPos(name,round(frame));
 end;

function TModelInstance.GetAnimationPos(name:string):single;
 begin
  result:=animations[FindAnimation(name)].curFrame;
 end;

function TModelInstance.GetAnimationSize(name:string):integer;
 var
  i:integer;
 begin
  i:=FindAnimation(name);
  result:=model.animations[i].numFrames;
 end;

function TModelInstance.IsAnimationPaused(name: string): boolean;
 begin
  with animations[FindAnimation(name)] do
   result:=paused;
 end;

function TModelInstance.IsAnimationPlaying(name:string):boolean;
 begin
  with animations[FindAnimation(name)] do
   result:=playing and not paused;
 end;

procedure TModelInstance.Update;
 var
  time:integer;
 begin
  if lastUpdated>0 then
   time:=game.frameStartTime-lastUpdated
  else
   time:=-1;
  lastUpdated:=game.frameStartTime;
  if time=0 then exit;

  AdvanceAnimations(time);
  if UpdateBones then begin
   UpdateBoneMatrices;
   dirty:=true;
   inc(globalDirty);
  end;
 end;

procedure TModelInstance.AdvanceAnimations(time:integer);
 var
  i,t,loopTo:integer;
  oldFrame:integer;
 begin
  for i:=0 to high(animations) do
   with animations[i] do
    if playing and not paused then begin
     t:=time;
     if t<0 then t:=game.frameStartTime-startTime;
     oldFrame:=round(curFrame);
     curFrame:=curFrame+t*model.animations[i].fps/1000;
     loopTo:=model.animations[i].loopTo;
     if (loopTo>0) and not stopping then begin // loop animation
      while round(curFrame)>=loopTo do
       curFrame:=curFrame-(loopTo-model.animations[i].loopFrom);
     end else
      if round(curFrame)>model.animations[i].numFrames-1 then begin
       playing:=false;
       curFrame:=model.animations[i].numFrames-1;
      end;
     if stopping and (weight.Value=0) then begin
      playing:=false;
      stopping:=false;
      curFrame:=0;
     end;
    end;
 end;

// Returns true if bones were changed
function TModelInstance.UpdateBones:boolean;
 var
  i,j,bCount,anim:integer;
  fullWeight,frame:single;
  aCount:integer; // number of active animations
  aIdx:array[0..5] of integer;
  weights:array[0..5] of single; // max 6 active animations
  vec:TVector4s;
  bState:TBoneState;
 begin
  result:=false;
  // Find active animations and calculate weights
  fullWeight:=0;
  aCount:=0;
  for i:=0 to high(animations) do begin
   if animations[i].playing then begin
    aIdx[aCount]:=i;
    weights[aCount]:=animations[i].weight.ValueAt(game.frameStartTime);
    fullWeight:=fullWeight+weights[aCount];
    inc(aCount);
    if aCount>=length(aIdx) then break;
   end
  end;
  if aCount=0 then exit; // no active animations
  // Normalize weights
  for i:=0 to aCount-1 do
   weights[i]:=weights[i]/fullWeight;
  // Prepare bones array
  bCount:=length(model.bones);
  if length(bones)<>bCount then begin
   result:=true;
   SetLength(bones,bCount);
  end;
  // Calculate bones
  for i:=0 to bCount-1 do begin
   // Use default bones
   bones[i].position.xyz:=model.bones[i].position;
   bones[i].rotation:=model.bones[i].rotation;
   bones[i].scale.xyz:=model.bones[i].scale;
   //if i<>40 then continue;
   ZeroMem(bState,sizeof(bState));
   for j:=0 to aCount-1 do begin
    anim:=aIdx[j];
    frame:=animations[anim].curFrame;
    // position
    vec:=model.animations[anim].GetBonePosition(i,frame);
    bState.position.Add(vec,weights[j]);
    // rotation
    vec:=model.animations[anim].GetBoneRotation(i,frame);
    bState.rotation.Add(vec,weights[j]);
    // scale
    vec:=model.animations[anim].GetBoneScale(i,frame);
    bState.scale.Add(vec,weights[j]);
   end;
   if aCount>1 then bState.rotation.Normalize; // sum of multiple rotations
   if not bState.IsEqual(bones[i]) then result:=true; // modified
   bones[i]:=bState;
  end;
 end;

procedure TModelInstance.UpdateBoneMatrices;
 procedure CalculateBoneMatrix(bone:integer);
  var
   mat,mScale,mTemp:TMatrix4s;
   parent:integer;
  begin
   if not IsNAN(boneMatrices[bone].toModel[0,0]) then exit; // already calculated
   parent:=model.bones[bone].parent;
   // recursion
   if parent>=0 then begin
    if IsNaN(boneMatrices[parent].toModel[0,0]) then
     CalculateBoneMatrix(parent);
   end;
   MatrixFromQuaternion(bones[bone].rotation,mat);
   if not IsIdentity(bones[bone].scale.xyz) then
    with bones[bone] do begin
     mScale:=IdentMatrix4s;
     mScale[0,0]:=scale.x;
     mScale[1,1]:=scale.y;
     mScale[2,2]:=scale.z;
     mTemp:=mat;
     MultMat(mScale,mTemp,mat); // TODO: !проверить порядок!
    end;
   move(bones[bone].position.xyz,mat[3],sizeof(TPoint3s));
   // Искомая матрица получается как цепочка преобразований:
   // из дефолтной позиции (1)-> в пространство кости (2)-> в пространство кости-предка (3)-> в мировые к-ты
   // матрица (1) постоянна и вычислена заранее - это model.bones[bone].matrix
   // матрица (2) вычислена здесь - это mat
   // матрица (3) вычислена в процессе рекурсии
   // Combine with parent bone
   if (parent>=0) and model.bonesRelative then
    MultMat(mat,boneMatrices[parent].toModel,boneMatrices[bone].toModel)
   else
    boneMatrices[bone].toModel:=mat;
   // Combine with
   with bones[bone] do begin
    MultMat(model.bones[bone].matrix,boneMatrices[bone].toModel,boneMatrices[bone].combined);
   end;
  end;

 var
  i,n:integer;
 begin
  n:=length(bones);
  if n=0 then exit;
  if length(boneMatrices)<>n then SetLength(boneMatrices,n);
  for i:=0 to n-1 do
   boneMatrices[i].toModel[0,0]:=NaN;
  for i:=0 to n-1 do
   CalculateBoneMatrix(i);
 end;

{ TBoneState }

function TBoneState.IsEqual(state:TBoneState):boolean;
 begin
  result:=
    Apus.Geom3D.IsEqual(position,state.position,10) and
    Apus.Geom3D.IsEqual(rotation,state.rotation,10) and
    Apus.Geom3D.IsEqual(scale,state.scale,10);
 end;

end.
