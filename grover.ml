open Printf
open Telemetry

let drawing_xdim = ref 800
let drawing_ydim = ref 800
let f_drawing_xdim = ref 800.0
let f_drawing_ydim = ref 800.0

let round x = int_of_float (floor (x +. 0.5))
let foi = float_of_int

let drawlength_of_gamelength board (x,y) =
  round ((foi x) *. !f_drawing_xdim /. board.f_rxdim),
  round ((foi y) *. !f_drawing_ydim /. board.f_rydim)

let drawcoords_of_gamecoords board (x,y) =
  let fxshift = board.rxdim / 2
  and fyshift = board.rydim / 2
  in
    ((x + fxshift) * !drawing_xdim / board.rxdim,
     (!drawing_ydim - (y + fyshift) * !drawing_ydim / board.rydim))

let create_main_window () =
  let win = GWindow.window ~width:800 ~height:800 ()
  in let area = GMisc.drawing_area ~width:800 ~height:800 ~packing:win#add ()
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

let draw_background board (drawing: GDraw.drawable) =
  let fdrxdim = float_of_int !drawing_xdim
  and fdrydim = float_of_int !drawing_ydim
  and rxdim = float_of_int board.xdim
  and rydim = float_of_int board.ydim
  in let xbs = round (fdrxdim /. rxdim)
     and ybs = round (fdrydim /. rydim)
  in
    for yi = 0 to (board.ydim - 1)
    do
      for xi = 0 to (board.xdim - 1)
      do
	let f = board.fields.(yi).(xi)
	in
	  if f.state != Unknown then begin
	    drawing#set_foreground (`NAME (match f.state with
					       Free -> "darkgreen"
					     | Occupied -> "darkred"
					     | Partially_Free ->
						 "darkgray"
					     | _ -> "white" ));
	    drawing#rectangle ~filled:true
	      ~x:(round (fdrxdim *. (foi xi) /. rxdim))
	      ~y:(round (fdrydim -. fdrydim *. (foi yi) /. rydim -. (foi ybs)))
	      ~width:xbs ~height:ybs ();
	  end
      done
    done

let draw_homebase board (drawing: GDraw.drawable) =
  let dx, dy = drawcoords_of_gamecoords board (0, 0)
  and rx, ry = drawlength_of_gamelength board (2500, 2500)
  in
    drawing#set_foreground (`NAME "green");
    drawing#arc ~filled:false ~x:(dx - rx) ~y:(dy - ry)
      ~width:(rx * 2) ~height:(ry * 2) ()

let drawing_hacks board (drawing: GDraw.drawable) =
  for i = 0 to board.xdim - 1
  do
    board.fields.(i).(i).state <- Occupied;
  done;
  drawing#set_foreground (`NAME "white");
  drawing#line 0 !drawing_ydim !drawing_xdim 0

let redraw_world world (area: GMisc.drawing_area) (drawing: GDraw.drawable) _ =
  let x,y = drawing#size;
  and board = !world.world_board
  in
    drawing_xdim := x;
    f_drawing_xdim := float_of_int x;
    drawing_ydim := y;
    f_drawing_ydim := float_of_int y;
    draw_background board drawing;
    draw_homebase board drawing;
    BCRecorder.iter (draw_bc board drawing) board.bcrecorder;
    drawing_hacks board drawing;
    true

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
(*	  ignore (redraw_world world area drawing ()); *)
	  true;
	end else begin
	  prerr_endline "got HUP or ERR from server";
	  false;
	end
    in
      ignore (area#event#connect#expose
		~callback:(redraw_world world area drawing));
      ignore (GMain.Io.add_watch ch ~prio:0 ~cond:[`IN; `HUP; `ERR]
		~callback:input_callback);
      ignore (GMain.Idle.add (redraw_world world area drawing));
      GMain.Main.main ()

let _ =
  main ()
