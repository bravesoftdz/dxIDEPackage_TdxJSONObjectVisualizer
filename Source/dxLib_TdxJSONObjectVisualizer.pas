(*
As of January 2016, latest version maintained on github:
https://github.com/darianmiller/dxIDEPackage_TdxJSONObjectVisualizer
*)
unit dxLib_TdxJSONObjectVisualizer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ToolsAPI, Vcl.StdCtrls;

type
  TAvailableState = (asAvailable, asProcRunning, asOutOfScope, asNotAvailable);

  TdxLibJSONObjectViewerFrame = class(TFrame, IOTADebuggerVisualizerExternalViewerUpdater,
    IOTAThreadNotifier, IOTAThreadNotifier160)
    memJSON: TMemo;
  private
    FOwningForm: TCustomForm;
    FClosedProc: TOTAVisualizerClosedProcedure;
    FExpression: string;
    fTypeName:String;
    FNotifierIndex: Integer;
    FCompleted: Boolean;
    FDeferredResult: string;
    FDeferredError: Boolean;
    FAvailableState: TAvailableState;
    function Evaluate(Expression: string): string;
  protected
    procedure SetParent(AParent: TWinControl); override;
  public
    procedure CloseVisualizer;
    procedure MarkUnavailable(Reason: TOTAVisualizerUnavailableReason);
    procedure RefreshVisualizer(const Expression, TypeName, EvalResult: string);
    procedure SetClosedCallback(ClosedProc: TOTAVisualizerClosedProcedure);
    procedure SetForm(AForm: TCustomForm);

    procedure CustomDisplay(const Expression, TypeName, EvalResult: string);

    { IOTAThreadNotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    procedure ThreadNotify(Reason: TOTANotifyReason);
    procedure EvaluteComplete(const ExprStr, ResultStr: string; CanModify: Boolean;
      ResultAddress, ResultSize: LongWord; ReturnCode: Integer);
    procedure ModifyComplete(const ExprStr, ResultStr: string; ReturnCode: Integer);
    { IOTAThreadNotifier160 }
    procedure EvaluateComplete(const ExprStr, ResultStr: string; CanModify: Boolean;
      ResultAddress: TOTAAddress; ResultSize: LongWord; ReturnCode: Integer);
  end;

procedure Register;

implementation

uses
  DesignIntf, Actnlist, ImgList, Menus, IniFiles,
  dxLib_JSONObjects,
  dxLib_JSONFormatter;

{$R *.dfm}

resourcestring
  sVisualizerName = 'dxIDEPackage: TdxJSONObject Visualizer for Delphi';
  sVisualizerDescription = 'Debugger visualizer which displays a pretty-printed JSON string from a TdxJSONObject descendant';
  sMenuText = 'Show JSON';
  sFormCaption = 'TdxJSONObject Visualizer for expression: %s (%s)';
  sProcessNotAccessible = 'process not accessible';
  sValueNotAccessible = 'value not accessible';
  sOutOfScope = 'out of scope';

type

  IFrameFormHelper = interface
    ['{0FD4A98F-CE6B-422A-BF13-14E59707D3B2}']
    function GetForm: TCustomForm;
    function GetFrame: TCustomFrame;
    procedure SetForm(Form: TCustomForm);
    procedure SetFrame(Form: TCustomFrame);
  end;

  TdxLibJSONObjectVisualizerForm = class(TInterfacedObject, INTACustomDockableForm, IFrameFormHelper)
  private
    FMyFrame: TdxLibJSONObjectViewerFrame;
    FMyForm: TCustomForm;
    FExpression: string;
    FTypeName:String;
  public
    constructor Create(const Expression, TypeName: string);
    { INTACustomDockableForm }
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    function GetIdentifier: string;
    function GetMenuActionList: TCustomActionList;
    function GetMenuImageList: TCustomImageList;
    procedure CustomizePopupMenu(PopupMenu: TPopupMenu);
    function GetToolbarActionList: TCustomActionList;
    function GetToolbarImageList: TCustomImageList;
    procedure CustomizeToolBar(ToolBar: TToolBar);
    procedure LoadWindowState(Desktop: TCustomIniFile; const Section: string);
    procedure SaveWindowState(Desktop: TCustomIniFile; const Section: string; IsProject: Boolean);
    function GetEditState: TEditState;
    function EditAction(Action: TEditAction): Boolean;
    { IFrameFormHelper }
    function GetForm: TCustomForm;
    function GetFrame: TCustomFrame;
    procedure SetForm(Form: TCustomForm);
    procedure SetFrame(Frame: TCustomFrame);
  end;

  TdxLibJSONObjectDebuggerVisualizer = class(TInterfacedObject, IOTADebuggerVisualizer,
    IOTADebuggerVisualizerExternalViewer)
  public
    function GetSupportedTypeCount: Integer;
    procedure GetSupportedType(Index: Integer; var TypeName: string;
      var AllDescendants: Boolean);
    function GetVisualizerIdentifier: string;
    function GetVisualizerName: string;
    function GetVisualizerDescription: string;
    function GetMenuText: string;
    function Show(const Expression, TypeName, EvalResult: string; Suggestedleft, SuggestedTop: Integer): IOTADebuggerVisualizerExternalViewerUpdater;
  end;

{ TDebuggerDateTimeVisualizer }

function TdxLibJSONObjectDebuggerVisualizer.GetMenuText: string;
begin
  Result := sMenuText;
end;

procedure TdxLibJSONObjectDebuggerVisualizer.GetSupportedType(Index: Integer;
  var TypeName: string; var AllDescendants: Boolean);
begin
  TypeName := 'TdxJSONObject';
  AllDescendants := True;
end;

function TdxLibJSONObjectDebuggerVisualizer.GetSupportedTypeCount: Integer;
begin
  Result := 1;
end;

function TdxLibJSONObjectDebuggerVisualizer.GetVisualizerDescription: string;
begin
  Result := sVisualizerDescription;
end;

function TdxLibJSONObjectDebuggerVisualizer.GetVisualizerIdentifier: string;
begin
  Result := ClassName;
end;

function TdxLibJSONObjectDebuggerVisualizer.GetVisualizerName: string;
begin
  Result := sVisualizerName;
end;

function TdxLibJSONObjectDebuggerVisualizer.Show(const Expression, TypeName, EvalResult: string; SuggestedLeft, SuggestedTop: Integer): IOTADebuggerVisualizerExternalViewerUpdater;
var
  AForm: TCustomForm;
  AFrame: TdxLibJSONObjectViewerFrame;
  VisDockForm: INTACustomDockableForm;
begin
  VisDockForm := TdxLibJSONObjectVisualizerForm.Create(Expression, TypeName) as INTACustomDockableForm;
  AForm := (BorlandIDEServices as INTAServices).CreateDockableForm(VisDockForm);
  AForm.Left := SuggestedLeft;
  AForm.Top := SuggestedTop;
  (VisDockForm as IFrameFormHelper).SetForm(AForm);
  AFrame := (VisDockForm as IFrameFormHelper).GetFrame as TdxLibJSONObjectViewerFrame;
  AFrame.CustomDisplay(Expression, TypeName, EvalResult);
  Result := AFrame as IOTADebuggerVisualizerExternalViewerUpdater;
end;


procedure TdxLibJSONObjectViewerFrame.CustomDisplay(const Expression, TypeName, EvalResult: string);
begin
  FAvailableState := asAvailable;
  FExpression := Expression;
  fTypeName := TypeName;

  memJSON.Text := FormatJSON( Evaluate(Expression+'.AsJson').DeQuotedString );
  memJSON.Invalidate;
end;

procedure TdxLibJSONObjectViewerFrame.AfterSave;
begin

end;

procedure TdxLibJSONObjectViewerFrame.BeforeSave;
begin

end;

procedure TdxLibJSONObjectViewerFrame.CloseVisualizer;
begin
  if FOwningForm <> nil then
    FOwningForm.Close;
end;

procedure TdxLibJSONObjectViewerFrame.Destroyed;
begin

end;

function TdxLibJSONObjectViewerFrame.Evaluate(Expression: string): string;
var
  CurProcess: IOTAProcess;
  CurThread: IOTAThread;
  ResultStr: array[0..4095] of Char;
  CanModify: Boolean;
  Done: Boolean;
  ResultAddr, ResultSize, ResultVal: LongWord;
  EvalRes: TOTAEvaluateResult;
  DebugSvcs: IOTADebuggerServices;
begin
  begin
    Result := '';
    if Supports(BorlandIDEServices, IOTADebuggerServices, DebugSvcs) then
      CurProcess := DebugSvcs.CurrentProcess;
    if CurProcess <> nil then
    begin
      CurThread := CurProcess.CurrentThread;
      if CurThread <> nil then
      begin
        repeat
        begin
          Done := True;
          EvalRes := CurThread.Evaluate(Expression, @ResultStr, Length(ResultStr),
            CanModify, eseAll, '', ResultAddr, ResultSize, ResultVal, '', 0);
          case EvalRes of
            erOK: Result := ResultStr;
            erDeferred:
              begin
                FCompleted := False;
                FDeferredResult := '';
                FDeferredError := False;
                FNotifierIndex := CurThread.AddNotifier(Self);
                while not FCompleted do
                  DebugSvcs.ProcessDebugEvents;
                CurThread.RemoveNotifier(FNotifierIndex);
                FNotifierIndex := -1;
                if not FDeferredError then
                begin
                  if FDeferredResult <> '' then
                    Result := FDeferredResult
                  else
                    Result := ResultStr;
                end;
              end;
            erBusy:
              begin
                DebugSvcs.ProcessDebugEvents;
                Done := False;
              end;
          end;
        end
        until Done = True;
      end;
    end;
  end;
end;

procedure TdxLibJSONObjectViewerFrame.EvaluteComplete(const ExprStr,
  ResultStr: string; CanModify: Boolean; ResultAddress, ResultSize: LongWord;
  ReturnCode: Integer);
begin
  EvaluateComplete(ExprStr, ResultStr, CanModify, TOTAAddress(ResultAddress), ResultSize, ReturnCode);
end;

procedure TdxLibJSONObjectViewerFrame.EvaluateComplete(const ExprStr,
  ResultStr: string; CanModify: Boolean; ResultAddress: TOTAAddress; ResultSize: LongWord;
  ReturnCode: Integer);
begin
  FCompleted := True;
  FDeferredResult := ResultStr;
  FDeferredError := ReturnCode <> 0;
end;

procedure TdxLibJSONObjectViewerFrame.MarkUnavailable(
  Reason: TOTAVisualizerUnavailableReason);
begin
  if Reason = ovurProcessRunning then
  begin
    FAvailableState := asProcRunning;
  end else if Reason = ovurOutOfScope then
    FAvailableState := asOutOfScope;

  memJSON.Clear;
  memJSON.Invalidate;
end;

procedure TdxLibJSONObjectViewerFrame.Modified;
begin

end;

procedure TdxLibJSONObjectViewerFrame.ModifyComplete(const ExprStr,
  ResultStr: string; ReturnCode: Integer);
begin

end;

procedure TdxLibJSONObjectViewerFrame.RefreshVisualizer(const Expression, TypeName,
  EvalResult: string);
begin
  FAvailableState := asAvailable;
  CustomDisplay(Expression, TypeName, EvalResult);
end;

procedure TdxLibJSONObjectViewerFrame.SetClosedCallback(
  ClosedProc: TOTAVisualizerClosedProcedure);
begin
  FClosedProc := ClosedProc;
end;

procedure TdxLibJSONObjectViewerFrame.SetForm(AForm: TCustomForm);
begin
  FOwningForm := AForm;
end;

procedure TdxLibJSONObjectViewerFrame.SetParent(AParent: TWinControl);
begin
  if AParent = nil then
  begin
    if Assigned(FClosedProc) then
      FClosedProc;
  end;
  inherited;
end;

procedure TdxLibJSONObjectViewerFrame.ThreadNotify(Reason: TOTANotifyReason);
begin

end;

constructor TdxLibJSONObjectVisualizerForm.Create(const Expression, TypeName: string);
begin
  inherited Create;
  FExpression := Expression;
  fTypeName := TypeName;
end;

procedure TdxLibJSONObjectVisualizerForm.CustomizePopupMenu(PopupMenu: TPopupMenu);
begin
  // no toolbar
end;

procedure TdxLibJSONObjectVisualizerForm.CustomizeToolBar(ToolBar: TToolBar);
begin
 // no toolbar
end;

function TdxLibJSONObjectVisualizerForm.EditAction(Action: TEditAction): Boolean;
begin
  Result := False;
end;

procedure TdxLibJSONObjectVisualizerForm.FrameCreated(AFrame: TCustomFrame);
begin
  FMyFrame :=  TdxLibJSONObjectViewerFrame(AFrame);
end;

function TdxLibJSONObjectVisualizerForm.GetCaption: string;
begin
  Result := Format(sFormCaption, [FExpression, fTypeName]);
end;

function TdxLibJSONObjectVisualizerForm.GetEditState: TEditState;
begin
  Result := [];
end;

function TdxLibJSONObjectVisualizerForm.GetForm: TCustomForm;
begin
  Result := FMyForm;
end;

function TdxLibJSONObjectVisualizerForm.GetFrame: TCustomFrame;
begin
  Result := FMyFrame;
end;

function TdxLibJSONObjectVisualizerForm.GetFrameClass: TCustomFrameClass;
begin
  Result := TdxLibJSONObjectViewerFrame;
end;

function TdxLibJSONObjectVisualizerForm.GetIdentifier: string;
begin
  Result := 'TdxJSONObjectDebugVisualizer';
end;

function TdxLibJSONObjectVisualizerForm.GetMenuActionList: TCustomActionList;
begin
  Result := nil;
end;

function TdxLibJSONObjectVisualizerForm.GetMenuImageList: TCustomImageList;
begin
  Result := nil;
end;

function TdxLibJSONObjectVisualizerForm.GetToolbarActionList: TCustomActionList;
begin
  Result := nil;
end;

function TdxLibJSONObjectVisualizerForm.GetToolbarImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TdxLibJSONObjectVisualizerForm.LoadWindowState(Desktop: TCustomIniFile;
  const Section: string);
begin
  //no desktop saving
end;

procedure TdxLibJSONObjectVisualizerForm.SaveWindowState(Desktop: TCustomIniFile;
  const Section: string; IsProject: Boolean);
begin
  //no desktop saving
end;

procedure TdxLibJSONObjectVisualizerForm.SetForm(Form: TCustomForm);
begin
  FMyForm := Form;
  if Assigned(FMyFrame) then
    FMyFrame.SetForm(FMyForm);
end;

procedure TdxLibJSONObjectVisualizerForm.SetFrame(Frame: TCustomFrame);
begin
   FMyFrame := TdxLibJSONObjectViewerFrame(Frame);
end;

var
  vMyVisualizer: IOTADebuggerVisualizer;

procedure Register;
begin
  vMyVisualizer := TdxLibJSONObjectDebuggerVisualizer.Create;
  (BorlandIDEServices as IOTADebuggerServices).RegisterDebugVisualizer(vMyVisualizer);
end;

procedure RemoveVisualizer;
var
  DebuggerServices: IOTADebuggerServices;
begin
  if Supports(BorlandIDEServices, IOTADebuggerServices, DebuggerServices) then
  begin
    DebuggerServices.UnregisterDebugVisualizer(vMyVisualizer);
    vMyVisualizer := nil;
  end;
end;

initialization
finalization
  RemoveVisualizer;
end.

