open Printf
open Telemetry

let drawing_xdim = ref 600
let drawing_ydim = ref 600

let drawlength_of_gamelength board (x,y) =
  (x * !drawing_xdim / board.fxdim,
   y * !drawing_ydim / board.fydim)

let drawcoords_of_gamecoords board (x,y) =
  let fxshift = board.fxdim / 2
  and fyshift = board.fydim / 2
  in
    ((x + fxshift) * !drawing_xdim / board.fxdim,
     (!drawing_ydim - (y + fyshift) * !drawing_ydim / board.fydim))

let create_main_window () =
  let win = GWindow.window ~width:600 ~height:600 ()
  in let area = GMisc.drawing_area ~width:600 ~height:600 ~packing:win#add ()
  in let drawing = area#misc#realize (); new GDraw.drawable (area#misc#window)
  in let style = area#misc#style#copy
  in
    style#set_bg [`NORMAL,`BLACK];
    area#misc#set_style style;
    drawing#set_background `BLACK;
    win, area, drawing

let draw_bc board (drawing: GDraw.drawable) bcr =
  let dx, dy = drawcoords_of_gamecoords board (bcr.bcx, bcr.bcy)
  and rx, ry = drawlength_of_gamelength board (bcr.bcr, bcr.bcr)
  in
    drawing#set_foreground (`NAME (match bcr.bctype with
				       Boulder -> "gray"
				     | Crater -> "brown"));
    drawing#arc ~filled:false ~x:(dx - rx) ~y:(dy - ry)
      ~width:(rx * 2) ~height:(ry * 2) ()

let draw_homebase board (drawing: GDraw.drawable) =
  let dx, dy = drawcoords_of_gamecoords board (0, 0)
  and rx, ry = drawlength_of_gamelength board (2500, 2500)
  in
    drawing#set_foreground (`NAME "green");
    drawing#arc ~filled:false ~x:(dx - rx) ~y:(dy - ry)
      ~width:(rx * 2) ~height:(ry * 2) ()

let redraw_world world (area: GMisc.drawing_area) (drawing: GDraw.drawable) _ =
  let x,y = drawing#size;
  and board = !world.world_board
  in
    drawing_xdim := x;
    drawing_ydim := y;
    draw_homebase board drawing;
    BCRecorder.iter (draw_bc board drawing) board.bcrecorder;
    false

let server_msg_callback world socket =
  Run.world_step world socket

let main () =
  prerr_endline "Starting up GTK version of rover..";
  begin
    try
      ignore (GMain.init ());
   with
	x ->
	  fprintf stderr "are you sure you have an X server running?\n";
	  raise x
  end;
  let mainwin, area, drawing = create_main_window ()
  in
    ignore (mainwin#connect#destroy GMain.quit);
    mainwin#show ();
    let socket = Run.create_socket ()
    in let world = ref (Run.world_init socket)
    in let ch = GMain.Io.channel_of_descr socket
    in let input_callback c =
	if List.mem `IN c then begin (* input from server *)
	  world := server_msg_callback !world socket;
	  (*	    area#set_size ~width:(xscaler * !world.world_board.xdim)
		    ~height:(xscaler * !world.world_board.ydim);
	  *)
	  ignore (redraw_world world area drawing ());
	  true;
	end else begin
	  prerr_endline "got HUP or ERR from server";
	  false;
	end
    in
      ignore (area#event#connect#expose
		~callback:(redraw_world world area drawing));
      GMain.Io.add_watch ch ~prio:0 ~cond:[`IN; `HUP; `ERR]
	~callback:input_callback;
      GMain.Main.main ()

let _ =
  main ()
