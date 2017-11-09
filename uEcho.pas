unit uEcho;

interface
type
  TEcho = class
    function echoteste: string;
  end;
implementation

{ TEcho }

function TEcho.echoteste: string;
begin
  Result := 'Teste echo Web Framework';
end;

end.
