unit u_UtilsWebServer;

interface
uses
  System.Rtti,
  System.Classes,
  SysUtils,
  IWSystem,
  System.JSON,
  IdHashMessageDigest,
  uRouteInfo,
  System.Generics.Collections,
  uClssResource,
  uClssViewBase,
  IdCustomHTTPServer, Vcl.Dialogs;

type

  TROWebServerExceptionType = (HTMLMsg, JSONMsg);

  TIndexUtil = class
  private
    FURis : string;
  public
    function projectname: string;
    property uris: string read FURis write FURis;
  end;

{
  Author : Ronald Rodrigues Farias
}
 { load staticfiles }
function load_static_file(ARouteInfo : TRouteInfo): TViewResult;


 { exec the view resource registered in server }
function call_method(ARouteInfo : TRouteInfo; AResources : TList<TResourceInfo>): TViewResult;
{
 Tips para ReplaceVARInHTML():
  * ADICIONADO +3 AO FIM POR SER O LENGTH DA TAG DE FECHAMENTO
  * SUBTRAIDO -1 DO INICIO PARA VOLTAR UMA CASA ANTES AO PRIMEIRO CARACTERE RETORNADO PELA FUNCAO POS()
}

{ default exception message rendering methods }
function get_index_msg(AListOfResources : Tlist<TResourceInfo>; AMsgType : TROWebServerExceptionType): string;
function get_error_msg(ARootRoute, EMessage : string; AClass : TClass; AMsgType : TROWebServerExceptionType): string;

{ html responses}
function get_error_html(ARootRoute, EMessage : string; AClass : TClass): string;
function get_index_html(AListOfResources : Tlist<TResourceInfo>): string;
{ json responses }
function get_error_json(ARootRoute, EMessage : string; AClass : TClass): string;
function get_index_json(AListOfResources : Tlist<TResourceInfo>): string;

{ default method for rendering the template }
function RenderTemplate(PathFile, a_VarName : string; a_Objeto : TObject) : string;

