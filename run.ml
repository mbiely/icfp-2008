open Statemachines
open Telemetry

let dir_of_turn w turn = 
  if turn = 0. then 
    Straight
  else if turn > 0. then
    if turn > w.imax_turn then 
      HardLeft
    else
      Left
  else     
    if turn < (-.w.imax_turn) then 
      HardRight
    else
      Right

let great_decision_procedure w t = 
  let angle = Geometry.angle_to_point (t.x,t.y) (0,0) in
  let turn = Geometry.turn_towards_dstangle angle t.dir  in
  Printf.fprintf stderr "angle %f dir %f turn %f\n" angle t.dir turn; 
  flush stderr;
  let want_dir = dir_of_turn w turn in
  Accelerating,want_dir

let precalculation_hook x = x


let stupid_loop_one_game socket = 
  
  let _ = Communication.waitfordata socket in
  let init = match Communication.sock_recv_next socket with
    | Some(x) -> x
    | None -> failwith "zeugs"
  in
  let world = initialization_of_string init in

  
  let rec loop world = 
    if not (Communication.is_dataavailable socket) then
      let world = precalculation_hook world in loop world
    else
      let _ = Communication.waitfordata socket in
      let next = 
	match Communication.sock_recv_next socket with 
	  | Some(x) -> x
	  | None -> (Printf.fprintf stderr "hoscherei\n"; loop world) 
      in 
      if not (is_telemetry next) then 
	(Printf.fprintf stderr "Event: %s\n" next;flush stderr;
	match event_of_string next with
	  | Scored x -> Printf.fprintf stderr "We have scored %d points!\n" x;flush stderr; loop world
	  | BoulderHit | CraterFall | Killed | Success -> loop world
	)
      else
	begin
	  let t = telemetry_of_string next in
	  
	  let world = merge_telemetry_into_world world t in
	  let wantedstate = great_decision_procedure world t in
	  
	  (* this might result in awful slingering if requested is left or right and communication becomes an issue*)
	  let command = Statemachines.both_change_to (t.speeding,t.turning) wantedstate in
	  Communication.sock_send socket (command2string command);
	  loop world
	end
  in
  loop world
    
    
let main = 
  try
    (* Communication.open_connection (Sys.argv.(0)) (int_of_string
       Sys.argv.(1)) *)
    let socket = Communication.connect "localhost" 17676 in
    stupid_loop_one_game socket 
  with Unix.Unix_error(code,_,_) as e -> Printf.fprintf stderr "%s\n" (Unix.error_message code);
    raise e
  


