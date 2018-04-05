unit uClssResource;

interface
type

  TResourceInfo = record
  private
    FRoute: String;
    FCLassView: TClass;
  public
    property ClassView : TClass read FCLassView write FClassView;
    property Route     : String read FRoute write FRoute;

    constructor Create(AClassView : TClass; ARoute : String);
  end;

implementation

{ TResourceInfo }


{ TResourceInfo }

constructor TResourceInfo.Create(AClassView: TClass; ARoute: String);
begin
    Self.FCLassView   := AClassView;
    Self.FRoute       := ARoute;
end;

end.