{ generic invoke some in object, search in functions first, if don't find, then it will search in properties to execute }
function InvokeInObj(a_Objeto : TObject; a_metodo : string): string;

{ Standard method for rendering variables in template internally, it's who calls the second methods inside itself }
function ReplaceVARInHTML(a_VarName, a_TextHTML: string; a_Objeto : TObject) : string;
function ReplaceVARContent(a_VarName, a_Content: string; a_Objeto : TObject) : string;
function ReplaceFORInHTML(a_VarName, a_TextHTML : string; a_Objeto : TObject): string;
{ MD5 short call }
function MD5(AValue : string) : string;

implementation

function load_static_file(ARouteInfo : TRouteInfo): TViewResult;
var
  sl : TStringList;
  sResPath : string;
  arrResPath : TArray<String>;
  i : integer;
begin
     { recrio a rota para o arquivo estatico }

     sResPath := '/' + ARouteInfo.Method;
     for I := 0 to Length(ARouteInfo.Resources)-1 do
       begin
           sResPath := sResPath + '/' + ARouteInfo.Resources[i].AsString;
       end;

     {-}

     sl := TStringList.Create;
     try
         try
           sl.LoadFromFile(gsAppPath + sResPath);
           Result.Text := sl.Text;

           // recolho a extensao do arquivo estatico como contenttype
           arrResPath := sResPath.Split(['.']);
           if (arrResPath[Length(arrResPath)-1] = 'css') or
              (arrResPath[Length(arrResPath)-1] = 'html') then
           begin
              Result.ContentType := 'text/' + arrResPath[Length(arrResPath)-1];
           end
           else if (arrResPath[Length(arrResPath)-1] = 'pdf') then
           begin
              Result.ContentType := 'application/' + arrResPath[Length(arrResPath)-1];
           end
           else
           begin
              Result.ContentType := arrResPath[Length(arrResPath)-1];
           end;
         except
            raise EIdHTTPServerError.Create('recurso nao existe');
         end;
     finally
         sl.Free;
     end;

end;
function call_method(ARouteInfo : TRouteInfo; AResources : TList<TResourceInfo>): TViewResult;
var
  rtContext : TRttiContext;
  rtMethod  : TRttiMethod;
  oAux      : TObject;
  sTextResponse,
  sContentType : String;
  rtAttr    : TCustomAttribute;
  sValue : TValue;
begin
  rtContext := TRttiContext.Create;

  oAux := AResources[ARouteInfo.ResourceIndex].ClassView.Create;
  try
      if ARouteInfo.Method = 'favicon.ico' then
         exit;


      rtMethod := rtContext.GetType(oAux.ClassType)
                         .GetMethod(ARouteInfo.Method);
      rtContext.GetType(oAux.ClassType).GetProperty('RouteOperationalContext')
                          .SetValue(oAux, TValue.From<TRouteInfo>(ARouteInfo));

      if rtMethod = nil then
         raise Exception.Create('recurso nao existe, por favor reveja sua rota');

      sValue := rtMethod.Invoke(oAux, ARouteInfo.Resources);
      sTextResponse := sValue.AsString;

      for rtAttr in rtMethod.GetAttributes do
        begin
           if rtAttr is TContentType then
           begin
              sContentType := TContentType(rtAttr).ContentType;
              Break;
           end;
        end;
      Result.Text := sTextResponse;
      Result.ContentType := sContentType;
  finally
      rtContext.Free;
      oAux.Free;
  end;

end;
function get_index_msg(AListOfResources : Tlist<TResourceInfo>; AMsgType : TROWebServerExceptionType): string;
begin
    case AMsgType of
      HTMLMsg: Result := get_index_html(AListOfResources);
      JSONMsg: Result := get_index_json(AListOfResources);
    end;
end;

function get_error_msg(ARootRoute, EMessage : string; AClass : TClass; AMsgType : TROWebServerExceptionType) : string;
begin
  case AMsgType of
    HTMLMsg: Result := get_error_html(ARootRoute, EMessage, AClass);
    JSONMsg: Result := get_error_json(ARootRoute, EMessage, Aclass);
  end;
end;

{ --  HTML METHODS -- }

function get_index_html(AListOfResources : Tlist<TResourceInfo>): string;
var
  i : integer;
  sURIsForHTML : string;
  oIndex : TIndexUtil;
begin
    oIndex := TIndexUtil.Create;

    try
        for I := 0 to AListOfResources.Count-1 do
        begin
            sURIsForHTML := sURIsForHTML + '<div class="row">' +
                    '<label class="col-md-12">URI:</label>'+
                    '<div class="input-group col-md-12">'+
                     '   <span class="input-group-addon">' +
                         AListOfResources[i].Route +
                     '</span>' +
                      '<input class="form-control" type="text" placeholder="' +
                        AListOfResources[i].ClassView.QualifiedClassName + '">'+
                    '</div>' +
                '</div>';
        end;
        oIndex.uris := sURIsForHTML;
        Result := RenderTemplate(gsAppPath + '\index.html', 'obj', oIndex);
    finally
        oIndex.Free;
    end;
end;

function get_error_html(ARootRoute, EMessage : string; AClass : TClass): string;
var
  sURIsForHTML : string;
  oHTML : TStringList;
  i : integer;
  rtContext : TRttiContext;
begin
    oHTML := TStringList.Create;
    rtContext := TRttiContext.Create;

    oHTML.LoadFromFile(gsAppPath + '/error.html');
    with rtContext.GetType(AClass) do
    begin
        for I := 0 to Length(GetDeclaredMethods)-1 do
        begin
             sURIsForHTML := sURIsForHTML + '<div class="row">' +
                    '<label class="col-md-12">URI:</label>'+
                    '<div class="input-group col-md-12">'+
                     '   <span class="input-group-addon"><i class="fa fa-briefcase"></i>' +
                          ARootRoute +
                     '</span>' +
                      '<input class="form-control" type="text" placeholder="' + GetDeclaredMethods[i].ToString + '">'+
                    '</div>' +
                '</div>';

        end;
    end;


    Result := oHTML.Text.Replace('{uris}', sURIsForHTML).Replace('{erro}', EMessage);
    oHTML.Free;
    rtContext.Free;
end;
  {--}

{ -- JSON METHODS -- }
function get_index_json(AListOfResources : Tlist<TResourceInfo>): string;
var
  oJS : TJSONObject;
  oJSArr : TJSONArray;
  i : integer;
  sJSArray, sJSObject : string;
begin
    for I := 0 to AListOfResources.Count-1 do
    begin
        if sJSObject.IsEmpty then
            sJSObject := Format('"%s":"%s"', [AListOfResources[i].Route, AListOfResources[i].ClassView.QualifiedClassName])
        else
            sJSObject := sJSObject + ',' + Format('"%s":"%s"', [AListOfResources[i].Route, AListOfResources[i].ClassView.QualifiedClassName]);
    end;
    Result := '{"routes":[{' + sJSObject.Replace('/', '\/') + '}]}';
end;


function get_error_json(ARootRoute, EMessage : string; AClass : TClass): string;
var
  sURIsForHTML : string;
  oJS, oJSRoute : TJSONObject;
  i : integer;
  oJSArr : TJSONArray;
  rtContext : TRttiContext;
  sJSRoute, sJSArr, sJS : string;
begin
    rtContext := TRttiContext.Create;

    EMessage := EMessage.Replace(#13, '');
    with rtContext.GetType(AClass) do
    begin
        for I := 0 to Length(GetDeclaredMethods)-1 do
        begin
          if sJSArr.IsEmpty then
             sJSArr := Format('"%s"', [GetDeclaredMethods[i].ToString])
          else
             sJSArr := sJSArr + ',' + Format('"%s"', [GetDeclaredMethods[i].ToString]);
        end;
        sJSRoute := Format('"%s":[%s]', [ARootRoute, sJSArr]);
        sJS :=      Format('{"%s":{%s, "%s":"%s"}}', ['route', sJSRoute, 'error', EMessage]);

    end;

    Result := sJS;

end;

  {--}

function InvokeInObj(a_Objeto : TObject; a_metodo : string): string;
var
  rtContext     : TRttiContext;
  arrMethods    : TArray<TRttiMethod>;
  method        : TRttiMethod;

  arrProperties : TArray<TRttiProperty>;
  prop          : TRttiProperty;
begin
    Result := '';
    rtContext := TRttiContext.Create;
    try
        method := rtContext.GetType(a_Objeto.ClassType).GetMethod(a_metodo);
        if method <> nil then
        begin
            Result := method.Invoke(a_Objeto, []).ToString;
        end;

        if Result.IsEmpty then
        begin
            prop := rtContext.GetType(a_Objeto.ClassType).GetProperty(a_metodo);
            if prop <> nil then
            begin
               Result := prop.GetValue(a_Objeto).ToString;
            end;
        end;
    finally
        rtContext.Free;
    end;
end;

function ReplaceVARContent(a_VarName, a_Content: string; a_Objeto : TObject) : string;
var
  posContentInicial : integer;
  posContentFinal   : integer;
  posContentBetween : integer;
  i : integer;
  method : string;
  resultMethod : string;
  VarTag : string;
begin
    VarTag := '{' + a_VarName;
    posContentInicial := Pos(VarTag + '.', a_Content) + length(VarTag) + 1;

    if not (Pos(VarTag + '.', a_Content) > 0) then
      Result := a_Content
    else
    begin
        for i := posContentInicial to length(a_Content) do
        begin
             if a_Content[i] = '}' then
             begin
                 method := Copy(a_Content, posContentInicial, i - posContentInicial);

                 resultMethod := InvokeInObj(a_Objeto, method);
                 a_Content := StringReplace(a_Content, VarTag + '.' + method + '}', resultMethod, []);
                 Break;

             end;
        end;
        Result := ReplaceVARContent(a_VarName, a_Content, a_Objeto);
    end;
end;

function ReplaceVARInHTML(a_VarName, a_TextHTML: string; a_Objeto : TObject) : string;
var
  posInicial   : integer;
  posFinal     : integer;
  posBetween   : integer;
  i            : integer;
  content      : string;
  method       : string;
  resultMethod : string;
  VarTag       : string;
begin
    VarTag := '{' + a_VarName;
    posInicial := Pos(VarTag, a_TextHTML);
    posBetween := posInicial + Length(VarTag) + 1;
    if not (posInicial > 0) then
       Result := a_TextHTML
    else
    begin
        for i := posBetween to Length(a_TextHTML) do
        begin
            if (a_TextHTML[i] = '%') and (a_TextHTML[i+1] = '}') then
            begin
                posFinal := i -1;
                content := Copy(a_TextHTML, posBetween, posFinal - posBetween);
                Break;
            end;
        end;
        content := ReplaceVARContent(a_VarName, content, a_Objeto);

        a_TextHTML := a_TextHTML.Remove(posInicial-1, posFinal - posInicial + 3);
        a_TextHTML := a_TextHTML.Insert(posInicial-1, content);

        Result := ReplaceVARInHTML(a_VarName, a_TextHTML, a_Objeto);
    end;
end;

function ReplaceFORInHTML(a_VarName, a_TextHTML : string; a_Objeto : TObject): string;
var
  posInicialSentence, contEndSentence, posEndSentence,
  posFinalFor, i : integer;
  for_sentence : string;
  for_body : string;
  args : TArray<string>;
  keyobj, valueobj : string;
  oAux : TObject;
  sContentBody : string;
  full_for : string;
begin
     posInicialSentence := Pos('{for ', a_TextHTML);
     // RECOLHE A SENTENÇA DO FOR
     for I := posInicialSentence to a_TextHTML.Length-1 do
     begin
         if a_TextHTML[i] = '}' then
         begin
            contEndSentence := i - (posInicialSentence+5);
            posEndSentence := i;
            Break;
         end;
     end;

     for_sentence := Copy(a_TextHTML, posInicialSentence+5, contEndSentence);
     args := for_sentence.Split(['in']);

     // RECOLHENDO CHAVE E VALOR DO LAÇO
     keyobj := args[0].Replace(' ', ''); valueobj := args[1].Replace(' ', '');

     // RECOLHE O CORPO DO FOR
     for I := posEndSentence+1 to a_TextHTML.Length-1 do
     begin
         if (a_TextHTML[i] = '%') and
         (a_TextHTML[i+1] = '%') and
         (a_TextHTML[i+2] = '}') then
         begin
            posFinalFor := i-2;
            Break;
         end;
     end;
     for_body := Copy(a_TextHTML, posEndSentence+1, posFinalFor-posEndSentence);
     full_for := Copy(a_TextHTML, posInicialSentence, (posFinalFor-posInicialSentence)+contEndSentence);

     for oAux in TObjectList<TObject>(a_Objeto) do
     begin
         sContentBody := sContentBody + ReplaceVARContent(keyobj, for_body, oAux);
     end;

     a_TextHTML := a_TextHTML.Replace(full_for, '');
     a_TextHTML := a_TextHTML.Insert(posInicialSentence+contEndSentence-contEndSentence,sContentBody);
     Result := a_TextHTML;

end;

function RenderTemplate(PathFile, a_VarName : string; a_Objeto : TObject) : string;
var
  sHTML : TStringList;
begin
     sHTML := TStringList.Create;
     try
        sHTML.LoadFromFile(PathFile);
        Result := ReplaceVARInHTML(a_VarName, sHTML.Text, a_Objeto);
     finally
        sHTML.Free;
     end;
end;

function MD5(aValue : string): string;
 var
   md5     : TIdHashMessageDigest5;
begin

  md5 := TIdHashMessageDigest5.Create;
  try
    Result := MD5.HashStringAsHex(aValue);

  finally
    md5.Free;
  end;

end;
{ TIndexUtil }

function TIndexUtil.projectname: string;
begin
    Result := gsAppName;
end;

end.
