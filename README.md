# Delphi-Web-Framework
*A Micro **Delphi** Web-Framework composed by an indy http listener and much Rtti*

Alternative to develop micro services web in delphi, without a bigger datasnap project or some additional component paid.

## Using this you have a few resources very usefull  ## 
* **Instantly run**

  It's a singleton, so... you're be able to have a global Context of the current client in your application.
  
* **Easly publish resources**
  
  You just need to call the singleton in the Create routine of your application (or in some moment that you want)
  and assign the resources (that here will be your TClass type) wich you want to publish in your micro-service.
  
  **something like this:**
  
```Delphi
procedure TForm1.FormCreate(Sender: TObject);
begin

  with TROWebServer.GetInstance do
  begin
      StartServer;
      AddRecurso(TEcho , 'echo');
  end;

end;
```

* And easy call

![call_example](https://github.com/Ronald-TR/Delphi-Web-Framework/blob/master/call_example.png)

  The default port is **8000**
  
  but you can change it in the Create constructor of the ROWebServer class.
  
  
  ***Beta 0.1.2***


  
