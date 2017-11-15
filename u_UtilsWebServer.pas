unit u_UtilsWebServer;

interface
uses uROWebServer, System.Rtti, System.Classes, SysUtils;
{
  Author : Ronald Rodrigues Farias
  ver..: 0.1.1
}

{
 Tips para ReplaceVARInHTML():
  * ADICIONADO +3 AO FIM POR SER O LENGTH DA TAG DE FECHAMENTO
  * SUBTRAIDO -1 DO INICIO PARA VOLTAR UMA CASA ANTES AO PRIMEIRO CARACTERE RETORNADO PELA FUNCAO POS()
}

{default method}
function RenderTemplate(PathFile, a_VarName : string; a_Objeto : TObject) : string;

{generic invoke some in object, search in functions first, if don't find, then it will search in properties to execute}
function InvokeInObj(a_Objeto : TObject; a_metodo : string): string;

{Standard method for rendering variables in template, it's who calls the second methods inside itself}
function ReplaceVARInHTML(a_VarName, a_TextHTML: string; a_Objeto : TObject) : string;
function ReplaceVARContent(a_VarName, a_Content: string; a_Objeto : TObject) : string;



implementation

uses uEcho;

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
        arrMethods := rtContext.GetType(a_Objeto.ClassType).GetMethods;
        for method in arrMethods do
        begin
             if method.Name = a_metodo then
             begin
                Result := method.Invoke(a_Objeto, []).ToString;
                Break;
             end;
        end;

        if Result.IsEmpty then
        begin
            arrProperties := rtContext.GetType(a_Objeto.ClassType).GetProperties;
            for prop in arrProperties do
            begin
                 if prop.Name = a_metodo then
                 begin
                    Result := prop.GetValue(a_Objeto).ToString;
                    Break;
                 end;
            end;
        end;

    finally
       // rtContext.Free;
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

end.
